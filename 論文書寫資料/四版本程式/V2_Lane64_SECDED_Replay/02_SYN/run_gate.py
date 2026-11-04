"""Post-synthesis normal-operation VCS simulation; Python 2.7 compatible.
Uses the point netlist with the original make vcs_gate target, with SDF annotation.
"""
from __future__ import print_function, division
import json
import os
import re
import subprocess
import shutil
from paper_compat import Path, run_process, emit

SYN=Path(__file__).resolve().parent
ROOT=SYN.parent


def read(p):
    return p.read_text(encoding='utf-8', errors='replace')


def prepare(point, scope, period, version, design):
    gate=point/'03_GATE'; gate.mkdir(exist_ok=True)
    # The current 02_SYN outputs are used directly. Each sweep point only
    # retains tiny summaries; netlist and SDF are never archived per period.
    net=SYN/'Netlist'/(design+'_SYN.v')
    sdf=SYN/'Netlist'/(design+'_SYN.sdf')
    if not net.is_file() or not sdf.is_file():raise ValueError('Missing gate netlist/SDF')
    match=re.search(r'\(DESIGN\s+"([^"]+)"\)',read(sdf))
    if not match:raise ValueError('Cannot identify SDF top design')
    top=match.group(1)
    if not re.match(r'^\w+$',top):raise ValueError('Unsupported top module name: '+top)
    declaration=re.search(r'\bmodule\s+'+re.escape(top)+r'\s*\((.*?)\)\s*;',read(net),re.S)
    if not declaration:raise ValueError('SDF top does not match netlist module')
    ft=sorted(set(re.findall(r'\bft_\w+',declaration.group(1))))
    # Use the matching synthesis SDF; retain timing checks.
    annotation='initial $sdf_annotate("'+sdf.resolve().as_posix()+'", dut, , "sdf_annotation.log", "MAXIMUM");'
    if scope=='full':
        signals=['clk','rst_n','in_valid','msg_in','msg_length','in_last','in_ready','out_data','out_valid','hash_done']
        connections=['.%s(%s)'%(n,n) for n in signals]+[".%s('0)"%n for n in ft]
        tb='''`timescale 1ns/1ps
module TESTBED_GATE;
 wire clk,rst_n,in_valid,in_last,in_ready,out_valid,hash_done;
 wire [1087:0] msg_in;
 wire [7:0] msg_length;
 wire [31:0] out_data;
 %s dut (%s);
 PATTERN #(.CLK_PERIOD_NS(%.12g)) u_PATTERN (%s);
 %s
 initial begin #(%.12g); $fatal(1,"[FAIL] gate global watchdog"); end
endmodule
'''%(top,','.join(connections),period,','.join('.%s(%s)'%(n,n) for n in signals),annotation,period*1000000)
        pattern=read(ROOT/'00_TESTBED/PATTERN.sv')
        pattern=re.sub(r'#1\s*;', '#(CLK_PERIOD_NS / 10.0);',pattern)
        (gate/'PATTERN_GATE.sv').write_text(pattern,encoding='utf-8')
        sources=[gate/'PATTERN_GATE.sv']
        success=r'\[SUCCESS\] All (\d+) SHA3-256 test cases passed!'
        expected_cases=18
    else:
        tb=read(ROOT/'00_TESTBED/TESTBED_CORE.sv')
        tb=tb.replace('module TESTBED_CORE;','module TESTBED_GATE;\n localparam real PERIOD = %.12g;'%period)
        tb=re.sub(r'paper_keccak_core\s+(?:#\s*\([^;]*?\)\s*)?dut\s*\([^;]*?\);',top+' dut('+','.join(
            ['.%s(%s)'%(n,n) for n in ['clk','rst_n','start_process','load_state','initial_state','state_out','process_done']]+[".%s('0)"%n for n in ft])+');',tb, count=1,flags=re.S)
        tb=tb.replace('always #5 clk=~clk;','always #(PERIOD/2.0) clk=~clk;')
        tb=re.sub(r'#1\s*;', '#(PERIOD/10.0);',tb)
        tb=tb.replace('#1000000;', '#(PERIOD*100000);')
        tb=tb.replace('endmodule',annotation+'\nendmodule')
        sources=[];success=r'\[SUCCESS\] All (\d+) standalone core reference vectors passed!';expected_cases=4
    (gate/'TESTBED_GATE.sv').write_text(tb,encoding='utf-8')
    sources+=[gate/'TESTBED_GATE.sv',net]
    (gate/'filelist.f').write_text('\n'.join('"'+p.resolve().as_posix()+'"' for p in sources)+'\n',encoding='utf-8')
    return gate,success,expected_cases


def assess(sim, marker, expected):
    found=re.search(marker,sim)
    functional=bool(found and int(found.group(1))==expected) and not re.search(r'\[FAIL\]|\bFatal\b|\bFATAL\b|Error-\[',sim)
    timing=bool(re.search(r'Timing violation',sim,re.I))
    return dict(gate_status='PASS' if functional and not timing else 'FAIL',
                gate_functional_pass=functional,gate_timing_violation=timing,
                gate_mode='serial320_make_vcs_gate_sdf',gate_sdf_annotation='REQUESTED',
                gate_case_count=int(found.group(1)) if found else 0,
                gate_note='Original make vcs_gate flags with SDF MAXIMUM. Normal vectors only; SDF warnings require review.')


def run_gate(point,scope,period,version,process,design,timeout=3600):
    gate,marker,expected=prepare(point,scope,period,version,design)
    # Copy the original Makefile byte-for-byte and invoke its original target.
    shutil.copy2(ROOT/'00_TESTBED/Makefile',gate/'Makefile')
    command=['make','vcs_gate','PROCESS='+process,'SRC_FILE=filelist.f','OUTPUT_NAME=simv','LOG_VCS=vcs.log','define=NO_DUMP']
    emit('[GATE_START] {} {} {:g} ns; log={}'.format(version,scope,period,gate/'gate.log'),flush=True)
    with (gate/'gate.log').open('w') as stream:
        stream.write(u'COMMAND: '+repr(command)+u'\n');stream.flush()
        result=run_process(command,cwd=gate,stdout=stream,stderr=subprocess.STDOUT,timeout=timeout)
    sim=read(gate/'gate.log')
    record=assess(sim,marker,expected)
    fail_line=re.search(r'(?m)^\[FAIL\][^\n]*',sim)
    record['gate_first_failure']=re.sub(r'digest=\S+','digest=REDACTED',fail_line.group(0))[:300] if fail_line else None
    record['gate_timing_violation_count']=len(re.findall(r'Timing violation',sim,re.I))
    annotation_path=gate/'sdf_annotation.log'
    annotation_log=read(annotation_path) if annotation_path.is_file() else ''
    annotation_ok='SDF annotation completed' in annotation_log and bool(re.search(r'Total errors:\s*0\b',annotation_log))
    warning_codes=re.findall(r'Warning-\[([A-Za-z0-9_]+)\]',annotation_log)
    reported_warnings=re.search(r'Total warnings:\s*(\d+)',annotation_log)
    reported_warnings=int(reported_warnings.group(1)) if reported_warnings else None
    warnings_accounted=reported_warnings is not None and len(warning_codes)==reported_warnings
    known_only=warnings_accounted and set(warning_codes).issubset(set(['SDFCOM_CFTC']))
    annotation_warnings=bool(reported_warnings) or bool(warning_codes)
    record['gate_sdf_annotation']='COMPLETED' if annotation_ok else 'INCOMPLETE'
    record['gate_sdf_review_required']=annotation_warnings
    record['gate_sdf_warning_codes']=sorted(set(warning_codes))
    record['gate_sdf_warning_count']=reported_warnings
    record['gate_sdf_warning_count_reconciled']=warnings_accounted
    record['gate_note']='SDF MAXIMUM normal-function test; SDFCOM_CFTC leaves some timing checks unmatched, so this is not full timing signoff.'
    if record['gate_status']=='PASS' and not annotation_ok:record['gate_status']='ERROR'
    elif record['gate_status']=='PASS' and not warnings_accounted:record['gate_status']='REVIEW_SDF'
    elif record['gate_status']=='PASS' and annotation_warnings:
        record['gate_status']='PASS_WITH_SDF_WARNING' if known_only else 'REVIEW_SDF'
    record['gate_exit_code']=result.returncode
    if result.returncode:record['gate_status']='FAIL'
    # Compilation/environment failures are distinct from a completed failing simulation.
    if not (gate/'simv').is_file():record['gate_status']='ERROR'
    record.update(scope=scope,period_ns=period,version=version)
    (gate/'gate_summary.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    emit('[GATE_{}] functional={} timing_violation={} mode={}'.format(record['gate_status'],record['gate_functional_pass'],record['gate_timing_violation'],record['gate_mode']),flush=True)
    return record


if __name__ == '__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--point',required=True,help='Current sweep point summary directory')
    parser.add_argument('--period',required=True,type=float,help='Period of the current in-place synthesis outputs')
    parser.add_argument('--scope',default='full',choices=['full','core'])
    parser.add_argument('--process',default='TSMC40',choices=['TSMC40','TSMC28','TSMC16','UMC018'])
    parser.add_argument('--timeout',type=int,default=3600)
    parser.add_argument('--design',required=True,help='Existing 02_SYN Netlist/Report stem, e.g. SHA3')
    args=parser.parse_args()
    point=Path(args.point).resolve()
    if (point/'03_GATE').exists():
        raise SystemExit('[FAIL] This point already has 03_GATE results; preserve them and use a new sweep point.')
    record=run_gate(point,args.scope,args.period,ROOT.name,args.process,args.design,args.timeout)
    raise SystemExit(0 if record['gate_status'] in ('PASS','PASS_WITH_SDF_WARNING') else 1)
