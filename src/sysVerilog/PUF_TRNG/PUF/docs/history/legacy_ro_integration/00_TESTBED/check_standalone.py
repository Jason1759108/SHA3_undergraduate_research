"""Compile the filelist in a clean copy, without generated files/include paths.

Regression for workstation SFCOR: PATTERN must not need generated vectors.svh.
python check_standalone.py --verilator PATH/TO/verilator_bin.exe
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parent.parent
TB=ROOT/'00_TESTBED'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verilator',default=shutil.which('verilator'))
    parser.add_argument('--work-dir',type=Path,default=ROOT/'.build/standalone_compile')
    parser.add_argument('--mode',choices=('all','wave','count','ro','ecc'),default='all')
    args=parser.parse_args()
    if not args.verilator:parser.error('Pass --verilator or install Verilator')
    tool=Path(args.verilator).resolve()
    build=args.work_dir.resolve();build.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy()
    if tool.name=='verilator_bin.exe':env['VERILATOR_ROOT']=str(tool.parent.parent)
    modes=('wave','count','ro','ecc') if args.mode=='all' else (args.mode,)
    for mode in modes:
        manifest={'wave':'filelist.f','count':'filelist_count.f','ro':'filelist_ro.f','ecc':'filelist_ecc.f'}[mode]
        with tempfile.TemporaryDirectory(prefix='clean_',dir=build) as temp:
            clean=Path(temp)
            (clean/'00_TESTBED').mkdir()
            shutil.copy2(TB/manifest,clean/'00_TESTBED'/manifest)
            for line in (TB/manifest).read_text().splitlines():
                if not line.strip():continue
                source=(TB/line.strip()).resolve()
                target=clean/source.relative_to(ROOT)
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(source,target)
            # No generated headers, include path, explicit top, or MULTITOP waiver.
            result=subprocess.run([str(tool),'--lint-only','--timing','-Wno-TIMESCALEMOD',
                '-f',manifest],cwd=clean/'00_TESTBED',env=env,
                stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
            (build/f'standalone_compile_{mode}.log').write_text(result.stdout,encoding='utf-8')
            if result.returncode:
                print(result.stdout);raise SystemExit(result.returncode)
        print(f'[SUCCESS] {mode}: clean compile, single automatic top, no generated headers')

if __name__=='__main__':main()
