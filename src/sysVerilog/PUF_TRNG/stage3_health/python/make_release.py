"""Require actual simulation, matching HWH/sources and routed primitive audit."""
import hashlib,json,sys
from pathlib import Path
from datetime import datetime,timezone
from entropy_health_pynq import inspect_hwh,validate_artifacts
root=Path(__file__).resolve().parents[1];out=Path(sys.argv[1]);project=Path(sys.argv[2]);pname=sys.argv[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
inspect_hwh(out/"entropy_health.hwh")
checks={}
for suite in ["unit","system","host","monitor","policy","collection"]:
    check=json.loads((root/"build"/(suite+"_pass.json")).read_text(encoding="utf-8"))
    if check["status"]!="PASS":raise RuntimeError("Missing PASS: "+suite)
    for name,digest in check["source_sha256"].items():
        if sha(root/name)!=digest:raise RuntimeError("Rerun stale test: "+name)
    checks[suite]=check
if checks["system"]["hwh_sha256"]!=sha(out/"entropy_health.hwh"):raise RuntimeError("Run full-system simulation for YOUR generated HWH before export")
# Check every generated IP RTL copy, to catch old packaged sources.
for source in (root/"rtl").glob("*.sv"):
    for base in [project/(pname+".gen")/"sources_1/bd/design_1/ipshared",project/(pname+".ip_user_files")/"bd/design_1/ipshared"]:
        copies=list(base.rglob(source.name))
        if not copies or any(p.read_bytes().replace(b"\r",b"")!=source.read_bytes().replace(b"\r",b"") for p in copies):raise RuntimeError("Stale packaged/copied IP: "+source.name)
files=[out/name for name in ["entropy_health.bit","entropy_health.hwh","entropy_health_pynq.py","analyze_raw.py","entropy_characterize.py","entropy_campaign.py"]]
manifest={"build_id":"entropy-health-"+datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),"hardware_mode":"physical_ro","health_configuration":{"startup_samples":1024,"rct_c":41,"apt_window":1024,"apt_c":793},"physical_entropy_validated":False,"physical_audit":json.loads((out/"physical_audit.json").read_text()),"sha256":{p.name:sha(p) for p in files},"checks":checks,"mutable_files":["Entropy_Health_Bringup.ipynb"],"notebook_template_sha256":sha(out/"Entropy_Health_Bringup.ipynb")}
(out/"release_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print("PASS entropy release preflight",validate_artifacts(out/"entropy_health.bit"))
