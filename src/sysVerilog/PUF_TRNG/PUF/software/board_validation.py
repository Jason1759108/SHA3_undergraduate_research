"""Repeatable single-board lab experiment; no Python ECC or key generation.

The host retains a reference candidate ONLY to check experimental reproducibility.
enrollment.json contains public reconstruction data, not this reference candidate.
"""
import csv
import hashlib
import json
import platform
from pathlib import Path
import random
import time

from puf256 import Puf256
from puf_screening import Stats,references,freeze,validate


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path,value):
    path=Path(path)
    temporary=path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(value,indent=2,sort_keys=True),encoding='utf-8')
    temporary.replace(path)


def run_validation(bitfile='puf256.bit',output=None,reference_reads=32,training_reads=128,
                   holdout_reads=32,reconstruction_runs=100,reload_runs=10):
    from pynq import Overlay,Clocks,__version__ as pynq_version
    if min(reference_reads,training_reads,holdout_reads,reconstruction_runs,reload_runs)<1:
        raise ValueError('All phase counts must be positive')
    bitfile=Path(bitfile).resolve()
    output=Path(output or ('results_'+time.strftime('%Y%m%d_%H%M%S')))
    output.mkdir(parents=True,exist_ok=False)
    started=time.monotonic()
    identity=dict(bitstream_sha256=sha256(bitfile),hwh_sha256=sha256(bitfile.with_suffix('.hwh')),
                  python=platform.python_version(),pynq=pynq_version,
                  started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
                  timestamp_note='Board wall clock may differ from client; elapsed time uses monotonic clock.',
                  reference_reads=reference_reads,training_reads=training_reads,
                  holdout_reads=holdout_reads,reconstruction_runs=reconstruction_runs,reload_runs=reload_runs,
                  window_cycles=100000,warmup_cycles=1024,system_hz=100000000,
                  conditions='One PYNQ-Z2, ambient lab conditions; no controlled voltage/temperature sweep.')
    save(output/'environment.json',identity)
    save(output/'progress.json',dict(stage='loading',passed=False))

    loads=[]
    def load():
        if sha256(bitfile)!=identity['bitstream_sha256'] or sha256(bitfile.with_suffix('.hwh'))!=identity['hwh_sha256']:
            raise RuntimeError('Overlay files changed during experiment')
        overlay=Overlay(str(bitfile),download=True)
        if 'puf256_0' not in overlay.ip_dict:raise RuntimeError('Missing puf256_0 in HWH')
        clock=float(Clocks.fclk0_mhz)
        if abs(clock-100.0)>.1:raise RuntimeError('FCLK0 is not 100 MHz')
        device=Puf256(getattr(overlay,'puf256_0'))
        registers=dict(bitmap=device._words(0x100,10),helper_input=device._words(0x140,3),
                       key_data=device._words(0x180,8),helper_output=device._words(0x1c0,3),
                       puf_sequence=device.ip.read(0x24),raw_sequence=device.ip.read(0x210),
                       helper_input_valid=device.ip.read(0x30))
        cleared=not any(registers.values())
        if not cleared:raise RuntimeError('PL reload did not clear volatile state')
        loads.append(dict(index=len(loads),fclk0_mhz=clock,volatile_state_cleared=cleared,
                          initial_volatile_registers=registers,
                          bitstream_sha256=identity['bitstream_sha256']))
        save(output/'overlay_loads.json',loads)
        device.abort()
        return overlay,device

    overlay,device=load()
    generator=random.Random(261113)
    fields=['stage','read','pair','sequence','status','count_a','count_b','delta','bit',
            'window_cycles','warmup_cycles','frequency_a_mhz','frequency_b_mhz']

    def acquire(stage,pairs,reads,reference=None):
        stats=[Stats(None if reference is None else reference[p]) for p in range(320)]
        with (output/(stage+'.csv')).open('w',newline='') as stream:
            writer=csv.DictWriter(stream,fieldnames=fields)
            writer.writeheader()
            for n in range(reads):
                order=list(pairs);generator.shuffle(order)
                for p in order:
                    row=device.measure(p)
                    stats[p].add(row)
                    row.update(stage=stage,read=n)
                    writer.writerow(row)
                stream.flush()
                if (n+1)%8==0 or n+1==reads:
                    print(stage,n+1,'/',reads,flush=True)
                    save(output/'progress.json',dict(stage=stage,reads_complete=n+1,passed=False))
        save(output/(stage+'_stats.json'),[s.record(p) for p,s in enumerate(stats)])
        return stats

    initial=acquire('reference',range(320),reference_reads)
    reference=references(initial,reference_reads)
    training=acquire('training',range(320),training_reads,reference)
    selection=freeze(reference,training,training_reads)
    selection.update(bitstream_sha256=identity['bitstream_sha256'],window_cycles=100000,warmup_cycles=1024)
    save(output/'selection.json',selection)
    if not selection['complete']:raise RuntimeError('Fewer than 256 eligible pairs; no PUF enrollment performed')
    bitmap=int(selection['bitmap_hex'],16)
    expected=int(selection['reference_candidate_hex'],16)

    holdout=acquire('holdout',selection['selected_pairs'],holdout_reads,reference)
    holdout_verdict=validate(selection,holdout,holdout_reads)
    save(output/'holdout_verdict.json',holdout_verdict)
    if not holdout_verdict['passed']:raise RuntimeError('Frozen selection failed holdout; do not reselect from holdout')

    result=device.register(bitmap)
    if not result['ok'] or result['key']!=expected:raise RuntimeError('Hardware registration disagrees with frozen reference')
    helper=result['helper']
    enrollment=dict(format='puf256-public-reconstruction-v1',bitmap_hex=selection['bitmap_hex'],
                    helper_hex=format(helper,'020x'),window_cycles=100000,warmup_cycles=1024,
                    bitstream_sha256=identity['bitstream_sha256'],hwh_sha256=identity['hwh_sha256'],
                    note='No stored key. Helper/bitmap are not authenticated by this prototype.')
    save(output/'enrollment.json',enrollment)
    results=[dict(stage='registration',index=0,status=result['status'],corrected_words=result['corrected_words'],match=True,
                  key_sha256=hashlib.sha256(result['key'].to_bytes(32,'little')).hexdigest(),sequence=result['sequence'])]
    save(output/'reconstructions.json',results)

    def reconstruct(stage,index):
        saved=json.loads((output/'enrollment.json').read_text(encoding='utf-8'))
        if saved['bitstream_sha256']!=sha256(bitfile):raise RuntimeError('Enrollment belongs to another bitstream')
        before=time.monotonic()
        response=device.reconstruct(int(saved['bitmap_hex'],16),int(saved['helper_hex'],16),
                                    saved['window_cycles'],saved['warmup_cycles'])
        match=response['ok'] and response['key']==expected
        results.append(dict(stage=stage,index=index,status=response['status'],
                            corrected_words=response['corrected_words'],match=match,
                            key_sha256=hashlib.sha256(response['key'].to_bytes(32,'little')).hexdigest() if response['key'] is not None else None,
                            elapsed_seconds=time.monotonic()-before,sequence=response['sequence']))
        save(output/'reconstructions.json',results)
        save(output/'progress.json',dict(stage=stage,index=index,passed=False))
        if not match:raise RuntimeError('Reconstruction failed or differed from enrolled candidate')

    for n in range(reconstruction_runs):
        reconstruct('repeat',n)
        if (n+1)%10==0:print('PUF reconstructions',n+1,'/',reconstruction_runs,flush=True)
    device.abort()  # Clears core/output, retains only public input configuration.
    reconstruct('abort-reset',0)
    for n in range(reload_runs):
        overlay,device=load()  # Global PL reset erases bitmap/helper registers too.
        if device.ip.read(0x100)!=0 or device.ip.read(0x24)!=0 or device.ip.read(0x180)!=0:
            raise RuntimeError('Reload did not clear volatile state')
        reconstruct('same-bitstream-reload',n)
        print('reload/reconstruct',n+1,'/',reload_runs,flush=True)
    summary=dict(passed=True,bitstream_sha256=identity['bitstream_sha256'],
                 eligible_pairs=selection['eligible_count'],selected_pairs=256,
                 reference_samples=320*reference_reads,training_samples=320*training_reads,
                 holdout_samples=256*holdout_reads,holdout=holdout_verdict,
                 reconstruction_count=len(results)-1,reload_count=reload_runs,
                 total_corrected_words=sum(r['corrected_words'] for r in results),
                 elapsed_seconds=time.monotonic()-started,
                 scope='Single board, fixed routed bitstream, ambient conditions. No authentication, SHA3, entropy or multi-device uniqueness claim.')
    save(output/'summary.json',summary)
    save(output/'progress.json',dict(stage='complete',passed=True))
    print(json.dumps(summary,indent=2),flush=True)
    return summary
