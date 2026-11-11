"""Small, finite, restart-aware characterization. No FPGA reconfiguration here."""
import hashlib,json,re,uuid
from datetime import datetime,timezone
from pathlib import Path
from entropy_health_pynq import save_capture,validate_artifacts

def _write(path,data):
    tmp=path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    tmp.replace(path)

def collect(session,board_id,experiment_date,output_root="characterization",dividers=(64,128,256,512),rounds=8):
    if not isinstance(board_id,str) or not board_id.strip():raise ValueError("Record the actual board ID")
    datetime.strptime(experiment_date,"%Y-%m-%d")
    if not isinstance(rounds,int) or isinstance(rounds,bool) or not 1<=rounds<=16:raise ValueError("rounds must be 1..16")
    dividers=tuple(dividers)
    if not dividers or len(set(dividers))!=len(dividers) or len(dividers)*rounds>128:raise ValueError("Use unique dividers and at most 128 batches")
    if any(not isinstance(v,int) or isinstance(v,bool) or not 16<=v<=4096 for v in dividers):raise ValueError("divider must be 16..4096")
    release_bytes=None
    if getattr(session,"bitfile",None):
        current=validate_artifacts(session.bitfile)
        if current["build_id"]!=session.release["build_id"]:raise RuntimeError("Release changed since session initialization")
        release_bytes=(Path(session.bitfile).parent/"release_manifest.json").read_bytes()
    safe_board=re.sub(r"[^A-Za-z0-9_-]","_",board_id)
    run_id=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")+"_"+uuid.uuid4().hex[:8]
    out=Path(output_root)/("board_"+safe_board)/(experiment_date+"_"+run_id)
    out.mkdir(parents=True,exist_ok=False)
    manifest={"schema":1,"board_id":board_id,"experiment_date_user_recorded":experiment_date,"board_system_utc":datetime.now(timezone.utc).isoformat(),"clock_note":"Board clock not independently verified; keep the operator-recorded date", "run_id":run_id,"build_id":session.release["build_id"],"collector_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),"dividers":list(dividers),"rounds":rounds,"planned_batches":len(dividers)*rounds,"capture_capacity":1024,"status":"running","batches":[],"ro_off_confirmed":False,"physical_entropy_certified":False,"acquisition":"Every batch discards 1024 startup-test samples before 1024 payload samples; RO restarts; concatenation is NOT continuous"}
    if release_bytes is not None:
        (out/"release_manifest.json").write_bytes(release_bytes)
        manifest["release_manifest_sha256"]=hashlib.sha256(release_bytes).hexdigest()
    mp=out/"run_manifest.json";_write(mp,manifest)
    print("Saving to",str(out),flush=True)
    try:
        for round_index in range(rounds):
            offset=round_index%len(dividers);order=dividers[offset:]+dividers[:offset]
            for divider in order:
                if session.mmio.read(0x14)!=0x524f4832 or session.mmio.read(0x0c)!=1024:raise RuntimeError("Hardware identity/capacity changed")
                capture=session.capture(divider=divider)
                index=len(manifest["batches"])+1
                prefix=out/("capture_{:03d}_div{:04d}".format(index,divider))
                save_capture(capture,prefix,board_id)
                meta=json.loads(prefix.with_suffix(".json").read_text(encoding="utf-8"))
                meta.update({"round":round_index+1,"batch_index":index,"run_id":run_id,"board_system_utc":datetime.now(timezone.utc).isoformat()})
                _write(prefix.with_suffix(".json"),meta)
                ro_off=session.mmio.read(0x20)==0
                reasons=[]
                if capture["status"]!=194 or capture["alarm"] or capture["fault_mask"]:reasons.append("capture fault/abort/watchdog")
                if capture["count"]!=1024 or len(capture["raw"])!=1024:reasons.append("incomplete capture")
                if capture["divider"]!=divider or capture["build_id"]!=manifest["build_id"]:reasons.append("settings/build changed")
                if not ro_off:reasons.append("RO is still enabled")
                manifest["batches"].append({"json":prefix.with_suffix(".json").name,"bin":prefix.with_suffix(".bin").name,"divider":divider,"round":round_index+1,"count":capture["count"],"status":capture["status"],"sha256":meta["sha256"],"ro_off":ro_off})
                if reasons:
                    manifest["status"]="stopped_on_fault";manifest["reason"]="; ".join(reasons);_write(mp,manifest)
                    print("STOP: saved partial/fault data;",manifest["reason"],flush=True)
                    break
                _write(mp,manifest)
                print("CAPTURE {}/{} round={} divider={} samples=1024 RO=OFF".format(index,manifest["planned_batches"],round_index+1,divider),flush=True)
            if manifest["status"]=="stopped_on_fault":break
        else:manifest["status"]="complete"
    except BaseException as exc:
        manifest["status"]="interrupted" if isinstance(exc,KeyboardInterrupt) else "error"
        manifest["reason"]=repr(exc)
        if hasattr(exc,"snapshot"):manifest["fault_snapshot"]=exc.snapshot
        raise
    finally:
        try:
            session.close();manifest["ro_off_confirmed"]=True
        except BaseException as exc:
            manifest["cleanup_error"]=repr(exc)
            if manifest["status"]=="complete":manifest["status"]="cleanup_failed"
        _write(mp,manifest)
    return {"folder":str(out),"status":manifest["status"],"batches":len(manifest["batches"]),"planned_batches":manifest["planned_batches"],"ro_off_confirmed":manifest["ro_off_confirmed"]}
