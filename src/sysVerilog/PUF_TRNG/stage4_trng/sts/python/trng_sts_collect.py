"""Fixed-size SP800-22 PILOT: 3907 fresh hardware digests, no FPGA/driver changes.

Only the first 1,000,000 bits are tested; all 1,000,192 generated bits are saved.
No retry, filtering, expansion, PRNG or software-hash replacement of FPGA output.
"""
import hashlib,json,shutil,time,uuid,zipfile
from datetime import datetime
from pathlib import Path

BITS=1000000
BATCHES=3907
HEALTH={"status":194,"count":1024,"ro_enable":0,"fault_mask":0,"rct_mask":0,"apt_mask":0,"observed":2048,"startup_seen":1024}


def validate_addon(base_folder="."):
    from trng_pynq import validate_artifacts
    base=Path(base_folder).resolve()
    meta=json.loads((base/"sts_addon_manifest.json").read_text(encoding="utf-8"))
    if meta["mode"]!="single_sequence_pilot" or meta["target_bits"]!=BITS or meta["batches"]!=BATCHES:
        raise RuntimeError("Unexpected STS pilot configuration")
    actual=hashlib.sha256((base/"release_manifest.json").read_bytes()).hexdigest()
    if actual!=meta["base_release_manifest_sha256"]:
        raise RuntimeError("Upload addon beside the ORIGINAL matching eight-file release")
    if hashlib.sha256((base/"trng_sts_collect.py").read_bytes()).hexdigest()!=meta["collector_sha256"]:
        raise RuntimeError("STS collector hash mismatch")
    release=validate_artifacts(base/"trng_sha3.bit")
    if release["build_id"]!=meta["base_build_id"]:raise RuntimeError("Wrong base build")
    return {"mode":"single_sequence_pilot","target_bits":BITS,"fresh_batches":BATCHES,
            "build_id":release["build_id"],"entropy_certified":False}


def collect_pilot(session,board_id,experiment_date,root="sts_pilot_results"):
    if not isinstance(board_id,str) or not board_id.strip():raise ValueError("Record board ID")
    datetime.strptime(experiment_date,"%Y-%m-%d")
    validate_addon(Path(session.bitfile).parent)
    stamp=datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")+"_"+uuid.uuid4().hex[:8]
    folder=Path(root)/(experiment_date+"_"+stamp)
    folder.mkdir(parents=True,exist_ok=False)
    if shutil.disk_usage(str(folder)).free<20*1024*1024:
        raise RuntimeError("Less than 20 MiB free; stop before capture")
    summary={"status":"RUNNING","purpose":"single-sequence SP800-22 pilot, not certification",
             "board_id":board_id,"experiment_date":experiment_date,"board_utc_timestamp":stamp,
             "board_clock_may_be_wrong":True,"build_id":session.release["build_id"],
             "requested_batches":BATCHES,"completed_batches":0,"sequence_bits":BITS,
             "sequences":1,"divider":512,"entropy_certified":False,
             "pvalue_uniformity_assessable":False,"multi_sequence_pass_proportion_assessable":False,
             "bit_order":"MSB first within each byte, matching original NIST binary reader",
             "fixed_selection":"first 125000 bytes of concatenated actual FPGA digests; retain unused tail"}
    def write_summary():
        (folder/"summary.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    write_summary();started=time.monotonic()
    try:
        with (folder/"raw_batches.bin").open("wb") as rawfile,(folder/"digests_all.bin").open("wb") as output,(folder/"batches.jsonl").open("w",encoding="utf-8") as records:
            for index in range(BATCHES):
                result=session.generate(divider=512)
                raw,digest=result["raw"],result["digest"]
                if len(raw)!=1024 or len(digest)!=32 or result["health"]!=HEALTH:
                    raise RuntimeError("Invalid health or batch length")
                if result["build_id"]!=summary["build_id"] or not result["functional_valid"] or not result["fpga_sha3_matches_python"]:
                    raise RuntimeError("Invalid generator acceptance")
                if hashlib.sha3_256(raw).digest()!=digest:raise RuntimeError("Saved FPGA digest mismatch")
                rawfile.write(raw);output.write(digest)
                records.write(json.dumps({"index":index,"raw_offset":index*1024,"digest_offset":index*32,
                    "raw_sha256":hashlib.sha256(raw).hexdigest(),"digest_hex":digest.hex(),
                    "health":result["health"],"build_id":result["build_id"]})+"\n")
                summary["completed_batches"]=index+1
                if (index+1)%128==0 or index+1==BATCHES:
                    rawfile.flush();output.flush();records.flush();write_summary()
                    print("PASS fresh hardware digests {}/{}; RO OFF".format(index+1,BATCHES),flush=True)
        all_digest=(folder/"digests_all.bin").read_bytes()
        if len(all_digest)!=BATCHES*32:raise RuntimeError("Incomplete output")
        (folder/"sha3_output_1000000bits.bin").write_bytes(all_digest[:BITS//8])
        summary.update({"status":"PASS_COLLECTION","generated_bits":len(all_digest)*8,
                        "unused_tail_bits":len(all_digest)*8-BITS,"raw_bytes":BATCHES*1024,
                        "final_health":session.source.snapshot(),"health_faults":0,
                        "duplicate_digests":BATCHES-len({all_digest[i:i+32] for i in range(0,len(all_digest),32)})})
    except BaseException as exc:
        summary.update({"status":"FAILED_STOPPED","error":repr(exc)})
        if hasattr(exc,"snapshot"):summary["fault_snapshot"]=exc.snapshot
        raise
    finally:
        summary["elapsed_seconds"]=time.monotonic()-started
        summary["files"]={p.name:{"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in folder.iterdir() if p.name!="summary.json"}
        write_summary()
        base=Path(session.bitfile).parent
        for name in ("release_manifest.json","sts_addon_manifest.json"):
            (folder/name).write_bytes((base/name).read_bytes())
        archive=folder.with_suffix(".zip")
        with zipfile.ZipFile(str(archive),"w",zipfile.ZIP_DEFLATED) as z:
            for p in sorted(folder.iterdir()):z.write(str(p),p.name)
        print("Saved pilot evidence:",str(archive),flush=True)
    return {"archive":str(archive),"summary":summary}
