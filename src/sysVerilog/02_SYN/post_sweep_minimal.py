"""Append one result per clock period to one CSV. Python 2.7/3."""
from __future__ import print_function, division
import csv
import hashlib
import json
import os
import shutil
import sys
from paper_compat import Path, emit, csv_open, DictWriter
from run_gate import run_gate

SYN = Path(__file__).resolve().parent
ROOT = SYN.parent
FIELDS = ['clock_period_ns','clock_cycles_per_block','block_size_bits',
          'total_cell_area','static_power_mw','dynamic_power_mw','total_power_mw',
          'throughput_gbps','energy_per_bit_pj','worst_slack_ns','status',
          'e2e_cycles_4096B','full_sha3_throughput_gbps',
          'full_sha3_estimated_p_over_t_pj_per_bit','gate_03_status',
          'gate_03_pass','gate_03_timing_violation','gate_03_sdf_warnings',
          'gate_03_first_failure']
VERSIONS = ('V0_C3_NoFT','V1_State1600_SECDED_Replay',
            'V2_Lane64_SECDED_Replay','V3_LaneParity_LocalReplay')
VERSION = 'V3_LaneParity_LocalReplay' if ROOT.name in ('SHA3', 'sysVerilog') else ROOT.name

def read(p):
    return p.read_text(encoding='utf-8',errors='replace')

def fingerprint():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
            for d in ('00_TESTBED','01_RTL') for p in (ROOT/d).iterdir()
            if p.is_file() and (p.suffix in ('.sv','.f','.py','.sh') or p.name=='Makefile')}

def preflight():
    p = ROOT/'rtl_latest.json'
    if not p.is_file(): raise ValueError('Run complete 01 RTL suite first')
    r = json.loads(read(p))
    if r.get('version')!=VERSION or r.get('status')!='PASS' or r.get('source_sha256')!=fingerprint():
        raise ValueError('RTL source differs from PASS record; rerun complete RTL suite')
    if int(r['message']['e2e_cycles'])<=0: raise ValueError('Missing 4096-byte cycle count')
    emit('[READY] Original DC flow; full SHA3; in-place 03 GATE')

def header(p):
    with csv_open(Path(p)) as f:
        w=DictWriter(f,fieldnames=FIELDS);w.writeheader()

def point(args):
    work,status,period,design,row_path,csv_path=args
    work=Path(work).resolve(); period=float(period)
    if VERSION not in VERSIONS or work!=(ROOT/'results'/'sweep'/'_work').resolve():
        raise ValueError('Unexpected temporary work directory')
    with open(str(row_path),'r') as f: row=next(csv.DictReader(f))
    rtl=json.loads(read(ROOT/'rtl_latest.json'))
    cycles=int(rtl['message']['e2e_cycles'])
    rate=32768.0/(cycles*period)
    row['e2e_cycles_4096B']=cycles
    row['full_sha3_throughput_gbps']='%.9g'%rate
    try: row['full_sha3_estimated_p_over_t_pj_per_bit']='%.9g'%(float(row['total_power_mw'])/rate)
    except ValueError: row['full_sha3_estimated_p_over_t_pj_per_bit']='N/A'
    row.update(gate_03_status='NOT_RUN',gate_03_pass='NO',gate_03_timing_violation='N/A',
               gate_03_sdf_warnings='N/A',gate_03_first_failure='')
    try:
        if status in ('OK','TIMING_FAILED'):
            marker=(work/'.synthesis_started').stat().st_mtime
            for ext in ('v','sdf'):
                p=SYN/'Netlist'/(design+'_SYN.'+ext)
                if not p.is_file() or p.stat().st_mtime<=marker:
                    raise ValueError('Missing or stale gate netlist/SDF')
            g=run_gate(work,'full',period,VERSION,'TSMC40',design)
            row['gate_03_status']=g['gate_status']
            row['gate_03_pass']='YES' if g['gate_status'] in ('PASS','PASS_WITH_SDF_WARNING') else 'NO'
            row['gate_03_timing_violation']='YES' if g['gate_timing_violation'] else 'NO'
            row['gate_03_sdf_warnings']=g.get('gate_sdf_warning_count','N/A')
            row['gate_03_first_failure']=g.get('gate_first_failure') or ''
    except Exception as e:
        row['gate_03_status']='ERROR';row['gate_03_first_failure']=str(e)[:200]
        emit('[GATE_ERROR] '+str(e))
    finally:
        p=work/'03_GATE'
        if p.exists():
            if os.path.islink(str(p)): raise ValueError('Refusing linked GATE directory')
            shutil.rmtree(str(p))
    with open(str(csv_path),'a') as f:
        w=csv.DictWriter(f,fieldnames=FIELDS,extrasaction='ignore');w.writerow(row)
    emit('[POINT] 02={} 03={} full_SHA3_P_over_T={}'.format(
         status,row['gate_03_status'],row['full_sha3_estimated_p_over_t_pj_per_bit']))

def summary(p):
    with open(str(p),'r') as f: rows=list(csv.DictReader(f))
    bad=[r for r in rows if r['status']!='OK' or r['gate_03_pass']!='YES']
    emit('[SUMMARY] version={} points={} failures={} csv={}'.format(VERSION,len(rows),len(bad),p))
    emit('[COMPLETED_CLEAN]' if not bad else '[COMPLETED_WITH_POINT_FAILURES]')
    # A completed sweep can include intentionally overclocked failing points.
    # The 10 ns check script separately requires an all-pass point.
    return 0

def cleanup():
    if SYN.resolve()!=(ROOT/'02_SYN').resolve() or VERSION not in VERSIONS:
        raise ValueError('Refusing cleanup outside a named version 02_SYN')
    for name in ('Report','Netlist'):
        p=SYN/name
        if p.exists():
            if os.path.islink(str(p)): raise ValueError('Refusing linked '+name)
            shutil.rmtree(str(p))
    for pattern in ('*_SYN.ddc','*.svf','dwsvf*','syn.log','command.log'):
        for p in SYN.glob(pattern):
            if p.is_file() and not os.path.islink(str(p)): os.unlink(str(p))
    emit('[COMPACT_CLEANUP] Temporary DC products removed')

if __name__=='__main__':
    try:
        mode=sys.argv[1]
        if mode=='preflight':preflight()
        elif mode=='header':header(sys.argv[2])
        elif mode=='point':point(sys.argv[2:])
        elif mode=='summary':sys.exit(summary(sys.argv[2]))
        elif mode=='cleanup':cleanup()
        else:raise ValueError('Unknown mode')
    except Exception as e:emit('[FAIL] '+str(e));sys.exit(1)
