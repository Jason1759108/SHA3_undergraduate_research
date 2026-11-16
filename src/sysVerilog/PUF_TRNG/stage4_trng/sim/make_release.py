"""Fail-closed release gate: frozen RTL, tested HWH, fresh check fingerprints.

Run only after build/audit and simulations have completed. Never accesses a board.
"""
import ast, hashlib, json, re, shutil, sys, zipfile
from datetime import datetime, timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"python"))
import trng_pynq


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def review_warnings():
    reports=ROOT/"build/reports/trng_integrated"
    def rows(path):
        result={}
        for line in path.read_text(errors="replace").splitlines():
            fields=[s.strip() for s in line.split("|")]
            if len(fields)==6 and re.fullmatch(r"[A-Z]+-\d+",fields[1]):
                result[fields[1]]={"severity":fields[2],"count":int(fields[4])}
        return result
    drc=rows(reports/"drc.rpt");method=rows(reports/"methodology.rpt")
    wanted={"LUTLP-2":("Warning",8),"PDCN-1569":("Warning",3),"REQP-1839":("Warning",8),"RTSTAT-10":("Warning",1),"REQP-181":("Advisory",2)}
    expected={k:{"severity":v[0],"count":v[1]} for k,v in wanted.items()}
    if drc!=expected:raise RuntimeError("Unexpected DRC warnings; inspect before release")
    if method!={k:{"severity":"Warning","count":v} for k,v in {"LUTAR-1":4,"TIMING-23":8,"XDCB-5":1}.items()}:
        raise RuntimeError("Unexpected methodology warnings; inspect before release")
    prior=rows(ROOT.parent/"stage1_sha3/build/reports/drc.rpt")
    if {k:v for k,v in drc.items() if k!="LUTLP-2"}!=prior:
        raise RuntimeError("Vendor DRC warning counts differ from accepted SHA3 baseline")
    # Each detailed warning remains in its inspected source/vendor hierarchy.
    text=(reports/"drc.rpt").read_text(errors="replace")
    for rule,prefix in {"LUTLP-2":"design_1_i/entropy_ip/","PDCN-1569":"design_1_i/axi_memory/","REQP-1839":"design_1_i/sha3/sha3_dma/","RTSTAT-10":"design_1_i/axi_memory/","REQP-181":"design_1_i/sha3/sha3_dma/"}.items():
        sections=re.findall(re.escape(rule)+r"#\d+ (?:Warning|Advisory)\n(.*?)(?=\n[A-Z]+-\d+#|\Z)",text,re.S)
        if len(sections)!=drc[rule]["count"] or any(prefix not in s for s in sections):
            raise RuntimeError("Unexpected warning scope: "+rule)
    result={"status":"PASS","drc":drc,"methodology":method,
            "vendor_drc_matches_previous_sha3":True,
            "note":"Warnings retained, not suppressed. RO loops intentional; vendor FIFO/reset warnings remain a residual implementation caveat. Stop DMA before reconfiguration and validate on board."}
    (ROOT/"build/warning_review.json").write_text(json.dumps(result,indent=2)+"\n")
    return result


def main():
    baseline=json.loads((ROOT/"baseline_sources.json").read_text())
    # Support the explicit map authored when this stage was created.
    for name,record in baseline.items():
        current=ROOT/name;original=ROOT.parent/record["source"]
        if sha(current)!=record["sha256"] or sha(original)!=record["sha256"]:
            raise RuntimeError("Frozen RTL mismatch: "+name)
    for directory in (ROOT/"build/ip_repo", ROOT/"build/trng_integrated/trng_integrated.gen/sources_1/bd/design_1/ipshared"):
        packaged=list(directory.rglob("*.sv"))
        for name in baseline:
            source=ROOT/name
            matches=[p for p in packaged if p.name==source.name]
            if len(matches)!=1 or matches[0].read_bytes().replace(b"\r\n",b"\n")!=source.read_bytes().replace(b"\r\n",b"\n"):
                raise RuntimeError("Packaged/generated RTL mismatch: "+name+" in "+str(directory))
    checks={}
    for suite,filename in {"unit":"unit_pass.json","normal":"normal_pass.json","ft":"ft_pass.json",
                           "axis":"axis_pass.json","system":"system_sim_result.json","host":"host_pass.json"}.items():
        record=json.loads((ROOT/"build"/filename).read_text())
        if record["status"]!="PASS" or not record["source_sha256"]:
            raise RuntimeError("Missing test: "+suite)
        for name,digest in record["source_sha256"].items():
            if sha(ROOT/name)!=digest:raise RuntimeError("Stale test {}: {}".format(suite,name))
        checks[suite]=record
    pending=ROOT/"build/overlay_pending"
    hwh_hash=sha(pending/"trng_sha3.hwh")
    if any(checks[k]["hwh_sha256"]!=hwh_hash for k in ("system","host")):
        raise RuntimeError("Release HWH differs from actual simulated/parsed BD")
    if checks["system"]["sha3_cases"]!=36 or checks["system"]["integrated_cases"]!=2:
        raise RuntimeError("Incomplete integrated system cases")
    if checks["host"]["expected_rejections"]<33:
        raise RuntimeError("Incomplete host rejection checks")
    folder=ROOT/"build/trng_integrated/trng_integrated.sim/sim_1/behav/xsim"
    for step in ("compile","elaborate","simulate"):
        log=(folder/(step+"_driver.log")).read_text(errors="replace")
        if re.search(r"(?m)^ERROR:|Fatal:|FATAL",log):raise RuntimeError("System log errors: "+step)
    for p in (ROOT/"python").glob("*.py"):
        ast.parse(p.read_text(encoding="utf-8"),feature_version=(3,6))
        shutil.copy2(str(p),str(pending/p.name))
    shutil.copy2(str(ROOT/"python/TRNG_Integrated_Bringup.ipynb"),str(pending/"TRNG_Integrated_Bringup.ipynb"))
    warning_review=review_warnings()
    manifest={"build_id":"trng-integrated-"+datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
              "mode":"physical_ro_health_ps_bridge_fpga_sha3","clock_mhz":25,
              "raw_batch_bytes":1024,"output_bytes":32,"sha3_ft_enabled":True,
              "entropy_credit_validated":False,"certified":False,
              "warning_review":warning_review,
              "physical_audit":json.loads((pending/"physical_audit.json").read_text()),
              "baseline_sources":baseline,"checks":checks,
              "sha256":{name:sha(pending/name) for name in sorted(trng_pynq.RELEASE_FILES)}}
    (pending/"release_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    trng_pynq.validate_artifacts(pending/"trng_sha3.bit")
    overlay=ROOT/"build/overlay";overlay.mkdir(exist_ok=True)
    names=sorted(trng_pynq.RELEASE_FILES|{"release_manifest.json","TRNG_Integrated_Bringup.ipynb"})
    for name in names:shutil.copy2(str(pending/name),str(overlay/name))
    archive=ROOT/"delivery/trng_integrated_ready.zip"
    with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as z:
        for name in names:z.write(overlay/name,name)
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None and set(z.namelist())==set(names)
        for name in names:assert hashlib.sha256(z.read(name)).hexdigest()==sha(overlay/name)
    result={"status":"PASS","build_id":manifest["build_id"],"release_zip_sha256":sha(archive),
            "release_files":names,"physical_audit":manifest["physical_audit"],
            "checks":list(checks),"original_stages_unchanged":True,
            "reviewed_warnings":warning_review,
            "board_acceptance":"PENDING","new_layout_entropy_assessment":"PENDING"}
    (ROOT/"build/final_validation.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,indent=2));print("SUCCESS INTEGRATED RELEASE",archive)
if __name__=="__main__":main()
