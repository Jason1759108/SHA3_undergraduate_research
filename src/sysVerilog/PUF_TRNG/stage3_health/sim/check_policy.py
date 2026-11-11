import math,json,hashlib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'python'))
from health_model import Monitor
H=.5;alpha=2.0**-20;n=1024;p=2.0**-H
# Exact binomial upper tail in log domain; use the NIST footnote's W trials.
def tail(c):
    return sum(math.exp(math.lgamma(n+1)-math.lgamma(k+1)-math.lgamma(n-k+1)+k*math.log(p)+(n-k)*math.log1p(-p)) for k in range(c,n+1))
c=next(c for c in range(math.ceil(n*p),n+1) if tail(c)<=alpha)
assert c==793 and tail(c-1)>alpha
assert 1+math.ceil(-math.log2(alpha)/H)==41
# Source data are immutable baseline evidence, not a new-build board validation.
source=ROOT.parent/'stage2_entropy/captures/board_21600/assessment_20261111/2026-11-11_20261110T064656Z_36e867d1/datasets/raw_joint_concat.bin'
raw=source.read_bytes();assert len(raw)==1024000
failures=[]
for batch in range(1000):
    m=Monitor()
    for value in raw[batch*1024:(batch+1)*1024]:m.step(value)
    if m.rct_mask or m.apt_mask:failures.append(batch+1)
assert not failures
result={'status':'PASS','monitoring_assumption_bits_per_channel_sample':H,'alpha_per_test':alpha,'not_validated_entropy_credit':True,'RCT_C':41,'APT_WINDOW':n,'APT_C':c,'binomial_tail_at_cutoff':tail(c),'binomial_tail_one_below':tail(c-1),'baseline_batches_replayed':1000,'baseline_health_failures':failures,'baseline_sha256':hashlib.sha256(raw).hexdigest(),'new_hardware_entropy_validated':False,'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'sim/check_policy.py',ROOT/'python/health_model.py']}}
(ROOT/'build/policy_pass.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
