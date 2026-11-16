"""Rebuild/check/package on Windows. No board or network access.

Uses installed Vivado and the retained stage1 PYNQ2.5 compatibility sources.
Existing stage4 project must still match packaged frozen RTL; final gate checks it.
"""
import argparse, os, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]


def main():
    ap=argparse.ArgumentParser();ap.add_argument("--vivado-bin",default="D:/VIVADO/2025.2/Vivado/bin")
    a=ap.parse_args();build=ROOT/"build";build.mkdir(exist_ok=True)
    env=os.environ.copy();env["PATH"]=a.vivado_bin+os.pathsep+env["PATH"]
    def run(cmd,name):
        print("Running",name,flush=True)
        with (build/(name+"_console.log")).open("w",encoding="utf-8") as log:
            p=subprocess.run([str(x) for x in cmd],cwd=str(ROOT),env=env,stdout=log,stderr=subprocess.STDOUT)
        if p.returncode:raise SystemExit("Stopped: "+name+"; inspect build/"+name+"_console.log")
    def vivado(script):
        run([Path(a.vivado_bin)/"vivado.bat","-mode","batch","-source",ROOT/"vivado"/(script+".tcl"),"-log",build/(script+".log"),"-journal",build/(script+".jou")],script)
    if not (build/"trng_integrated/trng_integrated.xpr").exists():vivado("create_project")
    for suite in ("normal","ft","axis"):
        run([sys.executable,ROOT/"sim/run_sim.py","--suite",suite,"--vivado-bin",a.vivado_bin],suite)
    run([sys.executable,ROOT/"sim/run_health.py","unit","--vivado-bin",a.vivado_bin],"unit")
    run([sys.executable,ROOT/"sim/make_vectors.py"],"vectors")
    vivado("prepare_sim")
    run([sys.executable,ROOT/"sim/run_system.py","--vivado-bin",a.vivado_bin],"system")
    run([sys.executable,ROOT/"sim/check_host.py"],"host")
    vivado("build")
    run([sys.executable,ROOT/"sim/make_release.py"],"release")
    print("SUCCESS: delivery/trng_integrated_ready.zip",flush=True)
if __name__=="__main__":main()
