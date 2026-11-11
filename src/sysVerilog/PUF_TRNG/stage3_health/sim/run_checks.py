import argparse,hashlib,json,os,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def run(cmd,cwd,log,env):
    with log.open("w",encoding="utf-8") as out:
        p=subprocess.run([str(v) for v in cmd],cwd=str(cwd),env=env,stdout=out,stderr=subprocess.STDOUT)
    if p.returncode:
        print(log.read_text(encoding="utf-8",errors="replace")[-6000:]);raise SystemExit("Command failed: "+str(log))
def main():
    ap=argparse.ArgumentParser();ap.add_argument("suite",choices=["unit","system"]);ap.add_argument("--vivado-bin",default="D:/VIVADO/2025.2/Vivado/bin");a=ap.parse_args()
    env=os.environ.copy();env["PATH"]=a.vivado_bin+os.pathsep+env["PATH"]
    result=ROOT/"build"/(a.suite+"_pass.json");result.unlink(missing_ok=True)
    if a.suite=="unit":
        folder=ROOT/"build/unit";folder.mkdir(parents=True,exist_ok=True)
        sources=[ROOT/"rtl"/v for v in ["ro_cell.sv","ro_bank.sv","entropy_axi.sv","entropy_health_monitor.sv"]]+[ROOT/"sim/tb_entropy_unit.sv"]
        commands=[("compile",["xvlog.bat","--sv",*sources]),("elaborate",["xelab.bat","tb_entropy_unit","-s","entropy_unit","--timescale","1ns/1ps"]),("simulate",["xsim.bat","entropy_unit","-runall"])]
        marker="SUCCESS HEALTH UNIT"
    else:
        folder=Path((ROOT/"build/system_sim_path.txt").read_text().strip())
        commands=[(n,[folder/(n+".bat")]) for n in ["compile","elaborate","simulate"]]
        marker="SUCCESS HEALTH SYSTEM reset GP0 startup RCT APT RAM-read fault abort recovery"
    for name,cmd in commands:
        if not Path(cmd[0]).is_absolute():cmd[0]=Path(a.vivado_bin)/cmd[0]
        run(cmd,folder,folder/(name+"_check.log"),env)
    text=(folder/"simulate_check.log").read_text(encoding="utf-8",errors="replace")
    if marker not in text or re.search(r"Fatal:|FATAL|^ERROR:",text,re.M):
        print(text[-6000:]);raise SystemExit("Simulation failed")
    inputs=list((ROOT/"rtl").glob("*.sv"))+[ROOT/"sim"/("tb_entropy_"+a.suite+".sv")]
    summary={"status":"PASS","suite":a.suite,"marker":marker,"source_sha256":{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},"physical_entropy_validated":False}
    if a.suite=="system":
        project=folder.parents[3]
        hwh=project/(project.name+".gen")/"sources_1/bd/design_1/hw_handoff/design_1.hwh"
        # Vivado project directory name may differ from project NAME; discover one HWH.
        matches=list(project.glob("*.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh"))
        if len(matches)!=1:raise SystemExit("Expected one generated design_1 HWH")
        summary["hwh_sha256"]=hashlib.sha256(matches[0].read_bytes()).hexdigest()
    result.write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print(text[-3500:]);print("Recorded",result)
if __name__=="__main__":main()
