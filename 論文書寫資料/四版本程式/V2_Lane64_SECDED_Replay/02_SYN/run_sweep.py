"""One invocation synthesizes FULL SHA3 and standalone CORE at every requested period.
Requires a successful complete run_all_rtl.py with identical source files.
Example: python run_sweep.py --periods 10 8 6 4 2 1 --process TSMC40
"""
from __future__ import print_function, division
import argparse
import csv
from datetime import datetime
import hashlib
import json
import math
import os
from paper_compat import Path, emit, run_process, which, isfinite, csv_open, DictWriter
import re
import shutil
import subprocess

SYN=Path(__file__).resolve().parent
ROOT=SYN.parent
NUMBER=r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?'
FIELDS=['version','scope','period_ns','status','area_library_units','dynamic_power_mw',
        'leakage_power_mw','total_power_mw','worst_slack_ns','e2e_cycles_4096B',
        'standalone_core_cycles','full_throughput_gbps','core_rate_throughput_gbps',
        'estimated_energy_per_bit_pj','full_power_core_normalized_pj',
        'power_method','raw_directory','error','constraint_summary']


def read(path): return path.read_text(encoding='utf-8',errors='replace')


def number(pattern,text,label):
    match=re.search(pattern,text,re.I|re.M)
    if not match: raise ValueError('Missing '+label)
    value=float(match.group(1))
    if not isfinite(value):raise ValueError('Nonfinite '+label)
    return value


def power(text,label):
    match=re.search(re.escape(label)+r'\s*=\s*('+NUMBER+r')\s*([munp]?W)\b',text,re.I)
    if not match:raise ValueError('Missing power value/unit: '+label)
    scales={'w':1000,'mw':1,'uw':.001,'nw':.000001,'pw':.000000001}
    return float(match.group(1))*scales[match.group(2).lower()]


def require_ns_time_unit(text):
    # DC R-2020.09: Time_unit : 1.0e-09 Second(ns)
    # Also accept equivalent spellings such as Time Units : 1ns.
    match=re.search(r'^\s*Time[ _]+Units?\s*[:=]\s*('+NUMBER+
                    r')\s*(seconds?|ns|ps|us|ms|s)\b',text,re.I|re.M)
    if not match:
        raise ValueError('Missing/unrecognized time unit; inspect units.rpt')
    scale={'second':1e9,'seconds':1e9,'s':1e9,'ms':1e6,'us':1e3,'ns':1.0,'ps':1e-3}
    ns=float(match.group(1))*scale[match.group(2).lower()]
    if not isfinite(ns) or abs(ns-1.0)>1e-12:
        raise ValueError('Expected 1 ns time unit, got {} ns; inspect units.rpt'.format(ns))
    return ns


def constraint_summary(text):
    section=None; totals=[]
    names=('max_transition','max_capacitance','max_fanout','min_delay/hold','max_delay/setup')
    for line in text.splitlines():
        label=line.strip()
        if label in names: section=label
        match=re.match(r'^\s*Total\s+(\d+)\s+',line)
        if section and match:
            totals.append('{}={}'.format(section,match.group(1)));section=None
    if totals:return '; '.join(totals)
    return 'violations present; inspect constraints.rpt' if 'VIOLATED' in text else 'none reported'


def check_protection_reports(report, version):
    expected={'V0_C3_NoFT':0,'V1_State1600_SECDED_Replay':5,
              'V2_Lane64_SECDED_Replay':29,'V3_LaneParity_LocalReplay':2}[version]
    table=csv.DictReader(read(report/'protection_instances.csv').splitlines())
    if not set(('instance','reference','area_report')).issubset(set(table.fieldnames or [])):
        raise ValueError('Protection report format missing; update paper_syn.tcl together with run_sweep.py')
    rows=list(table)
    if len(rows)!=expected or len(set(row['instance'] for row in rows))!=expected:
        raise ValueError('Protection instance count mismatch in report')
    for row in rows:
        name=row['area_report']
        if not re.match(r'^protection_\d+_area\.rpt$',name):raise ValueError('Invalid protection area report name')
        area=number(r'Total cell area\s*:\s*('+NUMBER+')',read(report/name),'protection reference area')
        if area<=0:raise ValueError('Protection reference has no positive mapped area: '+row['instance'])


def parse_reports(directory,period,scope,rtl):
    report=directory/'02_SYN/Report'
    for name in ('COMPLETE','area.rpt','power.rpt','timing.rpt','constraints.rpt',
                 'check_design.rpt','check_timing.rpt','qor.rpt','protection_instances.csv',
                 'clocks.rpt','ports.rpt','references.rpt','activity.rpt','units.rpt','run_metadata.txt'):
        if not (report/name).is_file() or not (report/name).stat().st_size:
            raise ValueError('Missing report: '+name)
    for ext in ('v','ddc','sdc','sdf'):
        if not list((directory/'02_SYN/Netlist').glob('*.'+ext)):raise ValueError('Missing netlist '+ext)
    log=read(directory/'02_SYN/dc.log')
    if re.search(r'^\s*(?:Error:|Fatal:)',log,re.M):raise ValueError('DC reported an error; inspect dc.log')
    # check_timing warns explicitly about unconstrained endpoints / clocks.
    checks=read(report/'check_timing.rpt')
    if re.search(r'Warning:.*(?:no clock|not constrained|unconstrained)',checks,re.I):
        raise ValueError('Unconstrained timing detected; inspect check_timing.rpt')
    check_protection_reports(report,rtl.get('version',ROOT.name))
    units=read(report/'units.rpt')
    require_ns_time_unit(units)
    area=number(r'Total cell area\s*:\s*('+NUMBER+')',read(report/'area.rpt'),'cell area')
    pwr=read(report/'power.rpt')
    dynamic=power(pwr,'Total Dynamic Power'); leakage=power(pwr,'Cell Leakage Power')
    if min(area,dynamic,leakage)<0 or area==0:raise ValueError('Invalid area/power')
    slack=number(r'^worst_slack_ns=('+NUMBER+')',read(report/'run_metadata.txt'),'slack')
    full_cycles=int(rtl['message']['e2e_cycles']); core_cycles=int(rtl['standalone_core_cycles'])
    if full_cycles<=0 or core_cycles<=0:raise ValueError('Invalid latency')
    full_tp=32768/(full_cycles*period)
    core_tp=1088/(core_cycles*period)
    total=dynamic+leakage
    # mW / Gbit/s = pJ/bit. This is a vectorless power-normalized estimate.
    constraints=read(report/'constraints.rpt')
    constraint_fail=slack>=0 and 'VIOLATED' in constraints
    valid=slack>=0 and not constraint_fail
    return dict(constraint_summary=constraint_summary(constraints),area_library_units=area,dynamic_power_mw=dynamic,leakage_power_mw=leakage,
                total_power_mw=total,worst_slack_ns=slack,
                e2e_cycles_4096B=full_cycles,standalone_core_cycles=core_cycles,
                full_throughput_gbps=full_tp if valid and scope=='full' else '',
                core_rate_throughput_gbps=core_tp if valid else '',
                estimated_energy_per_bit_pj=total/(full_tp if scope=='full' else core_tp) if valid else '',
                full_power_core_normalized_pj=total/core_tp if valid and scope=='full' else '',
                status='VALID' if valid else ('CONSTRAINT_FAIL' if constraint_fail else 'TIMING_FAIL'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--periods',type=float,nargs='+',default=[10,8,6,4,2,1])
    parser.add_argument('--process',default='TSMC40',choices=['TSMC40','TSMC28','TSMC16','UMC018'])
    parser.add_argument('--dc',default='dcnxt_shell')
    parser.add_argument('--setup',type=Path,help='Use an existing .synopsys_dc.setup instead of Makefile setup_dc')
    args=parser.parse_args()
    if any(not isfinite(p) or p<=0 for p in args.periods):parser.error('Periods must be finite and >0')
    if len(set(args.periods))!=len(args.periods):parser.error('Duplicate periods')
    summary=ROOT/'rtl_latest.json'
    if not summary.exists():raise SystemExit('[FAIL] Run the complete 00_TESTBED/run_all_rtl.sh first')
    rtl=json.loads(read(summary))
    if rtl.get('status')!='PASS' or rtl.get('version')!=ROOT.name:raise SystemExit('[FAIL] Invalid RTL summary')
    for name,expected in rtl['source_sha256'].items():
        p=ROOT/name
        if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected:
            raise SystemExit('[FAIL] Source changed since RTL tests: '+name)
    actual={str(p.relative_to(ROOT)) for d in ('00_TESTBED','01_RTL') for p in (ROOT/d).iterdir()
            if p.is_file() and (p.suffix in ('.sv','.f','.py','.sh') or p.name=='Makefile')}
    if actual!=set(rtl['source_sha256']):raise SystemExit('[FAIL] Source file list changed since RTL tests')
    out=ROOT/'results'/'sweep'/datetime.now().strftime('%Y%m%d_%H%M%S')
    out.mkdir(parents=True,exist_ok=False)
    if args.setup:
        setup=args.setup.resolve()
    else:
        setup=SYN/'.synopsys_dc.setup'
        with (out/'setup.log').open('w') as f:
            run_process(['make','-f','../00_TESTBED/Makefile','setup_dc','PROCESS='+args.process],
                           cwd=SYN,stdout=f,stderr=subprocess.STDOUT,check=True)
    if not setup.is_file():raise SystemExit('[FAIL] Synthesis setup missing: '+str(setup))
    shutil.copy2(setup,out/'synopsys_dc.setup')
    shutil.copy2(summary,out/'rtl_summary.json')
    (out/'request.json').write_text(json.dumps(dict(version=ROOT.name,periods_ns=args.periods,
            process=args.process,dc=args.dc,constraint_policy='paper_v2_slew0p1_coreload0p1T',power_method='vectorless, 0.1 toggles/cycle, static probability 0.5',
            timestamp=datetime.now().isoformat()),indent=2),encoding='utf-8')
    rows=[]; errors=0
    for period in args.periods:
        if errors: break
        for scope in ('full','core'):
            point=out/'{}_{:g}ns'.format(scope, period); point.mkdir()
            for folder in ('00_TESTBED','01_RTL','02_SYN'):
                dst=point/folder; dst.mkdir()
                for p in (ROOT/folder).iterdir():
                    if p.is_file():shutil.copy2(p,dst/p.name)
            shutil.copy2(setup,point/'02_SYN/.synopsys_dc.setup')
            env=os.environ.copy();env.update(CLK_PERIOD=str(period),PAPER_SCOPE=scope,PAPER_VERSION=ROOT.name)
            row=dict(version=ROOT.name,scope=scope,period_ns=period,status='ERROR',
                     power_method='vectorless',raw_directory=str(point.relative_to(out)),error='')
            emit('[RUN {}/{}] {} {} {:g} ns'.format(len(rows)+1,len(args.periods)*2,ROOT.name,scope,period),flush=True)
            try:
                with (point/'02_SYN/dc.log').open('w') as f:
                    run_process([args.dc,'-f','paper_syn.tcl'],cwd=point/'02_SYN',env=env,
                                   stdout=f,stderr=subprocess.STDOUT,check=True)
                row.update(parse_reports(point,period,scope,rtl))
                emit("[{}] {} {:g} ns | slack={:.6g} ns | constraints: {}".format(
                    row['status'],scope,period,row['worst_slack_ns'],row['constraint_summary']),flush=True)
                if row['status']!='VALID':
                    emit('[NOT_VALID] DC completed, but this point does not satisfy all constraints. Reports: '+str(point/'02_SYN/Report'))
            except Exception as exc:
                row['error']=str(exc);errors+=1;emit('[TOOL_ERROR] '+str(exc),flush=True)
                logpath=point/'02_SYN/dc.log'
                if logpath.is_file():
                    errors_in_log=[line for line in read(logpath).splitlines() if re.match(r'^\s*(Error:|Fatal:)',line)]
                    for line in errors_in_log[:3]:emit('  '+line.strip())
                emit('[LOG] '+str(logpath))
            rows.append(row)
            with csv_open(out/'sweep.csv') as f:
                w=DictWriter(f,fieldnames=FIELDS);w.writeheader();w.writerows(rows)
            if errors: break
    valid={s:sum(r['status']=='VALID' and r['scope']==s for r in rows) for s in ('full','core')}
    result=dict(status='PASS' if not errors and all(valid.values()) else 'FAIL',valid_points=valid,
                tool_or_report_errors=errors,completed_points=len(rows),expected_points=len(args.periods)*2,
                status_counts={name:sum(r['status']==name for r in rows) for name in ('VALID','TIMING_FAIL','CONSTRAINT_FAIL','ERROR')},
                results=str(out),note='TIMING_FAIL rows are not performance results.')
    (out/'sweep_summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    emit('[SUMMARY] completed={}/{} valid_full={} valid_core={} timing_fail={} constraint_fail={} tool_errors={}'.format(
        len(rows),len(args.periods)*2,valid['full'],valid['core'],result['status_counts']['TIMING_FAIL'],
        result['status_counts']['CONSTRAINT_FAIL'],errors))
    if errors:emit('[STOPPED] Tool/report error: sweep is incomplete. '+str(out))
    elif not all(valid.values()):emit('[COMPLETED_NO_VALID_DATA] All points executed, but at least one scope has no VALID point. '+str(out))
    else:emit('[SUCCESS] Sweep completed; usable full/core data saved. '+str(out))
    raise SystemExit(0 if result['status']=='PASS' else 1)


if __name__=='__main__':main()
