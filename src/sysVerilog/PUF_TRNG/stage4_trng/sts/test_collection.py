"""OFFLINE MOCK ONLY: execute authored notebook, verify 3907-digest trace, reject faults."""
import ast,hashlib,json,os,shutil,sys,tempfile,types,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'python'));sys.path.insert(0,str(ROOT.parent/'python'))
import trng_sts_collect as c
import trng_pynq
from trng_health import HealthFailure
from review_sts_capture import review


def main():
    print('OFFLINE MOCK ONLY: no FPGA or board accessed',flush=True)
    base=ROOT.parent/'build/overlay';release=json.loads((base/'release_manifest.json').read_text())
    checks=0
    def rejects(fn,typ=Exception):
        nonlocal checks
        try:fn()
        except typ:checks+=1
        else:raise AssertionError('Expected rejection')
    with tempfile.TemporaryDirectory(dir=ROOT/'build') as tmp:
        temp=Path(tmp);folder=temp/'base';shutil.copytree(base,folder)
        for p in (ROOT/'python').iterdir():
            if p.is_file():shutil.copy2(p,folder/p.name)
        class Mock:
            fail_at=None;corrupt=False
            def __init__(self,bitfile):
                self.bitfile=str(Path(bitfile).resolve());self.release={'build_id':release['build_id']};self.count=0;self.closed=False
                mmio=types.SimpleNamespace(read=lambda off:0 if off==32 else 1)
                self.source=types.SimpleNamespace(snapshot=lambda:dict(c.HEALTH),mmio=mmio)
                self.engine=types.SimpleNamespace(_mmio=mmio)
            def self_test(self,rounds):return 34
            def generate(self,divider=512):
                if self.count==self.fail_at:raise HealthFailure('mock alarm',{'status':6,'rct_mask':255})
                raw=hashlib.sha3_512(self.count.to_bytes(8,'little')).digest()*16
                self.count+=1;digest=hashlib.sha3_256(raw).digest()
                if self.corrupt:digest=bytes(32)
                return {'raw':raw,'digest':digest,'health':dict(c.HEALTH),'build_id':self.release['build_id'],'functional_valid':True,'fpga_sha3_matches_python':True}
            def close(self):self.closed=True
        old=trng_pynq.TrngSession;trng_pynq.TrngSession=Mock
        sys.modules['pynq']=types.SimpleNamespace(__version__='2.5')
        nb=json.loads((ROOT/'python/TRNG_STS_Pilot.ipynb').read_text(encoding='utf-8'));env={};cwd=os.getcwd()
        try:
            os.chdir(folder)
            for cell in nb['cells']:
                if cell['cell_type']=='code':
                    text=''.join(cell['source']).replace('experiment_date = "請填實際日期 YYYY-MM-DD"','experiment_date = "2026-11-16"')
                    ast.parse(text,feature_version=(3,6));exec(compile(text,'authored-notebook-MOCK','exec'),env)
            archive=folder/env['pilot']['archive']
        finally:os.chdir(cwd);trng_pynq.TrngSession=old
        assert env['session'].closed and env['session'].count==3907
        result=review(archive,temp/'reviewed',False);assert result['fpga_digests_recomputed']==3907
        for mode in ('alarm','corrupt'):
            session=Mock(folder/'trng_sha3.bit')
            if mode=='alarm':session.fail_at=3
            else:session.corrupt=True
            rejects(lambda:c.collect_pilot(session,'mock-board','2026-11-16',root=temp/mode))
            failed=list((temp/mode).glob('*/summary.json'));s=json.loads(failed[0].read_text())
            assert s['status']=='FAILED_STOPPED' and s['completed_batches']==(3 if mode=='alarm' else 0)
            assert not list((temp/mode).glob('*/sha3_output_1000000bits.bin'))
            if mode=='alarm':assert s['fault_snapshot']['rct_mask']==255
        for target in ('raw_batches.bin','sha3_output_1000000bits.bin'):
            bad=temp/(target+'.zip')
            with zipfile.ZipFile(archive) as z:
                files={name:z.read(name) for name in z.namelist()}
            files[target]=bytes([files[target][0]^1])+files[target][1:]
            summary=json.loads(files['summary.json']);summary['files'][target]['sha256']=hashlib.sha256(files[target]).hexdigest()
            files['summary.json']=json.dumps(summary).encode()
            with zipfile.ZipFile(bad,'w',zipfile.ZIP_DEFLATED) as z:
                for name,data in files.items():z.writestr(name,data)
            rejects(lambda:review(bad,temp/('bad_'+target),False),RuntimeError)
        original=(folder/'trng_sts_collect.py').read_bytes();(folder/'trng_sts_collect.py').write_bytes(b'tampered')
        rejects(lambda:c.validate_addon(folder),RuntimeError);(folder/'trng_sts_collect.py').write_bytes(original)
    result={'status':'PASS','mock_only':True,'authored_notebook_executed':True,'fresh_mock_digests':3907,
            'source_and_digest_trace_recomputed':True,'fault_no_retry':True,'raw_and_output_tampering_rejected':True,
            'expected_rejections':checks,'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'python/trng_sts_collect.py',ROOT/'python/TRNG_STS_Pilot.ipynb',ROOT/'python/sts_addon_manifest.json',ROOT/'review_sts_capture.py',Path(__file__)]}}
    (ROOT/'tools/collection_test.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
