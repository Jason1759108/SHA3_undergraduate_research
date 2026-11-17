"""Standalone PUF256 regression. No external project sources required."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parent.parent
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--verilator',default=shutil.which('verilator'))
    p.add_argument('--zig')
    p.add_argument('--mode',choices=['axi-ro','core-count','ecc-secded','wave','core','ecc'],default='axi-ro')
    p.add_argument('--vcd',action='store_true')
    p.add_argument('--full-clock-trace',action='store_true',help='Include duplicated 640-bit raw clock buses; produces very large VCD files')
    p.add_argument('--translate-only',action='store_true',help='Generate simulator sources without compiling/running')
    p.add_argument('--build-dir',type=Path,default=ROOT/'build/sim')
    a=p.parse_args()
    a.mode={'wave':'axi-ro','core':'core-count','ecc':'ecc-secded'}.get(a.mode,a.mode)
    top={'axi-ro':'TESTBED_PUF_AXI_RO','core-count':'TESTBED_PUF_CORE_COUNT','ecc-secded':'TESTBED_PUF_ECC_SECDED'}[a.mode]
    manifest={'axi-ro':'filelist_puf_axi_ro.f','core-count':'filelist_puf_core_count.f','ecc-secded':'filelist_puf_ecc_secded.f'}[a.mode]
    if not a.verilator:p.error('Install Verilator or provide --verilator PATH')
    tool=Path(a.verilator).resolve(); build=(a.build_dir/a.mode).resolve(); build.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy()
    if tool.name=='verilator_bin.exe':env['VERILATOR_ROOT']=os.path.relpath(tool.parent.parent,ROOT)
    def run(cmd,name,cwd=ROOT):
        r=subprocess.run(cmd,cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=1800)
        (build/name).write_text(r.stdout,encoding='utf-8')
        if r.returncode:raise SystemExit(r.stdout[-10000:])
        return r.stdout
    sources=[(ROOT/'sim'/line).resolve().as_posix() for line in (ROOT/'sim'/manifest).read_text().splitlines() if line.strip()]
    for ext in ('cpp','h'):
        for file in build.glob('VTEST*.'+ext):file.unlink()
    args=[str(tool),'--timing','--assert','--trace','--trace-depth','4','-Wno-TIMESCALEMOD',
          '--top-module',top,'--prefix','VTEST','--Mdir',str(build)]
    args+=['--cc','--main'] if a.zig else ['--binary','-j','2']
    if a.mode=='axi-ro' and not a.full_clock_trace:
        # Verilator's Windows filename normalization can mix slash styles;
        # basename wildcards match the actual source filenames on both hosts.
        lines=['`verilator_config', 'tracing_off -file "*ro_edge_counter.sv"']
        for file in [ROOT/'sim/TESTBED_PUF_AXI_RO.sv',ROOT/'sim/ro_wave_model.sv',
                     ROOT/'rtl/puf_axi.sv',ROOT/'rtl/ro_measure.sv']:
            for number,line in enumerate(file.read_text(encoding='utf-8').splitlines(),1):
                wide_clock_decl=('wire [639:0] ro_clocks' in line or
                                 'input wire [2*PAIRS-1:0] ro_clocks' in line or
                                 'output logic [2*PAIRS-1:0] ro' in line)
                counter_array=any(name in line for name in ('source_gray [','gray_meta [','gray_sync ['))
                if wide_clock_decl or counter_array:
                    lines.append('tracing_off -file "*{}" -lines {}'.format(file.name,number))
        control=build/'trace_control.vlt'
        control.write_text('\n'.join(lines)+'\n',encoding='utf-8')
        sources.insert(0,str(control))
    print('Translating RTL',flush=True);run(args+sources,'verilator.log')
    if a.translate_only:return
    if a.zig:
        runtime=tool.parent.parent/'include'
        env.update(ZIG_GLOBAL_CACHE_DIR=str(build/'zig-global'),ZIG_LOCAL_CACHE_DIR=str(build/'zig-local'),TEMP=str(build),TMP=str(build))
        exe=build/('sim.exe' if os.name=='nt' else 'sim')
        cmd=[str(Path(a.zig).resolve()),'c++','-std=c++20','-O1','-DVL_TIME_CONTEXT',
             '-DVM_TRACE=1','-DVM_TRACE_VCD=1','-Wno-nullability-completeness',
             '-I'+str(runtime),'-I'+str(build)]
        if os.name=='nt':cmd+=['-target','x86_64-windows-gnu']
        cmd += [str(file) for file in sorted(build.glob('*.cpp'))]
        cmd += [str(runtime/name) for name in ('verilated.cpp','verilated_threads.cpp','verilated_timing.cpp','verilated_vcd_c.cpp')]
        print('Compiling simulator',flush=True);run(cmd+['-o',str(exe)],'build.log')
    else:exe=build/('VTEST.exe' if os.name=='nt' else 'VTEST')
    result=run([str(exe)]+(['+vcd'] if a.vcd else []),'simulation.log',build)
    if '[SUCCESS]' not in result:raise SystemExit(result)
    if a.mode=='axi-ro' and a.vcd and not a.full_clock_trace:
        from compact_vcd import compact
        full=build/'puf_axi_ro.vcd'; focused=build/'puf_axi_ro_focused.vcd'
        count=compact(full,focused)
        focused.replace(full)
        print('Focused VCD: {} signal identifiers, {} bytes'.format(count,full.stat().st_size))
    print(result)
if __name__=='__main__':main()
