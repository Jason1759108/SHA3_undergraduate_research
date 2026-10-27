"""One invocation runs this version's complete paper RTL suite. No third-party Python packages.
Workstation: python (2.7 or 3.x) run_all_rtl.py
Local validation: --simulator verilator --verilator PATH --cxx PATH --output DIR
"""
from __future__ import print_function, division
import argparse
import csv
import hashlib
import json
import os
from paper_compat import Path, emit, run_process, which, isfinite, csv_open, DictWriter
import re
import shutil
import subprocess
from datetime import datetime

TB = Path(__file__).resolve().parent
ROOT = TB.parent
VERSION = ROOT.name
if VERSION not in ('V0_C3_NoFT','V1_State1600_SECDED_Replay',
                   'V2_Lane64_SECDED_Replay','V3_LaneParity_LocalReplay'):
    raise SystemExit('[FAIL] Keep the supplied V0/V1/V2/V3 directory name; it selects the required test suite.')


def fingerprint():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for folder in ('00_TESTBED', '01_RTL')
            for p in sorted((ROOT / folder).iterdir())
            if p.is_file() and (p.suffix in ('.sv','.f','.py','.sh') or p.name=='Makefile')}


def run(command, log, cwd, env):
    with log.open('w', encoding='utf-8') as stream:
        stream.write(u'COMMAND: ' + repr(command) + '\n'); stream.flush()
        result = run_process(command, cwd=cwd, env=env, stdout=stream,
                                stderr=subprocess.STDOUT, timeout=1800)
    if result.returncode:
        raise RuntimeError('Command failed ({}): {}\n'.format(result.returncode, log) +
                           log.read_text(encoding='utf-8', errors='replace')[-5000:])


def suite():
    normal = [str((TB / s.strip()).resolve()) for s in (TB / 'filelist.f').read_text().splitlines()
              if s.strip() and not s.lstrip().startswith('//')]
    rtl = [s for s in normal if '/01_RTL/' in Path(s).as_posix()]
    result = [('normal', 'TESTBED', normal + [str(TB/'paper_cycle_monitor.sv')], [], '[SUCCESS]')]
    if not VERSION.startswith('V0_'):
        define = 'FT_PATTERN_1600' if VERSION.startswith('V1_') else 'FT_PATTERN'
        result += [('ft', 'TESTBED', normal, [define], '[SUCCESS]'),
                   ('cross_lane', 'TESTBED', rtl+[str(TB/'TESTBED_CROSS_LANE.sv')], [], '[SUCCESS]')]
    if VERSION.startswith(('V1_', 'V2_')):
        result += [('hamming_unit', 'tb_hamming64',
                    [str(ROOT/'01_RTL'/s) for s in ('sha3_pkg.sv', 'keccak_hamming64.sv')]+
                    [str(TB/'tb_hamming64.sv')], [], 'fail=0')]
    if VERSION.startswith('V1_'):
        result += [('hamming1600_unit', 'tb_hamming1600',
                    [str(ROOT/'01_RTL'/s) for s in ('sha3_pkg.sv', 'keccak_hamming64.sv')]+
                    [str(TB/'tb_hamming1600.sv')], [], '[SUCCESS]')]
    if VERSION.startswith('V3_'):
        result += [('parity_unit', 'tb_parity_predictor',
                    [str(ROOT/'01_RTL'/s) for s in ('sha3_pkg.sv', 'keccak_parity_predictor.sv', 'keccak_lane_parity.sv')]+
                    [str(TB/'tb_parity_predictor.sv')], [], '[SUCCESS]')]
    result += [('core', 'TESTBED_CORE', rtl+[str(ROOT/'01_RTL/paper_keccak_core.sv'),
                                         str(TB/'TESTBED_CORE.sv')], [], '[SUCCESS]')]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', choices=['vcs', 'verilator'], default='vcs')
    parser.add_argument('--verilator', default='verilator')
    parser.add_argument('--cxx', help='Native C++ compiler; used with Verilator --cc/--main')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--only', help='Development-only subset; cannot authorize a sweep')
    args = parser.parse_args()
    out = (args.output or ROOT/'results'/'rtl'/datetime.now().strftime('%Y%m%d_%H%M%S')).resolve()
    out.mkdir(parents=True, exist_ok=False)
    before = fingerprint()
    results = []
    cases = []
    env = os.environ.copy()
    env['PATH'] = str(Path(args.cxx).resolve().parent) + os.pathsep + env['PATH'] if args.cxx else env['PATH']
    if args.simulator == 'verilator':
        verilator = Path(which(args.verilator) or args.verilator).resolve()
        runtime = verilator.parent.parent/'include'
        env['VERILATOR_ROOT'] = str(verilator.parent.parent)
    try:
        for mode, top, files, defines, success in suite():
            if args.only and mode not in args.only.split(','): continue
            build = out/mode; build.mkdir()
            filelist = build/'files.f'
            filelist.write_text('\n'.join('"'+s.replace('\\','/')+'"' for s in files)+'\n', encoding='utf-8')
            emit('[INFO] {}: {}'.format(VERSION, mode), flush=True)
            exe = build/('sim.exe' if os.name == 'nt' else 'simv')
            if args.simulator == 'vcs':
                command = ['vcs', '-full64', '-sverilog', '-timescale=1ns/1ps',
                           '-debug_access+all', '-top', top, '-f', str(filelist),
                           '-Mdir='+str(build/'csrc'), '-o', str(exe), '+define+NO_DUMP']
                command += ['+define+'+d for d in defines]
                run(command, build/'compile.log', TB, env)
            else:
                command = [str(verilator), '--timing', '--assert', '-Wno-fatal', '--top-module', top,
                           '--prefix', 'VPAPER', '--Mdir', str(build), '-DNO_DUMP', '-f', str(filelist)]
                command += ['-D'+d for d in defines]
                command += ['--cc', '--main'] if args.cxx else ['--binary', '-j', '2', '-o', str(exe)]
                run(command, build/'compile.log', TB, env)
                if args.cxx:
                    cmd = [args.cxx, '-std=c++20', '-O0', '-DVL_TIME_CONTEXT',
                           '-I'+str(runtime), '-I'+str(build)]
                    cmd += [str(p) for p in sorted(build.glob('*.cpp'))]
                    cmd += [str(runtime/s) for s in ('verilated.cpp', 'verilated_threads.cpp', 'verilated_timing.cpp')]
                    cmd += ['-o', str(exe)]
                    run(cmd, build/'build.log', TB, env)
            run([str(exe)], build/'simulation.log', build, env)
            text = (build/'simulation.log').read_text(encoding='utf-8', errors='replace')
            if success not in text or re.search(r'\[FAIL\]|\bFatal\b|%Error|\bFATAL\b', text):
                raise RuntimeError('{}: missing success marker or failure in {}/simulation.log'.format(mode, build))
            results.append({'test': mode, 'status': 'PASS', 'log': str(build/'simulation.log')})
            for line in text.splitlines():
                if '[PASS]' in line:
                    fields=dict(re.findall(r'(\w+)=([^\s]+)',line))
                    cases.append(dict(test=mode,case=line.split('[PASS]',1)[1].strip().split()[0],
                                      details=line,measurements=json.dumps(fields)))
            emit('[PASS] {}'.format(mode), flush=True)
        if fingerprint() != before: raise RuntimeError('Sources changed during regression')
        if not args.only:
            with csv_open(out/'case_results.csv') as f:
                w=DictWriter(f,fieldnames=['test','case','details','measurements'])
                w.writeheader();w.writerows(cases)
            text = (out/'normal/simulation.log').read_text(encoding='utf-8', errors='replace')
            rows = [dict(zip(['message_bytes','e2e_cycles','permutations','core_cycles_total'], m))
                    for m in re.findall(r'\[METRIC\] bytes=(\d+) e2e_cycles=(\d+) permutations=(\d+) core_cycles_total=(\d+)',text)]
            selected = [r for r in rows if r['message_bytes']=='4096']
            if len(selected)!=1 or int(selected[0]['permutations'])!=31:
                raise RuntimeError('Missing unique 4096-byte/31-permutation measurement')
            with csv_open(out/'latency.csv') as f:
                w=DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
            core_text=(out/'core/simulation.log').read_text(encoding='utf-8',errors='replace')
            core_cycles={int(c) for c in re.findall(r'\[CORE_METRIC\] cycles=(\d+)',core_text)}
            if len(core_cycles)!=1: raise RuntimeError('Core cycles absent or inconsistent')
            record=dict(version=VERSION,status='PASS',simulator=args.simulator,
                        timestamp=datetime.now().isoformat(),source_sha256=before,tests=results,
                        message=selected[0],standalone_core_cycles=core_cycles.pop(),output=str(out))
            (out/'rtl_summary.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
            (ROOT/'rtl_latest.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
        emit('[SUCCESS] Complete RTL suite passed!' if not args.only else '[SUCCESS] Selected development tests passed (not a full-suite approval).')
        emit(out)
    except Exception as exc:
        (out/'FAILED.txt').write_text(str(exc),encoding='utf-8')
        emit('[FAIL] {}'.format(exc),flush=True)
        raise SystemExit(1)


if __name__ == '__main__': main()
