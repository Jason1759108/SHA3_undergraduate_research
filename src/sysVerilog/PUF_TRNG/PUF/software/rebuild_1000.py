"""Fixed-attempt hardware reconstruction using an existing per-board enrollment.

No registration, re-selection, software ECC, or retry-until-success is performed.
Compatible with the board's Python 3.6. Only one controller may access this IP.
"""
import hashlib
import json
import os
import platform
from pathlib import Path
import time
import zipfile
from collections import Counter
from puf256 import Puf256


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True), encoding='utf-8')
    temporary.replace(path)


def run_1000(board_label, input_file=None, output=None):
    from pynq import Overlay, Clocks, __version__ as pynq_version
    board_label = str(board_label)
    if board_label not in ('20100', '20200'):
        raise ValueError('Unknown declared board endpoint')
    source = Path(input_file or ('own_enrollment_' + board_label + '.json'))
    frozen = json.loads(source.read_text(encoding='utf-8'))
    if frozen['board_label'] != board_label:
        raise ValueError('Enrollment belongs to a different declared endpoint')
    enrollment = frozen['enrollment']
    bitmap = int(enrollment['bitmap_hex'], 16)
    helper = int(enrollment['helper_hex'], 16)
    if not (0 <= bitmap < (1 << 320) and bin(bitmap).count('1') == 256 and 0 <= helper < (1 << 80)):
        raise ValueError('Invalid frozen bitmap/helper')
    bitfile = Path('puf256.bit').resolve()
    for path, expected in [(bitfile, enrollment['bitstream_sha256']),
                           (bitfile.with_suffix('.hwh'), enrollment['hwh_sha256']),
                           (Path('puf256.py'), frozen['driver_sha256'])]:
        if sha256(path) != expected:
            raise RuntimeError('Frozen overlay/driver changed: ' + str(path))
    output = Path(output or ('rebuild1000_' + board_label + '_' + time.strftime('%Y%m%d_%H%M%S')))
    output.mkdir(parents=True, exist_ok=False)
    save(output / 'frozen_input.json', frozen)
    started = time.monotonic()
    boot_path = Path('/proc/sys/kernel/random/boot_id')
    env = dict(board_label=board_label, requested_attempts=1000, client_date='2026-11-13',
               input_sha256=sha256(source), module_sha256=sha256(Path(__file__)),
               driver_sha256=sha256('puf256.py'), bitstream_sha256=sha256(bitfile),
               hwh_sha256=sha256(bitfile.with_suffix('.hwh')), pynq=pynq_version,
               python=platform.python_version(), board_started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
               linux_boot_id=boot_path.read_text().strip() if boot_path.exists() else None,
               policy='Exactly 1000 reconstruction attempts; no new registration, re-selection, or automatic retries.',
               conditions='Ambient lab conditions; no controlled temperature/voltage sweep or power cycle.')
    save(output / 'environment.json', env)
    print('BOARD', board_label, 'OUTPUT', output.name, flush=True)
    print('Frozen own bitmap:', enrollment['bitmap_hex'], flush=True)
    print('Using existing enrollment/helper; no new registration.', flush=True)
    overlay = Overlay(str(bitfile), download=True)
    device = Puf256(getattr(overlay, 'puf256_0'))
    clock = float(Clocks.fclk0_mhz)
    registers = dict(bitmap=device._words(0x100, 10), helper_input=device._words(0x140, 3),
                     key_data=device._words(0x180, 8), helper_output=device._words(0x1c0, 3),
                     puf_sequence=device.ip.read(0x24), raw_sequence=device.ip.read(0x210),
                     helper_input_valid=device.ip.read(0x30))
    if abs(clock - 100.0) > .1 or any(registers.values()):
        raise RuntimeError('Wrong clock or nonzero state after overlay load')
    save(output / 'initial_state.json', dict(fclk0_mhz=clock, volatile_registers=registers))
    device.abort()
    attempts = []
    error_text = None
    try:
        with (output / 'attempts.jsonl').open('w', encoding='utf-8') as stream:
            for index in range(1000):
                before = time.monotonic()
                response = device.reconstruct(bitmap, helper,
                    window_cycles=enrollment['window_cycles'], warmup_cycles=enrollment['warmup_cycles'])
                key = response['key']
                key_hash = hashlib.sha256(key.to_bytes(32, 'little')).hexdigest() if key is not None else None
                row = dict(attempt=index + 1, sequence=response['sequence'], command=response['command'],
                           status=response['status'], status_name=response['status_name'], error=response['error'],
                           key_hex=format(key, '064x') if key is not None else None, key_sha256=key_hash,
                           matches_enrollment=key_hash == frozen['expected_key_sha256'],
                           corrected_words=response['corrected_words'],
                           diagnostic_pair=device.ip.read(0x2c) if response['status'] == 4 else None,
                           duration_seconds=time.monotonic()-before, elapsed_seconds=time.monotonic()-started,
                           bitmap_readback_hex=format(device._words(0x100, 10), '080x'),
                           helper_readback_hex=format(device._words(0x140, 3), '020x'))
                attempts.append(row)
                stream.write(json.dumps(row, sort_keys=True) + '\n')
                stream.flush()
                if (index + 1) % 25 == 0:
                    os.fsync(stream.fileno())
                    good = sum(r['status'] == 0 and r['matches_enrollment'] for r in attempts)
                    progress = dict(completed_attempts=index+1, requested_attempts=1000, successful_matching=good,
                                    hardware_rejections=sum(r['status'] != 0 for r in attempts),
                                    accepted_mismatches=sum(r['status'] == 0 and not r['matches_enrollment'] for r in attempts),
                                    elapsed_seconds=time.monotonic()-started)
                    save(output / 'progress.json', progress)
                    print(board_label, '{}/1000'.format(index+1), 'matching={}'.format(good),
                          'rejected={}'.format(progress['hardware_rejections']),
                          'mismatched={}'.format(progress['accepted_mismatches']), flush=True)
                if row['bitmap_readback_hex'] != enrollment['bitmap_hex'] or row['helper_readback_hex'] != enrollment['helper_hex']:
                    raise RuntimeError('Enrollment registers changed during experiment')
    except Exception as exc:
        error_text = type(exc).__name__ + ': ' + str(exc)
        save(output / 'interruption.json', dict(error=error_text, completed_attempts=len(attempts)))
        raise
    finally:
        final_clock = float(Clocks.fclk0_mhz)
        matching = sum(r['status'] == 0 and r['matches_enrollment'] for r in attempts)
        rejected = sum(r['status'] != 0 for r in attempts)
        wrong = sum(r['status'] == 0 and not r['matches_enrollment'] for r in attempts)
        summary = dict(board_label=board_label, requested_attempts=1000, completed_attempts=len(attempts),
                       completed=len(attempts)==1000 and error_text is None,
                       successful_matching=matching, hardware_rejections=rejected, accepted_mismatches=wrong,
                       status_counts=dict(Counter(str(r['status']) for r in attempts)),
                       corrected_word_distribution=dict(Counter(str(r['corrected_words']) for r in attempts if r['status']==0)),
                       total_corrected_words=sum(r['corrected_words'] for r in attempts),
                       bitmap_hex=enrollment['bitmap_hex'], helper_hex=enrollment['helper_hex'],
                       expected_key_sha256=frozen['expected_key_sha256'], input_sha256=sha256(source),
                       attempts_sha256=sha256(output/'attempts.jsonl'),
                       elapsed_seconds=time.monotonic()-started, fclk0_end_mhz=final_clock,
                       files_unchanged=sha256(bitfile)==env['bitstream_sha256'] and sha256(bitfile.with_suffix('.hwh'))==env['hwh_sha256']
                           and sha256(source)==env['input_sha256'] and sha256(Path(__file__))==env['module_sha256']
                           and sha256('puf256.py')==env['driver_sha256'])
        summary['passed'] = summary['completed'] and matching==1000 and summary['files_unchanged'] and abs(final_clock-100.0)<=.1
        save(output / 'summary.json', summary)
        with zipfile.ZipFile(str(output)+'.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
            for path in sorted(output.iterdir()):
                if path.is_file():
                    bundle.write(str(path), output.name+'/'+path.name)
        print(json.dumps(summary, indent=2, sort_keys=True), flush=True)
    return summary
