"""Run the actual vendor check with a deadline measured AFTER checkpoint load.

Diagnostic reduced-clock models are never used to qualify hardware. A captured
Vivado PID belongs to this newly launched child and is held by a Windows process
handle, so timeout cleanup cannot accidentally target a reused PID.
"""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--vivado', default='C:/AMDDesignTools/2026.1/Vivado/bin/vivado.bat')
    p.add_argument('--checkpoint', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--checks', default='TIMING-1')
    p.add_argument('--keep-ro', type=int, default=-1)
    p.add_argument('--analysis-timeout', type=float, default=90)
    p.add_argument('--group-ro', action='store_true')
    p.add_argument('--stop-feedback', action='store_true')
    p.add_argument('--explicit-input-jitter', action='store_true')
    p.add_argument('--threads', type=int, default=2)
    p.add_argument('--setup-tcl', type=Path)
    p.add_argument('--restore-xdc', type=Path)
    p.add_argument('--pre-open-tcl', type=Path)
    p.add_argument('--post-tcl', type=Path)
    a = p.parse_args()
    if not -1 <= a.keep_ro <= 640 or a.analysis_timeout <= 0 or not 1<=a.threads<=32:
        p.error('Invalid RO count or deadline')
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env.update(PUF_PROBE_CHECKPOINT=str(a.checkpoint.resolve()), PUF_PROBE_OUTPUT=str(out),
               PUF_PROBE_KEEP_RO=str(a.keep_ro), PUF_PROBE_CHECKS=a.checks,
               PUF_PROBE_GROUP_RO='1' if a.group_ro else '0',
               PUF_PROBE_STOP_FEEDBACK='1' if a.stop_feedback else '0',
               PUF_PROBE_EXPLICIT_INPUT_JITTER='1' if a.explicit_input_jitter else '0',
               PUF_PROBE_THREADS=str(a.threads))
    env['PUF_PROBE_SETUP_TCL'] = str(a.setup_tcl.resolve()) if a.setup_tcl else ''
    env['PUF_PROBE_RESTORE_XDC'] = str(a.restore_xdc.resolve()) if a.restore_xdc else ''
    env['PUF_PROBE_PRE_OPEN_TCL'] = str(a.pre_open_tcl.resolve()) if a.pre_open_tcl else ''
    env['PUF_PROBE_POST_TCL'] = str(a.post_tcl.resolve()) if a.post_tcl else ''
    runner = ROOT / 'verification/methodology_diagnostics/methodology_probe.tcl'
    cmd = [str(Path(a.vivado).resolve()), '-mode', 'batch', '-nojournal', '-notrace',
           '-log', str(out / 'vivado.log'), '-source', str(runner)]
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    process_handle = None
    started = time.monotonic()
    analysis_started = None
    result = dict(checkpoint=str(a.checkpoint.resolve()), checks=a.checks, keep_ro=a.keep_ro,
                  checkpoint_sha256=hashlib.sha256(a.checkpoint.read_bytes()).hexdigest(),
                  analysis_timeout_s=a.analysis_timeout, diagnostic_only=True, group_ro=a.group_ro,
                  stop_feedback=a.stop_feedback, explicit_input_jitter=a.explicit_input_jitter, threads=a.threads)
    result['setup_tcl'] = env['PUF_PROBE_SETUP_TCL']
    result['restore_xdc'] = env['PUF_PROBE_RESTORE_XDC']
    result['pre_open_tcl'] = env['PUF_PROBE_PRE_OPEN_TCL']
    result['post_tcl'] = env['PUF_PROBE_POST_TCL']
    if a.restore_xdc:
        result['restore_xdc_sha256'] = hashlib.sha256(a.restore_xdc.read_bytes()).hexdigest()
    log = out / 'console.log'
    with log.open('w', encoding='utf-8') as stdout:
        child = subprocess.Popen(cmd, cwd=out, env=env, stdout=stdout, stderr=subprocess.STDOUT,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            while True:
                data = log.read_text(encoding='utf-8', errors='replace')
                pid = re.search(r'^PUF_PROBE_PID (\d+)$', data, re.M)
                if pid and process_handle is None:
                    result['vivado_pid'] = int(pid[1])
                    process_handle = kernel.OpenProcess(0x0001 | 0x00100000, False, int(pid[1]))
                    if not process_handle:
                        raise OSError(ctypes.get_last_error(), 'OpenProcess failed')
                ready = re.search(r'^PUF_PROBE_READY (.+)$', data, re.M)
                if ready and analysis_started is None:
                    analysis_started = time.monotonic()
                    result['ready'] = ready[1]
                    print('ANALYSIS_STARTED ' + ready[1], flush=True)
                done = re.search(r'^PUF_PROBE_DONE elapsed_ms=(\d+)$', data, re.M)
                if done:
                    audited = re.search(r'^PUF_PROBE_CLOCK_AUDIT (\d+)$', data, re.M)
                    if audited:
                        result['audited_clocks'] = int(audited[1])
                    result.update(verdict='RETURNED', analysis_elapsed_s=int(done[1]) / 1000)
                    break
                if (out / 'STOP_PROBE').exists():
                    result.update(verdict='PROFILE_CAPTURED', analysis_elapsed_s=(time.monotonic()-analysis_started) if analysis_started else None)
                    break
                if child.poll() is not None:
                    result.update(verdict='TOOL_ERROR', exit_code=child.returncode)
                    break
                if analysis_started is not None and time.monotonic() - analysis_started > a.analysis_timeout:
                    result.update(verdict='ANALYSIS_TIMEOUT', analysis_elapsed_s=time.monotonic()-analysis_started)
                    break
                if analysis_started is None and time.monotonic() - started > 240:
                    result.update(verdict='LOAD_TIMEOUT')
                    break
                time.sleep(0.25)
        finally:
            if result.get('verdict') != 'RETURNED' and process_handle:
                kernel.TerminateProcess(process_handle, 124)
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                if process_handle:
                    kernel.TerminateProcess(process_handle, 124)
                child.kill()
                child.wait(timeout=15)
            if process_handle:
                kernel.CloseHandle(process_handle)
    result['total_elapsed_s'] = time.monotonic() - started
    (out / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2), flush=True)
    return 0 if result['verdict'] == 'RETURNED' else 1


if __name__ == '__main__':
    raise SystemExit(main())
