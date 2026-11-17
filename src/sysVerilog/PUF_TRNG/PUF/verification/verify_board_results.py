"""Recompute frozen selection and all acceptance gates from exported raw CSVs."""
import argparse
from collections import Counter
import csv
from fractions import Fraction
import hashlib
import json
from pathlib import Path


def verify(folder):
    def read(name):return json.loads((folder/name).read_text(encoding='utf-8'))
    env=read('environment.json');selection=read('selection.json');enrollment=read('enrollment.json')
    summary=read('summary.json');trials=read('reconstructions.json')
    require=lambda ok,message: None if ok else fail(message)
    loads=read('overlay_loads.json')
    require(len(loads)==env['reload_runs']+1,'Overlay load count mismatch')
    require(all(row['index']==i and abs(row['fclk0_mhz']-100.0)<=.1 and row['volatile_state_cleared']
                and set(row['initial_volatile_registers'])=={'bitmap','helper_input','key_data','helper_output','puf_sequence','raw_sequence','helper_input_valid'}
                and all(value==0 for value in row['initial_volatile_registers'].values())
                and row['bitstream_sha256']==env['bitstream_sha256'] for i,row in enumerate(loads)),
            'PL reload/clock evidence mismatch')
    def phase(name,pairs,reads,reference=None,previous=0):
        observations={p:[] for p in pairs};seen=set()
        with (folder/(name+'.csv')).open(newline='') as stream:
            for row in csv.DictReader(stream):
                p=int(row['pair']);n=int(row['read']);identity=(n,p)
                require(row['stage']==name and p in observations and 0<=n<reads and identity not in seen,'Bad/duplicate sample identity')
                seen.add(identity)
                sequence=int(row['sequence']);require(sequence==(previous+1)&0xffffffff,'Raw sequence discontinuity');previous=sequence
                a=int(row['count_a']);b=int(row['count_b']);status=int(row['status'])
                require(0<=a<65536 and 0<=b<65536,'Count overflow')
                require(int(row['window_cycles'])==100000 and int(row['warmup_cycles'])==1024,'Measurement parameters changed')
                d=a-b;bit=int(d>0) if status==0 and d else None
                require(int(row['delta'])==d and row['bit']==('' if bit is None else str(bit)),'Raw polarity metadata mismatch')
                if status==0:require(a>0 and b>0 and max(a,b)*8*100000000/100000<=500000000,'RO timing bound exceeded or invalid ticks')
                observations[p].append((a,b,status,bit))
        require(len(seen)==len(pairs)*reads,'Missing samples')
        return observations,previous

    initial,sequence=phase('reference',list(range(320)),env['reference_reads'])
    refs={}
    for p,rows in initial.items():
        bits={r[3] for r in rows}
        refs[p]=rows[0][3] if len(bits)==1 and None not in bits and all(r[2]==0 and abs(r[0]-r[1])>=8 for r in rows) else None
    train,sequence=phase('training',list(range(320)),env['training_reads'],refs,sequence)
    ranks=[]
    for p,rows in train.items():
        if refs[p] is not None and all(s==0 and bit==refs[p] and abs(a-b)>=8 for a,b,s,bit in rows):
            ranks.append((min(Fraction(abs(a-b),a+b) for a,b,_,_ in rows),min(abs(a-b) for a,b,_,_ in rows),p))
    ranked=[item[2] for item in sorted(ranks,key=lambda x:(-x[0],-x[1],x[2]))]
    selected=sorted(ranked[:256])
    require(len(selected)==256 and selection['complete'] and selected==selection['selected_pairs'],'Frozen selection mismatch')
    require(ranked==selection['ranked_eligible'] and len(ranked)==selection['eligible_count'],'Training ranking mismatch')
    bitmap=sum(1<<p for p in selected)
    candidate=sum(refs[p]<<j for j,p in enumerate(selected))
    require(selection['bitmap_hex']==format(bitmap,'080x') and selection['reference_candidate_hex']==format(candidate,'064x'),'Bit ordering mismatch')
    held,sequence=phase('holdout',selected,env['holdout_reads'],refs,sequence)
    require(all(s==0 and bit==refs[p] and abs(a-b)>=8 for p,rows in held.items() for a,b,s,bit in rows),'Frozen holdout failed')
    helper=0
    for w in range(16):
        syndrome=0
        for b in range(16):
            if candidate>>(16*w+b)&1:syndrome^=16 | (b+1 if b<15 else 0)
        helper|=syndrome<<(5*w)
    require(enrollment['bitmap_hex']==selection['bitmap_hex'] and enrollment['helper_hex']==format(helper,'020x'),'Hardware helper disagrees with independent syndrome')
    require(env['bitstream_sha256']==enrollment['bitstream_sha256']==selection['bitstream_sha256']==summary['bitstream_sha256'],'Bitstream identity mismatch')
    require(enrollment['hwh_sha256']==env['hwh_sha256'],'HWH identity mismatch')
    plan=[('registration',0)]+[('repeat',n) for n in range(env['reconstruction_runs'])]+[('abort-reset',0)]+[('same-bitstream-reload',n) for n in range(env['reload_runs'])]
    require([(r['stage'],r['index']) for r in trials]==plan,'Missing/duplicate reconstruction trials')
    digest=hashlib.sha256(candidate.to_bytes(32,'little')).hexdigest()
    seq=0
    for result in trials:
        if result['stage']=='same-bitstream-reload':seq=0
        seq+=1
        require(result['match'] and result['status']==0 and result['key_sha256']==digest and 0<=result['corrected_words']<=16,'Reconstructed candidate differs or error')
        require(result['sequence']==seq,'PUF sequence mismatch across reset/reload')
    corrected=sum(r['corrected_words'] for r in trials)
    require(summary['passed'] and summary['eligible_pairs']==len(ranked) and summary['selected_pairs']==256,'Summary mismatch')
    require(summary['reference_samples']==320*env['reference_reads'] and summary['training_samples']==320*env['training_reads'] and summary['holdout_samples']==256*env['holdout_reads'],'Summary row counts mismatch')
    require(summary['reconstruction_count']==len(trials)-1 and summary['reload_count']==env['reload_runs'] and summary['total_corrected_words']==corrected,'Summary trial counts mismatch')
    return dict(passed=True,bitstream_sha256=env['bitstream_sha256'],raw_rows=sequence,
                eligible_pairs=len(ranked),selected_pairs=256,reconstructions=len(trials)-1,
                same_bitstream_reloads=env['reload_runs'],total_corrected_words=corrected,
                corrected_word_distribution=dict(Counter(str(r['corrected_words']) for r in trials[1:])),
                verification='Independent CSV ranking, margin, polarity, helper syndrome, output digest and completion sequence checks')


def fail(message):raise ValueError(message)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path);parser.add_argument('--save',type=Path)
    args=parser.parse_args();result=verify(args.folder)
    text=json.dumps(result,indent=2);print(text)
    if args.save:args.save.write_text(text,encoding='utf-8')
