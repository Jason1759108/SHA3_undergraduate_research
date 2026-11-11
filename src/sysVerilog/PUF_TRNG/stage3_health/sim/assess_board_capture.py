"""Offline only. Frozen NIST binaries; no notebook or board-side code executed."""
import os,subprocess,json,re,time,hashlib
from pathlib import Path
from archive_datasets import dataset_folder
ROOT=Path(__file__).resolve().parents[1]
OLD=ROOT.parent/'stage2_entropy'
BIN=OLD/'build/nist_native'
OUT=ROOT/'captures/board_21600/health_20261111'
DATA=dataset_folder()
R=OUT/'nist_results';R.mkdir(exist_ok=True)
previous=json.loads((OLD/'captures/board_21600/assessment_20261111/assessment_summary.json').read_text())
for exe,digest in previous['tool_binary_sha256'].items():
    assert hashlib.sha256((BIN/exe).read_bytes()).hexdigest()==digest
assert previous['official_non_iid_reference_selftests_passed']==11
(R/'tool_provenance.json').write_text(json.dumps({'unchanged_binary_hashes':previous['tool_binary_sha256'],'source_commits':previous['source_commits'],'selftests_reused':'11 official non-IID fixtures; unchanged binaries and configuration','restart_controls_reused':'known-positive and repeated-row negative controls from previous assessment','native_port_note':previous['native_port_note']},indent=2)+'\n')
env=os.environ.copy();env['PATH']='C:/msys64/mingw64/bin'+os.pathsep+env['PATH'];env['OMP_NUM_THREADS']='4'
records=[]
def run(label,exe,args):
    cmd=[str(BIN/exe)]+list(map(str,args));start=time.time()
    with (R/(label+'.log')).open('w',encoding='utf-8') as log:
        q=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=env)
    text=(R/(label+'.log')).read_text()
    records.append({'label':label,'command':cmd,'returncode':q.returncode,'seconds':time.time()-start})
    (R/'execution_index.json').write_text(json.dumps(records,indent=2)+'\n')
    print(label,'rc',q.returncode,'seconds',round(records[-1]['seconds'],2),flush=True)
    return q.returncode,text
assessments=[]
for label,name,bits in [('joint','raw_joint_concat.bin',8)]+[('channel_'+str(k),'channel_'+str(k)+'_concat.bin',1) for k in range(8)]:
    rc,text=run(label,'ea_non_iid.exe',['-i','-a','-vv',DATA/name,str(bits)])
    hit=re.findall(r'Assessed min entropy:\s*([0-9.eE+-]+)',text)
    if rc or not hit:raise RuntimeError('Non-IID run incomplete: '+label)
    item={'label':label,'bits_per_symbol':bits,'samples':1024000,'initial_statistical_estimate':float(hit[-1]),'sha256':hashlib.sha256((DATA/name).read_bytes()).hexdigest(),'not_validated_entropy_credit':True}
    assessments.append(item);(R/'non_iid_summary.json').write_text(json.dumps(assessments,indent=2)+'\n')
restarts=[]
for item in assessments:
    label=item['label']
    if label=='joint':path=DATA/'restart_joint_rows.bin'
    else:
        ch=int(label.split('_')[1]);path=R/('restart_'+label+'.bin')
        path.write_bytes(bytes((b>>ch)&1 for b in (DATA/'restart_joint_rows.bin').read_bytes()))
    rc,text=run('restart_'+label,'ea_restart_windows.exe',['-n','-vv',path,str(item['bits_per_symbol']),str(item['initial_statistical_estimate'])])
    v=dict(item);v['returncode']=rc;v['restart_passed']=rc==0 and 'Validation Test Passed' in text
    for name,pattern in [('restart_H_r',r'H_r:\s*([0-9.eE+-]+)'),('restart_H_c',r'H_c:\s*([0-9.eE+-]+)'),('retained_statistical_estimate',r'min\(H_r, H_c, H_I\):\s*([0-9.eE+-]+)')]:
        hits=re.findall(pattern,text)
        v[name]=float(hits[-1]) if hits else None
    restarts.append(v);(R/'restart_summary.json').write_text(json.dumps(restarts,indent=2)+'\n')
print('Completed all requested assessments; failed results, if any, retained',flush=True)
