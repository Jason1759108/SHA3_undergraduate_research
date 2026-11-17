"""Independently check 1000-attempt evidence; record verification is not a pass verdict."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import statistics


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def verify(folder, kit=None):
    folder = Path(folder)
    kit = Path(kit) if kit else Path(__file__).resolve().parents[1]
    env = read(folder/'environment.json')
    label = env['board_label']
    require(label in ['20100','20200'], 'Unknown board role')
    original = kit/'docs/results/rebuild_1000/inputs'/label/('own_enrollment_'+label+'.json')
    frozen = read(original)
    # The board reserializes this snapshot using Linux newlines. The source file's
    # exact byte hash is checked separately against env['input_sha256'] below.
    require(read(folder/'frozen_input.json')==frozen, 'Frozen input changed')
    enrol = frozen['enrollment']
    base = kit/'docs/results/rebuild_1000/provenance'/label
    for name, expected in frozen['source_sha256'].items():
        require(sha(base/name)==expected, 'Baseline provenance changed '+name)
    require(read(base/'enrollment.json')==enrol, 'Own enrollment differs from baseline')
    selection = read(base/'selection.json')
    expected = int(selection['reference_candidate_hex'],16)
    expected_hash = hashlib.sha256(expected.to_bytes(32,'little')).hexdigest()
    baseline = read(base/'reconstructions.json')
    require(baseline[0]['stage']=='registration' and baseline[0]['key_sha256']==expected_hash
            ==frozen['expected_key_sha256'], 'Expected identity is not original registration')
    require(selection['bitmap_hex']==enrol['bitmap_hex'] and bin(int(enrol['bitmap_hex'],16)).count('1')==256,
            'Own bitmap changed or incorrect count')
    helper = 0
    for word in range(16):
        syndrome = 0
        for bit in range(16):
            if expected >> (16*word+bit) & 1:
                syndrome ^= 16 | (bit+1 if bit<15 else 0)
        helper |= syndrome << (5*word)
    require(enrol['helper_hex']==format(helper,'020x'), 'Helper syndrome differs from original identity')
    require(env['requested_attempts']==1000 and env['input_sha256']==sha(original), 'Wrong fixed input/schedule')
    require(env['module_sha256']==sha(kit/'docs/results/rebuild_1000/evidence/rebuild_1000.py'), 'Runner source changed')
    require(env['driver_sha256']==frozen['driver_sha256']==sha(kit/'docs/results/rebuild_1000/evidence/puf256.py'), 'Driver changed')
    for name, field in [('puf256.bit','bitstream_sha256'),('puf256.hwh','hwh_sha256')]:
        release=read(kit/'docs/results/single_board/original_board_manifest.json')
        require(env[field]==enrol[field]==release['files'][name]['sha256'],'Overlay identity changed '+name)
    initial=read(folder/'initial_state.json')
    require(abs(initial['fclk0_mhz']-100.0)<=.1,'Initial FCLK incorrect')
    required={'bitmap','helper_input','key_data','helper_output','puf_sequence','raw_sequence','helper_input_valid'}
    require(set(initial['volatile_registers'])==required and not any(initial['volatile_registers'].values()),
            'State not zero following initial overlay load')
    rows=[json.loads(line) for line in (folder/'attempts.jsonl').read_text(encoding='utf-8').splitlines()]
    require(len(rows)==1000,'Not exactly 1000 recorded attempts')
    known={0:'PUF_OK',1:'PUF_BAD_COMMAND',2:'PUF_MEASURE_TIMEOUT',4:'PUF_WEAK_PAIR',5:'PUF_ECC_UNCORRECTABLE',
           6:'PUF_MISSING_HELPER',7:'PUF_BAD_BITMAP',8:'PUF_BAD_WINDOW',9:'PUF_BAD_WARMUP',10:'PUF_RO_STOPPED',
           11:'PUF_RO_SATURATED',12:'PUF_BACKEND_FAULT'}
    matching=rejected=wrong=0
    previous=0.0
    for index,row in enumerate(rows,1):
        require(row['attempt']==row['sequence']==index and row['command']==1,'Missing/duplicate attempt or changed hardware sequence')
        require(row['bitmap_readback_hex']==enrol['bitmap_hex'] and row['helper_readback_hex']==enrol['helper_hex'],
                'Enrollment registers changed')
        status=row['status']
        require(status in known and row['status_name']==known[status] and row['error']==int(status!=0),'Inconsistent status packet')
        require(0<row['duration_seconds']<=row['elapsed_seconds']-previous+.001,'Invalid/overlapping attempt time')
        previous=row['elapsed_seconds']
        require(0<=row['corrected_words']<=16,'Invalid correction count')
        if status==0:
            value=int(row['key_hex'],16)
            require(0<=value<1<<256 and row['key_hex']==format(value,'064x'),'Invalid accepted key length')
            digest=hashlib.sha256(value.to_bytes(32,'little')).hexdigest()
            require(digest==row['key_sha256'] and row['matches_enrollment']==(digest==expected_hash),'Identity digest/match flag mismatch')
            require(row['diagnostic_pair'] is None,'Unexpected failed pair on success')
            if digest==expected_hash:matching+=1
            else:wrong+=1
        else:
            rejected+=1
            require(row['key_hex'] is None and row['key_sha256'] is None and not row['matches_enrollment']
                    and row['corrected_words']==0,'Rejected transaction exposed/counts a key')
            if status==4:
                pair=row['diagnostic_pair']
                require(isinstance(pair,int) and 0<=pair<320 and int(enrol['bitmap_hex'],16)>>pair&1,
                        'Weak-pair diagnostic is not selected')
    summary=read(folder/'summary.json')
    status_counts=dict(Counter(str(r['status']) for r in rows))
    corrected=dict(Counter(str(r['corrected_words']) for r in rows if r['status']==0))
    total=sum(r['corrected_words'] for r in rows)
    for name,value in dict(board_label=label,requested_attempts=1000,completed_attempts=1000,completed=True,
                           successful_matching=matching,hardware_rejections=rejected,accepted_mismatches=wrong,
                           status_counts=status_counts,corrected_word_distribution=corrected,total_corrected_words=total,
                           bitmap_hex=enrol['bitmap_hex'],helper_hex=enrol['helper_hex'],expected_key_sha256=expected_hash,
                           input_sha256=sha(original),attempts_sha256=sha(folder/'attempts.jsonl')).items():
        require(summary[name]==value,'Summary mismatch '+name)
    require(summary['files_unchanged'] and abs(summary['fclk0_end_mhz']-100.0)<=.1,'Final file/clock check failed')
    require(summary['elapsed_seconds']>=previous and summary['passed']==(matching==1000),'Invalid final time/pass verdict')
    blocks=[]
    for start in range(0,1000,100):
        batch=rows[start:start+100]
        blocks.append(dict(first=start+1,last=start+100,
                           successful_matching=sum(r['status']==0 and r['matches_enrollment'] for r in batch),
                           hardware_rejections=sum(r['status']!=0 for r in batch),
                           accepted_mismatches=sum(r['status']==0 and not r['matches_enrollment'] for r in batch)))
    return dict(records_verified=True,passed=matching==1000,board_label=label,attempts=1000,
                successful_matching=matching,hardware_rejections=rejected,accepted_mismatches=wrong,
                status_counts=status_counts,total_corrected_words=total,corrected_word_distribution=corrected,
                duration_seconds=summary['elapsed_seconds'],median_attempt_seconds=statistics.median(r['duration_seconds'] for r in rows),
                minimum_attempt_seconds=min(r['duration_seconds'] for r in rows),maximum_attempt_seconds=max(r['duration_seconds'] for r in rows),
                rejection_pair_counts=dict(Counter(str(r['diagnostic_pair']) for r in rows if r['status']==4)),
                original_registration_hex=format(expected,'064x'),bitmap_hex=enrol['bitmap_hex'],
                bitstream_sha256=env['bitstream_sha256'],linux_boot_id=env['linux_boot_id'],blocks_of_100=blocks)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path)
    parser.add_argument('--save',type=Path)
    args=parser.parse_args()
    result=verify(args.folder)
    text=json.dumps(result,indent=2,sort_keys=True)
    if args.save:
        args.save.write_text(text,encoding='utf-8')
    print(text)
