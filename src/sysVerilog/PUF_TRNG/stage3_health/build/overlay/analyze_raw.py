"""Descriptive checks only: no entropy estimate and no certification."""
import json,sys
from pathlib import Path

def analyze(raw):
    if not raw:raise ValueError("No raw samples")
    channels=[]
    for k in range(8):
        bits=[(b>>k)&1 for b in raw];ones=sum(bits);changes=sum(a!=b for a,b in zip(bits,bits[1:]));longest=run=1
        for a,b in zip(bits,bits[1:]):
            run=run+1 if a==b else 1;longest=max(longest,run)
        channels.append({"channel":k,"samples":len(bits),"ones_fraction":ones/len(bits),"transitions":changes,"longest_identical_run":longest,"stuck":ones in (0,len(bits))})
    return {"samples":len(raw),"channels":channels,"entropy_estimate":None,"warning":"Bias/run checks do not prove unpredictability or certify a TRNG"}
if __name__=="__main__":print(json.dumps(analyze(Path(sys.argv[1]).read_bytes()),indent=2))
