import sys,subprocess,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];log=ROOT/'build/collection_checks.log'
with log.open('w',encoding='utf-8') as f:q=subprocess.run([sys.executable,'-m','unittest','discover','-s',str(ROOT/'sim'),'-p','test_*.py'],stdout=f,stderr=subprocess.STDOUT)
text=log.read_text(encoding='utf-8')
if q.returncode or 'FAILED' in text:print(text[-4000:]);raise SystemExit('Collection tests failed')
inputs=list((ROOT/'python').glob('*.py'))+list((ROOT/'sim').glob('test_*.py'))+[ROOT/'sim/review_characterization.py',ROOT/'sim/run_collection.py',ROOT/'python/Entropy_Health_Bringup.ipynb']
summary={'status':'PASS','tests_run':int(re.search(r'Ran (\d+) tests',text).group(1)),'skipped':int(re.search(r'skipped=(\d+)',text).group(1))if 'skipped=' in text else 0,'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}}
(ROOT/'build/collection_pass.json').write_text(json.dumps(summary,indent=2)+'\n')
print(text[-300:]);print('Recorded collection gate:',summary['tests_run'],'tests, skipped',summary['skipped'])
