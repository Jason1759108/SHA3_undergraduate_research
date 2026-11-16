"""Bounded end-to-end collection. Preserve raw data independently of SHA3 output."""
import hashlib
import json
import time
import uuid
import zipfile
from datetime import datetime
from pathlib import Path


def collect(session, board_id, experiment_date, count=16, divider=512, root="trng_results"):
    if not isinstance(board_id, str) or not board_id.strip():
        raise ValueError("Record the actual reserved board ID")
    datetime.strptime(experiment_date, "%Y-%m-%d")
    if type(count) is not int or not 1 <= count <= 1000:
        raise ValueError("count must be 1..1000")
    if type(divider) is not int or not 16 <= divider <= 4096:
        raise ValueError("divider must be 16..4096")
    stamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ") + "_" + uuid.uuid4().hex[:8]
    folder = Path(root) / (experiment_date + "_" + stamp)
    folder.mkdir(parents=True, exist_ok=False)
    raws, digests, records = [], [], []
    summary = {"board_id":board_id, "experiment_date":experiment_date,
               "board_utc_timestamp":stamp, "board_clock_may_be_wrong":True,
               "build_id":session.release["build_id"], "requested_batches":count,
               "divider":divider, "status":"RUNNING", "certified":False,
               "entropy_credit_validated":False,
               "note":"RO restarts per batch; startup 1024 discarded; payload 1024 retained. PS bridges raw bytes to FPGA SHA3."}
    def write_summary():
        (folder / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    write_summary()
    try:
        for index in range(count):
            started = time.monotonic()
            result = session.generate(divider)
            raw, digest = result["raw"], result["digest"]
            if len(raw) != 1024 or len(digest) != 32 or not result["functional_valid"]:
                raise RuntimeError("Invalid generator result")
            if hashlib.sha3_256(raw).digest() != digest:
                raise RuntimeError("Independent collection SHA3 comparison failed")
            record = {k:v for k,v in result.items() if k not in ("raw","digest")}
            record.update({"index":index,"raw_sha256":hashlib.sha256(raw).hexdigest(),
                           "digest_hex":digest.hex(), "elapsed_seconds":time.monotonic()-started})
            # Write each accepted batch immediately; preserve earlier evidence on failure.
            (folder / ("batch_%04d.bin" % index)).write_bytes(raw)
            (folder / ("batch_%04d.json" % index)).write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
            raws.append(raw);digests.append(digest);records.append(record)
            if (index+1)%16 == 0 or index+1 == count:
                print("PASS integrated batches {}/{}; RO OFF after each batch".format(index+1,count),flush=True)
        datasets = folder / "datasets"
        datasets.mkdir()
        joint = b"".join(raws)
        (datasets / "raw_joint_concat.bin").write_bytes(joint)
        (datasets / "conditioned_sha3_256.bin").write_bytes(b"".join(digests))
        for k in range(8):
            (datasets / ("raw_channel_%d.bin"%k)).write_bytes(bytes((x>>k)&1 for x in joint))
        if count == 1000:
            (datasets / "restart_joint_1000x1000.bin").write_bytes(b"".join(x[:1000] for x in raws))
        summary.update({"status":"PASS_FUNCTIONAL", "completed_batches":count,
                        "raw_bytes":len(joint), "digest_bytes":32*count,
                        "duplicate_raw_batches":count-len(set(raws)),
                        "duplicate_digests":count-len(set(digests)),
                        "all_hardware_digests_match_python":True,
                        "health_faults":0,"final_health":session.source.snapshot(),
                        "datasets":{p.name:{"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(datasets.iterdir())}})
    except Exception as exc:
        summary.update({"status":"FAILED_STOPPED","completed_batches":len(raws),"error":repr(exc)})
        raise
    finally:
        write_summary()
        # Snapshot the immutable release identity; never silently change it.
        release_path = Path(session.bitfile).parent / "release_manifest.json"
        if release_path.exists():
            (folder / "release_manifest.json").write_bytes(release_path.read_bytes())
        archive = folder.with_suffix(".zip")
        with zipfile.ZipFile(str(archive),"w",zipfile.ZIP_DEFLATED) as z:
            for p in sorted(folder.rglob("*")):
                if p.is_file():z.write(str(p),str(p.relative_to(folder)))
        print("Saved evidence:",str(archive),flush=True)
    return {"archive":str(archive),"summary":summary}
