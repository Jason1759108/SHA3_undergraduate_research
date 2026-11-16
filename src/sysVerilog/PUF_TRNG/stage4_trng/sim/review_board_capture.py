"""Offline integrity/functional review of the BOARD collection ZIP, not entropy certification."""
import argparse, hashlib, json, zipfile
from pathlib import Path
HEALTH={"status":194,"count":1024,"ro_enable":0,"fault_mask":0,"rct_mask":0,"apt_mask":0,"observed":2048,"startup_seen":1024}


def review(path, release_manifest):
    expected=json.loads(Path(release_manifest).read_text())
    with zipfile.ZipFile(path) as z:
        names=z.namelist()
        if len(names)!=len(set(names)) or sum(i.file_size for i in z.infolist())>32*1024*1024:
            raise RuntimeError("Duplicate ZIP entries or oversized collection")
        summary=json.loads(z.read("summary.json"));release=json.loads(z.read("release_manifest.json"))
        if release!=expected or summary["build_id"]!=expected["build_id"]:
            raise RuntimeError("Collection belongs to a different release")
        count=summary["completed_batches"]
        if type(count) is not int or not 1<=count<=1000 or count!=summary["requested_batches"] or summary["status"]!="PASS_FUNCTIONAL":
            raise RuntimeError("Incomplete/failed collection; inspect retained failure evidence")
        if summary["entropy_credit_validated"] is not False or summary["certified"] is not False:
            raise RuntimeError("Unsupported certification claim")
        raws=[];digests=[]
        for index in range(count):
            raw=z.read("batch_%04d.bin"%index);record=json.loads(z.read("batch_%04d.json"%index))
            digest=bytes.fromhex(record["digest_hex"])
            if len(raw)!=1024 or record["index"]!=index or record["build_id"]!=expected["build_id"] or record["health"]!=HEALTH:
                raise RuntimeError("Invalid batch metadata: "+str(index))
            if record["divider"]!=summary["divider"] or not record["functional_valid"] or not record["fpga_sha3_matches_python"]:
                raise RuntimeError("Invalid batch acceptance: "+str(index))
            if hashlib.sha256(raw).hexdigest()!=record["raw_sha256"] or hashlib.sha3_256(raw).digest()!=digest:
                raise RuntimeError("Raw/digest integrity mismatch: "+str(index))
            raws.append(raw);digests.append(digest)
        joint=b"".join(raws)
        datasets={"raw_joint_concat.bin":joint,"conditioned_sha3_256.bin":b"".join(digests)}
        datasets.update({"raw_channel_%d.bin"%k:bytes((x>>k)&1 for x in joint) for k in range(8)})
        if count==1000:datasets["restart_joint_1000x1000.bin"]=b"".join(r[:1000] for r in raws)
        if set(summary["datasets"])!=set(datasets):raise RuntimeError("Wrong dataset set")
        for name,data in datasets.items():
            if z.read("datasets/"+name)!=data or summary["datasets"][name]!={"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()}:
                raise RuntimeError("Derived dataset mismatch: "+name)
        if summary["raw_bytes"]!=len(joint) or summary["digest_bytes"]!=32*count or summary["health_faults"]!=0 or not summary["all_hardware_digests_match_python"] or summary["final_health"]!=HEALTH:
            raise RuntimeError("Summary inconsistency")
    return {"status":"PASS_FUNCTIONAL_EVIDENCE","build_id":expected["build_id"],"board_id":summary["board_id"],
            "experiment_date":summary["experiment_date"],"batches":count,"raw_bytes":len(joint),
            "duplicate_raw_batches":count-len(set(raws)),"duplicate_digests":count-len(set(digests)),
            "all_saved_digests_match_python":True,"new_layout_entropy_assessment":"PENDING",
            "entropy_credit_validated":False,"certified":False,
            "note":"Checks internal consistency of provided evidence; does not authenticate the physical board or prove entropy."}


if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("archive");ap.add_argument("--manifest",default=str(Path(__file__).resolve().parents[1]/"build/overlay/release_manifest.json"));ap.add_argument("--output")
    a=ap.parse_args();result=review(a.archive,a.manifest);text=json.dumps(result,indent=2)
    if a.output:Path(a.output).write_text(text+"\n",encoding="utf-8")
    print(text)
