"""Freeze a sign-independent common bitmap, then verify exported hardware trials."""
import argparse
import csv
from fractions import Fraction
import hashlib
import json
from pathlib import Path
from verify_board_results import verify as verify_baseline


def read(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path,obj):Path(path).write_text(json.dumps(obj,indent=2,sort_keys=True),encoding='utf-8')
def require(ok,message):
    if not ok:raise ValueError(message)


def training(folder):
    proof=verify_baseline(folder)
    env=read(folder/'environment.json')
    refs=[set() for _ in range(320)];clean=[True]*320
    with (folder/'reference.csv').open(newline='') as f:
        for r in csv.DictReader(f):
            p=int(r['pair']);a=int(r['count_a']);b=int(r['count_b']);s=int(r['status'])
            refs[p].add(int(a>b) if s==0 and a!=b else None)
            clean[p]=clean[p] and s==0 and abs(a-b)>=8
    reference=[next(iter(bits)) if clean[p] and len(bits)==1 and None not in bits else None for p,bits in enumerate(refs)]
    eligible=[r is not None for r in reference];gap=[None]*320;margin=[None]*320
    with (folder/'training.csv').open(newline='') as f:
        for r in csv.DictReader(f):
            p=int(r['pair']);a=int(r['count_a']);b=int(r['count_b']);s=int(r['status']);delta=abs(a-b)
            eligible[p]=eligible[p] and s==0 and delta>=8 and int(a>b)==reference[p]
            ratio=Fraction(delta,a+b) if a+b else Fraction(0)
            gap[p]=ratio if gap[p] is None else min(gap[p],ratio)
            margin[p]=delta if margin[p] is None else min(margin[p],delta)
    candidates=[p for p in range(320) if eligible[p]]
    require(len(candidates)==proof['eligible_pairs'],'Training eligibility disagrees with independent baseline checker')
    return dict(environment=env,reference=reference,eligible=set(candidates),gap=gap,margin=margin,
                original_bitmap=int(read(folder/'selection.json')['bitmap_hex'],16),proof=proof)


def freeze(a_folder,b_folder,out):
    a=training(a_folder);b=training(b_folder)
    for key in ['bitstream_sha256','hwh_sha256','window_cycles','warmup_cycles']:
        require(a['environment'][key]==b['environment'][key],'Different experiment parameter '+key)
    common=a['eligible']&b['eligible']
    old=[p for p in range(320) if a['original_bitmap']>>p&1]
    reuse=set(old)<=common
    ranked=sorted(common,key=lambda p:(-min(a['gap'][p],b['gap'][p]),-min(a['margin'][p],b['margin'][p]),p))
    selected=old if reuse else sorted(ranked[:256])
    plan=dict(format='puf256-two-board-common-v1',complete=len(selected)==256,
              bitstream_sha256=a['environment']['bitstream_sha256'],hwh_sha256=a['environment']['hwh_sha256'],
              window_cycles=100000,warmup_cycles=1024,selected_pairs=selected,
              bitmap_hex=format(sum(1<<p for p in selected),'080x'),
              eligible_20100=len(a['eligible']),eligible_20200=len(b['eligible']),common_eligible=len(common),
              reused_original_20100_bitmap=reuse,original_20100_pairs_not_eligible_on_20200=sorted(set(old)-b['eligible']),
              ranked_common=ranked,
              rule='Use original 20100 bitmap only if all its pairs are eligible on both boards. Otherwise rank common training-eligible pairs by descending minimum normalized gap over both boards, then minimum absolute margin, then ascending pair ID. No response polarity, inter-board difference or new holdout result enters selection.',
              training_source_sha256={label:{name:digest(folder/name) for name in ['environment.json','reference.csv','training.csv','selection.json']}
                                      for label,folder in [('20100',a_folder),('20200',b_folder)]})
    out.mkdir(parents=True,exist_ok=True);write(out/'common_bitmap.json',plan)
    if not plan['complete']:return plan
    plan_hash=digest(out/'common_bitmap.json')
    for label,info in [('20100',a),('20200',b)]:
        candidate=sum(info['reference'][p]<<j for j,p in enumerate(selected))
        write(out/('reference_'+label+'.json'),dict(board_label=label,plan_sha256=plan_hash,
              expected_candidate_hex=format(candidate,'064x'),
              note='Training-only laboratory reference; the board must produce its identity through actual PL registers.'))
    return plan


def verify_fixed(folder,plan_path,reference_path,allow_rejections=False):
    plan=read(plan_path);ref=read(reference_path);env=read(folder/'environment.json');summary=read(folder/'summary.json')
    require(plan['complete'] and len(plan['selected_pairs'])==256,'Incomplete frozen bitmap')
    bitmap=int(plan['bitmap_hex'],16);pairs=[p for p in range(320) if bitmap>>p&1]
    require(pairs==plan['selected_pairs'],'Bitmap order mismatch')
    for key in ['bitstream_sha256','hwh_sha256','bitmap_hex','window_cycles','warmup_cycles']:
        require(env[key]==plan[key],'Fixed experiment mismatch '+key)
    require(env['plan_sha256']==digest(plan_path)==ref['plan_sha256'] and env['reference_sha256']==digest(reference_path),'Frozen input hash mismatch')
    require(env['board_label']==ref['board_label'],'Wrong board reference')
    loads=read(folder/'overlay_loads.json');register_names={'bitmap','helper_input','key_data','helper_output','puf_sequence','raw_sequence','helper_input_valid'}
    require(len(loads)==env['reload_runs']+1,'Missing overlay load')
    for i,row in enumerate(loads):
        require(row['index']==i and abs(row['fclk0_mhz']-100.0)<=.1,'Wrong FCLK/load order')
        require(set(row['initial_volatile_registers'])==register_names and not any(row['initial_volatile_registers'].values()),'Reload did not clear state')
    expected=int(ref['expected_candidate_hex'],16);indices={p:j for j,p in enumerate(pairs)}
    seen=set();sequence=0;minimum=65536
    with (folder/'holdout.csv').open(newline='') as f:
        for r in csv.DictReader(f):
            p=int(r['pair']);n=int(r['read']);a=int(r['count_a']);b=int(r['count_b']);s=int(r['status']);sequence+=1
            require(p in indices and 0<=n<env['holdout_reads'] and (n,p) not in seen,'Missing/duplicate holdout identity')
            seen.add((n,p));require(int(r['sequence'])==sequence,'Raw sequence changed')
            require(s==0 and 0<a<65536 and 0<b<65536 and max(a,b)*.008<=500,'Invalid ticks or RO frequency bound')
            require(int(r['window_cycles'])==100000 and int(r['warmup_cycles'])==1024,'Raw measurement parameters changed')
            require(int(r['delta'])==a-b and int(r['bit'])==int(a>b)==((expected>>indices[p])&1) and abs(a-b)>=8,'Frozen holdout failed')
            minimum=min(minimum,abs(a-b))
    require(len(seen)==256*env['holdout_reads'],'Holdout row count')
    held=read(folder/'holdout_verdict.json')
    require(held['passed'] and not held['failures'] and held['rows']==sequence and held['min_abs_margin']==minimum,'Holdout summary mismatch')
    reg=read(folder/'registration.json');enrollment=read(folder/'enrollment.json')
    require(reg['candidate_hex']==format(expected,'064x'),'Hardware registration differs from training')
    helper=0
    for w in range(16):
        syndrome=0
        for bit in range(16):
            if expected>>(16*w+bit)&1:syndrome^=16 | (bit+1 if bit<15 else 0)
        helper|=syndrome<<(5*w)
    require(reg['helper_hex']==enrollment['helper_hex']==format(helper,'020x'),'Hardware helper mismatch')
    require(enrollment['bitmap_hex']==plan['bitmap_hex'] and enrollment['bitstream_sha256']==plan['bitstream_sha256'] and enrollment['plan_sha256']==digest(plan_path),'Enrollment metadata mismatch')
    key_hash=hashlib.sha256(expected.to_bytes(32,'little')).hexdigest()
    trials=read(folder/'reconstructions.json')
    schedule=[('registration',0)]+[('repeat',n) for n in range(env['reconstruction_runs'])]+[('abort-reset',0)]+[('same-bitstream-reload',n) for n in range(env['reload_runs'])]
    require([(r['stage'],r['index']) for r in trials]==schedule,'Missing reconstruction trial')
    seq=0;rejected=0
    for row in trials:
        if row['stage']=='same-bitstream-reload':seq=0
        seq+=1
        require(row['sequence']==seq and 0<=row['corrected_words']<=16,'Reconstruction sequence/count mismatch')
        if row['status']==0:
            require(row['match'] and row['key_sha256']==key_hash,'Accepted identity changed')
        else:
            require(allow_rejections and row['stage']!='registration' and row['status']==4 and not row['match']
                    and row['key_sha256'] is None and row['corrected_words']==0,'Rejected/failed reconstruction')
            rejected+=1
    require(summary['passed']==(rejected==0) and summary['candidate_hex']==reg['candidate_hex'] and summary['key_sha256']==key_hash and summary['plan_sha256']==digest(plan_path),'Summary identity/pass mismatch')
    require(summary['holdout_samples']==sequence and summary['reconstruction_count']==len(trials)-1 and summary['reload_count']==env['reload_runs'] and summary['corrected_words']==sum(r['corrected_words'] for r in trials),'Summary counts mismatch')
    if rejected:
        require(summary['completed'] and not summary['strict_pass'] and summary['all_accepted_keys_match']
                and summary['rejected_reconstructions']==rejected and summary['successful_reconstructions']==len(trials)-1-rejected,
                'Rejected attempts were hidden or counted as successful keys')
        continuation=read(folder/'continuation.json');prefix_path=folder/'strict_prefix_reconstructions.json';prefix=read(prefix_path)
        require(digest(prefix_path)==continuation['strict_prefix_sha256'] and prefix==trials[:len(prefix)]
                and prefix[-1]['status']==4,'Original strict failure prefix was changed')
        require(continuation['module_sha256']==digest(Path(__file__).resolve().parents[1]/'docs/results/two_boards/evidence/characterize_common.py'),'Characterization source mismatch')
    return dict(passed=rejected==0,records_verified=True,board_label=env['board_label'],candidate_hex=reg['candidate_hex'],linux_boot_id=env['linux_boot_id'],
                raw_holdout_rows=sequence,min_abs_margin=minimum,reconstructions=len(trials)-1,reloads=env['reload_runs'],
                successful_reconstructions=len(trials)-1-rejected,rejected_reconstructions=rejected,
                all_transactions_successful=rejected==0,all_accepted_keys_match=True,
                corrected_words=summary['corrected_words'],bitmap_hex=plan['bitmap_hex'],bitstream_sha256=plan['bitstream_sha256'])


def compare(a_folder,b_folder,plan_path,refs,allow_rejections=False):
    a=verify_fixed(a_folder,plan_path,refs/'reference_20100.json',allow_rejections);b=verify_fixed(b_folder,plan_path,refs/'reference_20200.json',allow_rejections)
    require(a['board_label']=='20100' and b['board_label']=='20200','Endpoint role mismatch')
    if a['linux_boot_id'] and b['linux_boot_id']:require(a['linux_boot_id']!=b['linux_boot_id'],'Endpoints appear to use the same running Linux kernel')
    delta=int(a['candidate_hex'],16)^int(b['candidate_hex'],16);hd=bin(delta).count('1')
    strict=a['all_transactions_successful'] and b['all_transactions_successful']
    return dict(passed=strict and hd>0,comparison_verified=True,all_transactions_successful=strict,
                identities_differ=hd>0,hamming_distance_bits=hd,compared_bits=256,
                hamming_distance_percent=hd/256*100,differing_bit_indices=[i for i in range(256) if delta>>i&1],
                same_bitstream=a['bitstream_sha256']==b['bitstream_sha256'],same_bitmap=a['bitmap_hex']==b['bitmap_hex'],
                board_20100=a,board_20200=b,
                scope='Measured distinction of these two declared boards with one shared frozen bitmap; not a population uniqueness or entropy estimate.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    f=sub.add_parser('freeze');f.add_argument('--a',type=Path,required=True);f.add_argument('--b',type=Path,required=True);f.add_argument('--out',type=Path,required=True)
    v=sub.add_parser('verify');v.add_argument('--a',type=Path,required=True);v.add_argument('--b',type=Path,required=True);v.add_argument('--plan',type=Path,required=True);v.add_argument('--refs',type=Path,required=True);v.add_argument('--save',type=Path,required=True)
    v.add_argument('--allow-rejections',action='store_true',help='Verify a completed characterization, retaining passed=false and every rejection')
    args=parser.parse_args()
    if args.command=='freeze':result=freeze(args.a,args.b,args.out)
    else:
        result=compare(args.a,args.b,args.plan,args.refs,args.allow_rejections);write(args.save,result)
    print(json.dumps(result,indent=2))
