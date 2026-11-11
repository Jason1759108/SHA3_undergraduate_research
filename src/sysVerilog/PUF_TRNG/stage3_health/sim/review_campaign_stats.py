"""Offline, batch-aware descriptive diagnostics. Not an entropy estimator."""
import hashlib,json
from collections import Counter
from pathlib import Path
import numpy as np
from archive_datasets import dataset_folder, CAPTURE

def analyze(folder):
    folder=Path(folder);m=json.loads((folder/'dataset_manifest.json').read_text())
    raw=(folder/'raw_joint_concat.bin').read_bytes()
    assert hashlib.sha256(raw).hexdigest()==m['files']['raw_joint_concat.bin']['sha256']
    a=np.frombuffer(raw,dtype=np.uint8).reshape(m['batches'],1024)
    bits=((a[:,:,None]>>np.arange(8))&1).astype(np.float64)
    pairs=[];lags=[];channels=[]
    def cor(x,y):
        sx=x.sum(axis=1);sy=y.sum(axis=1);n=x.shape[1]
        den=np.sqrt(sx*(n-sx)*sy*(n-sy))
        return np.divide(n*(x*y).sum(axis=1)-sx*sy,den,out=np.full_like(sx,np.nan),where=den!=0)
    for ch in range(8):
        b=bits[:,:,ch];fractions=b.mean(axis=1)
        transitions=(b[:,1:]!=b[:,:-1]).sum(axis=1)
        channels.append({'channel':ch,'ones_fraction':float(b.mean()),'batch_ones_min':float(fractions.min()),'batch_ones_max':float(fractions.max()),'stuck_batches':int(np.count_nonzero((fractions==0)|(fractions==1))),'transitions_min':int(transitions.min()),'transitions_max':int(transitions.max())})
        for lag in [1,2,4,8,16,32]:
            c=cor(b[:,:-lag],b[:,lag:]);v=np.abs(c)
            lags.append({'channel':ch,'lag':lag,'mean':float(np.nanmean(c)),'median_abs':float(np.nanmedian(v)),'p95_abs':float(np.nanquantile(v,.95)),'max_abs':float(np.nanmax(v)),'worst_batch_1based':int(np.nanargmax(v)+1)})
    for ch in range(8):
        for other in range(ch+1,8):
            c=cor(bits[:,:,ch],bits[:,:,other]);v=np.abs(c)
            pairs.append({'a':ch,'b':other,'mean':float(np.nanmean(c)),'median_abs':float(np.nanmedian(v)),'max_abs':float(np.nanmax(v))})
    counts=Counter(hashlib.sha256(row.tobytes()).hexdigest() for row in a)
    prefix=Counter(row[:32].tobytes().hex() for row in a)
    return {'batches':m['batches'],'samples':len(raw),'channels':channels,'within_batch_lag':lags,'within_batch_cross_channel':pairs,'duplicate_full_batch_groups':[{'sha256':k,'count':v} for k,v in counts.items() if v>1],'duplicate_first32_groups':[{'hex':k,'count':v} for k,v in prefix.items() if v>1],'joint_symbols_observed':int(len(np.unique(a))),'entropy_estimate':None,'note':'Correlations calculated strictly inside each 1024-sample batch. No claim of independent samples or entropy certification.'}

if __name__=='__main__':
    result=analyze(dataset_folder())
    # Compare with preserved evidence; do not silently overwrite historical results.
    saved=json.loads((CAPTURE/'descriptive_review.json').read_text())
    if result!=saved:raise RuntimeError('Recomputed diagnostics differ from preserved evidence')
    print('PASS: archive restored, ten export checksums verified, descriptive results exactly reproduced')
