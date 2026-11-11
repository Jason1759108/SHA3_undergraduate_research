"""Integrity + descriptive within-batch/restart comparisons, NOT entropy certification."""
import argparse,hashlib,json,math
from pathlib import Path
from analyze_raw import analyze

def correlation(a,b):
    n=len(a)
    if n!=len(b) or n==0:return None
    sa=sum(a);sb=sum(b);den=math.sqrt(sa*(n-sa)*sb*(n-sb))
    return None if den==0 else (n*sum(x*y for x,y in zip(a,b))-sa*sb)/den

def features(raw):
    if not raw:return {"samples":0,"basic":None,"pairwise":[],"lag":[]}
    bits=[[(b>>k)&1 for b in raw]for k in range(8)]
    pairs=[{"a":i,"b":j,"correlation":correlation(bits[i],bits[j])}for i in range(8)for j in range(i+1,8)]
    lag=[{"channel":k,"lag":v,"correlation":correlation(b[:-v],b[v:])}for k,b in enumerate(bits)for v in [1,2,4,8,16,32]if len(b)>v]
    return {"samples":len(raw),"basic":analyze(raw),"pairwise":pairs,"lag":lag}

def review(folder):
    folder=Path(folder);m=json.loads((folder/"run_manifest.json").read_text(encoding="utf-8"));rows=[];groups={};digests={};prefixes={}
    if "release_manifest_sha256" in m:
        if hashlib.sha256((folder/"release_manifest.json").read_bytes()).hexdigest()!=m["release_manifest_sha256"]:raise ValueError("Release manifest snapshot mismatch")
    for entry in m["batches"]:
        for key in ["bin","json"]:
            if Path(entry[key]).name!=entry[key]:raise ValueError("Unexpected file path")
        raw=(folder/entry["bin"]).read_bytes();meta=json.loads((folder/entry["json"]).read_text(encoding="utf-8"));digest=hashlib.sha256(raw).hexdigest()
        if digest!=meta["sha256"] or digest!=entry["sha256"] or len(raw)!=meta["count"] or len(raw)!=entry["count"]:raise ValueError("Capture integrity failed: "+entry["bin"])
        if meta["board_id"]!=m["board_id"] or meta["build_id"]!=m["build_id"] or meta["divider"]!=entry["divider"]:raise ValueError("Capture metadata mismatch")
        f=features(raw);rows.append({"bin":entry["bin"],"divider":entry["divider"],"round":entry["round"],"status":meta["status"],"alarm":meta["alarm"],"features":f})
        groups.setdefault(entry["divider"],[]).append((entry["bin"],raw))
        digests.setdefault(digest,[]).append(entry["bin"])
        if len(raw)>=32:prefixes.setdefault(raw[:32].hex(),[]).append(entry["bin"])
    grouped=[]
    for divider,batches in sorted(groups.items()):
        pair_values=[];lag_values=[];fractions=[];stuck=[]
        indices=[row for row in rows if row["divider"]==divider]
        for row in indices:
            f=row["features"]
            if f["basic"]:
                fractions.extend(c["ones_fraction"] for c in f["basic"]["channels"])
                stuck.extend({"file":row["bin"],"channel":c["channel"]}for c in f["basic"]["channels"]if c["stuck"])
            pair_values.extend(abs(v["correlation"])for v in f["pairwise"]if v["correlation"] is not None)
            lag_values.extend(abs(v["correlation"])for v in f["lag"]if v["correlation"] is not None)
        distances=[]
        for i in range(len(batches)):
            for j in range(i+1,len(batches)):
                a,b=batches[i][1],batches[j][1]
                if len(a)==len(b) and a:
                    distances.append(sum(bin(x^y).count("1")for x,y in zip(a,b))/(8*len(a)))
        grouped.append({"divider":divider,"sampling_interval_us":divider/25.0,"batches":len(batches),"samples":sum(len(b)for _,b in batches),"ones_fraction_min":min(fractions)if fractions else None,"ones_fraction_max":max(fractions)if fractions else None,"max_abs_within_batch_cross_channel_correlation":max(pair_values)if pair_values else None,"max_abs_within_batch_lag_correlation":max(lag_values)if lag_values else None,"stuck_channels":stuck,"restart_pair_bit_difference_min":min(distances)if distances else None,"restart_pair_bit_difference_max":max(distances)if distances else None})
    expected=set(v["bin"]for v in m["batches"])
    return {"integrity":"PASS","run_status":m["status"],"board_id":m["board_id"],"build_id":m["build_id"],"batches":len(rows),"total_samples":sum(row["features"]["samples"]for row in rows),"groups":grouped,"duplicate_full_batches":[v for v in digests.values()if len(v)>1],"duplicate_first_32_bytes":[v for v in prefixes.values()if len(v)>1],"unreferenced_bin_files":[p.name for p in folder.glob("capture_*.bin")if p.name not in expected],"per_batch":rows,"entropy_estimate":None,"physical_entropy_certified":False,"limitations":"Every batch is a separate RO restart. No boundary-crossing autocorrelation; no continuous million-sample claim; descriptive maxima have no automatic pass threshold."}

def main():
    a=argparse.ArgumentParser();a.add_argument("folder");args=a.parse_args();folder=Path(args.folder);data=review(folder)
    (folder/"characterization_review.json").write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    summary={k:v for k,v in data.items()if k!="per_batch"};print(json.dumps(summary,indent=2))
    print("Saved",folder/"characterization_review.json")
if __name__=="__main__":main()
