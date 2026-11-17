"""Continue a stopped strict experiment without erasing/retrying failed trials.

The fixed schedule contains 100 repeat attempts, one reset attempt and ten reload
attempts. WEAK_PAIR is recorded as a rejection, never counted as a recovered key.
"""
from pathlib import Path
import hashlib
import json
import shutil
import time
from board_validation import save,sha256
from puf256 import Puf256


def resume_characterization(failed_directory):
    from pynq import Overlay,Clocks
    source=Path(failed_directory)
    old=json.loads((source/'reconstructions.json').read_text())
    if not old or old[-1]['status']!=4 or old[-1]['stage']!='repeat':
        raise RuntimeError('Only a preserved repeat-stage WEAK_PAIR stop can be continued')
    env=json.loads((source/'environment.json').read_text());label=env['board_label']
    plan=json.loads(Path('common_bitmap.json').read_text())
    if sha256(Path('common_bitmap.json'))!=env['plan_sha256'] or sha256(Path('puf256.bit'))!=env['bitstream_sha256']:
        raise RuntimeError('Frozen inputs changed')
    if sha256(Path('puf256.hwh'))!=env['hwh_sha256']:raise RuntimeError('HWH changed')
    boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
    if env.get('linux_boot_id')!=boot:raise RuntimeError('Board rebooted since strict prefix')
    output=Path('characterized_'+label+'_'+time.strftime('%Y%m%d_%H%M%S'))
    output.mkdir(exist_ok=False)
    for f in source.iterdir():
        if f.is_file():shutil.copy2(f,output/f.name)
    shutil.copy2(source/'reconstructions.json',output/'strict_prefix_reconstructions.json')
    continuation=dict(source_strict_directory=source.name,strict_prefix_sha256=sha256(source/'reconstructions.json'),
                      module_sha256=sha256(Path(__file__)),policy='Fixed attempt schedule; record every WEAK_PAIR, no automatic retries or pair replacement.')
    save(output/'continuation.json',continuation)
    reg=json.loads((output/'registration.json').read_text());key=int(reg['candidate_hex'],16)
    digest=hashlib.sha256(key.to_bytes(32,'little')).hexdigest()
    enrollment=json.loads((output/'enrollment.json').read_text())
    bitmap=int(enrollment['bitmap_hex'],16);helper=int(enrollment['helper_hex'],16)
    trials=list(old);loads=json.loads((output/'overlay_loads.json').read_text())
    overlay=Overlay('puf256.bit',download=False);device=Puf256(overlay.puf256_0)
    if abs(float(Clocks.fclk0_mhz)-100.0)>.1 or device.ip.read(0x24)!=trials[-1]['sequence']:
        raise RuntimeError('Wrong clock or another controller changed PUF sequence')

    def attempt(stage,n):
        response=device.reconstruct(bitmap,helper)
        same=response['ok'] and response['key']==key
        trials.append(dict(stage=stage,index=n,status=response['status'],key_sha256=hashlib.sha256(response['key'].to_bytes(32,'little')).hexdigest() if response['key'] is not None else None,
                           corrected_words=response['corrected_words'],sequence=response['sequence'],match=same,
                           diagnostic_pair=device.ip.read(0x2c) if response['status'] else None))
        save(output/'reconstructions.json',trials);save(output/'progress.json',dict(stage=stage,index=n,completed=False))
        if response['ok'] and not same:raise RuntimeError('An accepted identity changed; experiment stopped and recorded')
        if response['status'] not in [0,4]:raise RuntimeError('Unexpected non-WEAK_PAIR failure; stopped and recorded')

    completed=[r['index'] for r in trials if r['stage']=='repeat']
    if completed!=list(range(len(completed))) or len(completed)>env['reconstruction_runs']:
        raise RuntimeError('Strict prefix is not a contiguous fixed schedule')
    for n in range(len(completed),env['reconstruction_runs']):
        attempt('repeat',n)
        if (n+1)%10==0:print(label,'fixed scheduled attempts',n+1,'/',env['reconstruction_runs'],flush=True)
    device.abort();attempt('abort-reset',0)
    for n in range(env['reload_runs']):
        if sha256(Path('puf256.bit'))!=env['bitstream_sha256']:raise RuntimeError('Bitstream changed')
        overlay=Overlay('puf256.bit',download=True)
        if abs(float(Clocks.fclk0_mhz)-100.0)>.1:raise RuntimeError('Wrong actual FCLK0')
        device=Puf256(overlay.puf256_0)
        registers=dict(bitmap=device._words(0x100,10),helper_input=device._words(0x140,3),key_data=device._words(0x180,8),
                       helper_output=device._words(0x1c0,3),puf_sequence=device.ip.read(0x24),raw_sequence=device.ip.read(0x210),helper_input_valid=device.ip.read(0x30))
        if any(registers.values()):raise RuntimeError('Reload did not clear state')
        loads.append(dict(index=len(loads),fclk0_mhz=float(Clocks.fclk0_mhz),initial_volatile_registers=registers))
        save(output/'overlay_loads.json',loads);device.abort();attempt('same-bitstream-reload',n)
        print(label,'characterized reload attempt',n+1,'/',env['reload_runs'],flush=True)
    recovery=trials[1:];accepted=sum(r['status']==0 for r in recovery);rejected=sum(r['status']!=0 for r in recovery)
    summary=dict(completed=True,passed=rejected==0,strict_pass=rejected==0,all_accepted_keys_match=True,
                 board_label=label,bitmap_hex=plan['bitmap_hex'],bitstream_sha256=env['bitstream_sha256'],plan_sha256=env['plan_sha256'],
                 candidate_hex=reg['candidate_hex'],key_sha256=digest,holdout_samples=256*env['holdout_reads'],
                 reconstruction_count=len(recovery),reconstruction_attempts=len(recovery),successful_reconstructions=accepted,
                 rejected_reconstructions=rejected,reload_count=env['reload_runs'],corrected_words=sum(r['corrected_words'] for r in trials),
                 rejection_status_counts={str(s):sum(r['status']==s for r in recovery) for s in sorted(set(r['status'] for r in recovery))},
                 note='Completed characterization with every strict-prefix rejection preserved. passed=false if any attempt was rejected.')
    save(output/'summary.json',summary);save(output/'progress.json',dict(stage='complete',completed=True,passed=summary['passed']))
    print(json.dumps(summary,indent=2),flush=True)
    return str(output)
