"""Fixed-bitmap two-board experiment. PUF and ECC are executed only in PL."""
import csv
import hashlib
import json
import platform
import random
import time
from pathlib import Path
from puf256 import Puf256
from board_validation import save,sha256


def run_fixed(board_label,plan_file='common_bitmap.json',reference_file=None,
              output=None,holdout_reads=32,reconstruction_runs=100,reload_runs=10):
    from pynq import Overlay,Clocks,__version__ as pynq_version
    board_label=str(board_label)
    if board_label not in ['20100','20200']:raise ValueError('Board label must be the declared endpoint')
    if min(holdout_reads,reconstruction_runs,reload_runs)<1:raise ValueError('Positive phase counts required')
    plan=json.loads(Path(plan_file).read_text())
    refpath=Path(reference_file or ('reference_'+board_label+'.json'))
    reference=json.loads(refpath.read_text())
    if reference['board_label']!=board_label or reference['plan_sha256']!=sha256(Path(plan_file)):
        raise RuntimeError('Wrong board reference or frozen plan')
    bitmap=int(plan['bitmap_hex'],16);pairs=[p for p in range(320) if bitmap>>p&1]
    if len(pairs)!=256 or pairs!=plan['selected_pairs']:raise RuntimeError('Invalid common bitmap')
    expected=int(reference['expected_candidate_hex'],16)
    bitfile=Path('puf256.bit').resolve()
    if sha256(bitfile)!=plan['bitstream_sha256'] or sha256(bitfile.with_suffix('.hwh'))!=plan['hwh_sha256']:
        raise RuntimeError('Overlay differs from frozen two-board experiment')
    output=Path(output or ('common_'+board_label+'_'+time.strftime('%Y%m%d_%H%M%S')))
    output.mkdir(parents=True,exist_ok=False)
    started=time.monotonic()
    boot_path=Path('/proc/sys/kernel/random/boot_id')
    env=dict(board_label=board_label,bitstream_sha256=plan['bitstream_sha256'],hwh_sha256=plan['hwh_sha256'],
             bitmap_hex=plan['bitmap_hex'],plan_sha256=sha256(Path(plan_file)),reference_sha256=sha256(refpath),
             pynq=pynq_version,python=platform.python_version(),
             linux_boot_id=boot_path.read_text().strip() if boot_path.exists() else None,
             window_cycles=100000,warmup_cycles=1024,holdout_reads=holdout_reads,
             reconstruction_runs=reconstruction_runs,reload_runs=reload_runs,
             scope='Two declared endpoints, same routed bitstream and pair order; ambient conditions. Boot ID is not a permanent chip identifier.')
    save(output/'environment.json',env);save(output/'progress.json',dict(stage='loading',passed=False))
    loads=[]
    def load():
        if sha256(bitfile)!=plan['bitstream_sha256']:raise RuntimeError('Bitstream changed')
        overlay=Overlay(str(bitfile),download=True)
        if abs(float(Clocks.fclk0_mhz)-100.0)>.1:raise RuntimeError('Wrong actual FCLK0')
        device=Puf256(getattr(overlay,'puf256_0'))
        registers=dict(bitmap=device._words(0x100,10),helper_input=device._words(0x140,3),
                       key_data=device._words(0x180,8),helper_output=device._words(0x1c0,3),
                       puf_sequence=device.ip.read(0x24),raw_sequence=device.ip.read(0x210),helper_input_valid=device.ip.read(0x30))
        if any(registers.values()):raise RuntimeError('PL reload did not clear volatile state')
        loads.append(dict(index=len(loads),fclk0_mhz=float(Clocks.fclk0_mhz),initial_volatile_registers=registers))
        save(output/'overlay_loads.json',loads);device.abort()
        return overlay,device
    overlay,device=load()
    failures=[];minimum=None;sequence=0;order=list(pairs);rng=random.Random(261113)
    with (output/'holdout.csv').open('w',newline='') as f:
        fields=['read','pair','sequence','status','count_a','count_b','delta','bit','window_cycles','warmup_cycles','frequency_a_mhz','frequency_b_mhz']
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
        for n in range(holdout_reads):
            rng.shuffle(order)
            for p in order:
                row=device.measure(p);j=pairs.index(p)
                if row['sequence']!=sequence+1:raise RuntimeError('Raw sequence discontinuity')
                sequence=row['sequence'];row['read']=n;writer.writerow(row)
                if row['status'] or row['bit']!=((expected>>j)&1) or abs(row['delta'])<8:
                    failures.append(dict(read=n,pair=p,status=row['status'],delta=row['delta']))
                if row['status']==0:minimum=abs(row['delta']) if minimum is None else min(minimum,abs(row['delta']))
            f.flush()
            if (n+1)%8==0:print(board_label,'fixed-bitmap holdout',n+1,'/',holdout_reads,flush=True)
    save(output/'holdout_verdict.json',dict(passed=not failures,failures=failures,rows=sequence,min_abs_margin=minimum))
    if failures:raise RuntimeError('Frozen common bitmap failed holdout; no re-selection from holdout')
    response=device.register(bitmap)
    if not response['ok'] or response['key']!=expected:raise RuntimeError('Hardware enrollment differs from training reference')
    helper=response['helper'];key=response['key']
    save(output/'enrollment.json',dict(board_label=board_label,bitmap_hex=plan['bitmap_hex'],helper_hex=format(helper,'020x'),
                                     bitstream_sha256=plan['bitstream_sha256'],plan_sha256=env['plan_sha256']))
    save(output/'registration.json',dict(candidate_hex=format(key,'064x'),helper_hex=format(helper,'020x'),
                                       key_sha256=hashlib.sha256(key.to_bytes(32,'little')).hexdigest(),
                                       note='Experimental PUF reference data, not a production secret store.'))
    trials=[dict(stage='registration',index=0,status=response['status'],key_sha256=hashlib.sha256(key.to_bytes(32,'little')).hexdigest(),
                 corrected_words=response['corrected_words'],sequence=response['sequence'],match=True)]
    save(output/'reconstructions.json',trials)
    def recover(stage,n):
        saved=json.loads((output/'enrollment.json').read_text())
        r=device.reconstruct(int(saved['bitmap_hex'],16),int(saved['helper_hex'],16))
        good=r['ok'] and r['key']==key
        trials.append(dict(stage=stage,index=n,status=r['status'],key_sha256=hashlib.sha256(r['key'].to_bytes(32,'little')).hexdigest() if r['key'] is not None else None,
                           corrected_words=r['corrected_words'],sequence=r['sequence'],match=good))
        save(output/'reconstructions.json',trials);save(output/'progress.json',dict(stage=stage,index=n,passed=False))
        if not good:raise RuntimeError('Fixed-bitmap reconstruction failed or changed identity')
    for n in range(reconstruction_runs):
        recover('repeat',n)
        if (n+1)%10==0:print(board_label,'common-bitmap reconstructions',n+1,'/',reconstruction_runs,flush=True)
    device.abort();recover('abort-reset',0)
    for n in range(reload_runs):
        overlay,device=load();recover('same-bitstream-reload',n)
        print(board_label,'common-bitmap reload',n+1,'/',reload_runs,flush=True)
    summary=dict(passed=True,board_label=board_label,bitmap_hex=plan['bitmap_hex'],bitstream_sha256=plan['bitstream_sha256'],
                 plan_sha256=env['plan_sha256'],candidate_hex=format(key,'064x'),key_sha256=hashlib.sha256(key.to_bytes(32,'little')).hexdigest(),
                 holdout_samples=sequence,reconstruction_count=len(trials)-1,reload_count=reload_runs,
                 corrected_words=sum(r['corrected_words'] for r in trials),elapsed_seconds=time.monotonic()-started)
    save(output/'summary.json',summary);save(output/'progress.json',dict(stage='complete',passed=True))
    print(json.dumps(summary,indent=2),flush=True)
    return summary
