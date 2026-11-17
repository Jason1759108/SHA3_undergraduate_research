"""Standalone A-side PUF regression with independently computed response/sketch vectors.

python run_sim.py --mode all --vcd
Windows: add --verilator PATH/verilator_bin.exe --zig PATH/zig.exe
"""
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parent.parent
TB=ROOT/'00_TESTBED'

def mix(x):
    x=((x^(x>>16))*0x7feb352d)&0xffffffff
    x=((x^(x>>15))*0x846ca68b)&0xffffffff
    return x^(x>>16)

def sv(name,data,width=None):
    if isinstance(data,bytes):
        width=width or len(data)*8
        data=int.from_bytes(data,'little')
    return f"localparam logic [{width-1}:0] {name} = {width}'h{data:0{(width+3)//4}x};\n"

def generate_vectors(dest):
    good=[i for i in range(320) if i%19!=0]
    constants={}
    def fixture(pairs,prefix):
        raw=sum((mix(0x13579bdf^((i*0x9e3779b9)&0xffffffff))&1)<<j for j,i in enumerate(pairs))
        bitmap=sum(1<<i for i in pairs)
        helper=0
        for w in range(16):
            word=(raw>>(w*16))&0xffff
            syndrome=0
            for k in range(16):
                if (word>>k)&1:syndrome^=16 | (k+1 if k<15 else 0)
            helper|=syndrome<<(w*5)
        constants[prefix+'_MAP']=(bitmap,320)
        constants[prefix+'_HELPER']=(helper,80)
        constants[prefix+'_RAW']=(raw,256)
        return {'raw_hex':f'{raw:064x}','helper_hex':f'{helper:020x}','selected_pairs':pairs}
    records={'default':fixture(good[:256],'GOLD'),'alternate':fixture(good[-256:],'ALT')}
    text=''.join(sv(name,value,width) for name,(value,width) in constants.items())
    (dest/'vectors.svh').write_text(text,encoding='utf-8')
    (dest/'reference.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    pattern=(TB/'PATTERN_PUF.sv').read_text()
    for name,(value,width) in constants.items():
        match=re.search(rf"\b{name}\s*=\s*(\d+)'h([0-9a-fA-F_]+)\s*;",pattern)
        if not match or int(match[1])!=width or int(match[2].replace('_',''),16)!=value:
            raise SystemExit(f'PATTERN {name} differs from independent Python reference')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode',choices=('all','ecc','ro','count','wave','puf'),default='all')
    parser.add_argument('--verilator',default=shutil.which('verilator'))
    parser.add_argument('--zig')
    parser.add_argument('--build-dir',type=Path,default=ROOT/'.build')
    parser.add_argument('--vcd',action='store_true')
    parser.add_argument('--vectors-only',action='store_true')
    args=parser.parse_args()
    modes=('ecc','ro','count','wave') if args.mode=='all' else (('wave',) if args.mode=='puf' else (args.mode,))
    base=args.build_dir.resolve();base.mkdir(parents=True,exist_ok=True)
    if args.vectors_only:
        generate_vectors(base);print(f'Vectors: {base}');return
    if not args.verilator:parser.error('Install Verilator or pass --verilator')
    tool=Path(args.verilator).resolve()
    env=os.environ.copy()
    if tool.name=='verilator_bin.exe':env['VERILATOR_ROOT']=os.path.relpath(tool.parent.parent,ROOT)
    for mode in modes:
        build=base/mode;build.mkdir(parents=True,exist_ok=True);generate_vectors(build)
        # Hierarchy changes can leave obsolete generated C++ files behind.
        # Remove only this runner's generated prefix, retaining logs/caches/vectors.
        for extension in ('cpp','h'):
            for generated in build.glob('VTEST*.'+extension):
                generated.unlink()
        manifest={'ecc':'filelist_ecc.f','ro':'filelist_ro.f','count':'filelist_count.f','wave':'filelist.f'}[mode]
        sources=[str((TB/line.strip()).resolve()) for line in (TB/manifest).read_text().splitlines() if line.strip()]
        def run(command,log,timeout=900,cwd=ROOT):
            result=subprocess.run(command,cwd=cwd,env=env,stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT,text=True,timeout=timeout)
            (build/log).write_text(result.stdout,encoding='utf-8')
            if result.returncode:
                print(result.stdout[-7000:]);raise SystemExit(f'Failed: {build/log}')
            return result.stdout
        command=[str(tool),'--timing','--assert','--trace','--trace-depth',('2' if mode=='wave' else '3'),
                 '-Wno-TIMESCALEMOD','--prefix','VTEST',
                 '--Mdir',str(build)]
        if not args.vcd:command+=['-DNO_DUMP']
        command+=['--cc','--main'] if args.zig else ['--binary','-j','2']
        print(f'[{mode}] translating RTL',flush=True)
        run(command+sources,'verilator.log')
        if args.zig:
            runtime=tool.parent.parent/'include'
            env.update(ZIG_GLOBAL_CACHE_DIR=str(base/'zig-global-cache'),
                       ZIG_LOCAL_CACHE_DIR=str(base/'zig-local-cache'),TEMP=str(base),TMP=str(base))
            output=build/('sim.exe' if os.name=='nt' else 'sim')
            command=[str(Path(args.zig).resolve()),'c++','-std=c++20','-O1',
                '-DVL_TIME_CONTEXT','-DVM_TRACE=1','-DVM_TRACE_VCD=1',
                '-Wno-nullability-completeness','-I'+str(runtime),'-I'+str(build)]
            if os.name=='nt':command+=['-target','x86_64-windows-gnu']
            command += [str(p) for p in sorted(build.glob('*.cpp'))]
            command += [str(runtime/n) for n in ('verilated.cpp','verilated_threads.cpp','verilated_timing.cpp','verilated_vcd_c.cpp')]
            print(f'[{mode}] building simulator',flush=True)
            run(command+['-o',str(output)],'build.log')
        else:output=build/('VTEST.exe' if os.name=='nt' else 'VTEST')
        text=run([str(output)]+(['+vcd'] if args.vcd else []),'simulation.log',timeout=240,cwd=build)
        if '[SUCCESS]' not in text:raise SystemExit(text)
        if args.vcd and mode in ('ro','wave','count'):
            wave=build/{'ro':'ro_sim.vcd','wave':'puf_sim.vcd','count':'puf_count_sim.vcd'}[mode]
            if not wave.exists() or wave.stat().st_size==0:raise SystemExit('Missing waveform')
        print(text,flush=True)
    print('[SUCCESS] all requested modes passed',flush=True)

if __name__=='__main__':main()
