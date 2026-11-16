"""Original NIST STS 2.1.2, ONE 1,000,000-bit sequence, all 15 families.

Final multi-sequence uniformity/proportion columns are not interpreted for N=1.
Unavailable random-excursion tests are N/A, not pass/fail; never redraw for PASS.
"""
import argparse,hashlib,json,math,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent
NAMES=['Frequency','BlockFrequency','CumulativeSums','Runs','LongestRun','Rank','FFT',
       'NonOverlappingTemplate','OverlappingTemplate','Universal','ApproximateEntropy',
       'RandomExcursions','RandomExcursionsVariant','Serial','LinearComplexity']
COUNTS=dict(zip(NAMES,[1,1,2,1,1,1,1,148,1,1,1,8,18,2,1]))


def run(input_file,output_folder,ascii_mode=False):
    source=Path(input_file).resolve();out=Path(output_folder).resolve()
    if not ascii_mode and source.stat().st_size!=125000:
        raise ValueError('Pilot requires exactly 125000 bytes = 1000000 bits; no repetition or padding')
    provenance=json.loads((ROOT/'tools/build_provenance.json').read_text())
    exe=ROOT/'tools/assess.exe'
    if hashlib.sha256(exe.read_bytes()).hexdigest()!=provenance['exe_sha256']:raise RuntimeError('Tool hash mismatch')
    if hashlib.sha256((ROOT/'tools/templates/template9').read_bytes()).hexdigest()!=provenance['template9_sha256']:
        raise RuntimeError('Official template hash mismatch')
    control=json.loads((ROOT/'tools/selftest_result.json').read_text())
    if control['status']!='PASS' or control['exe_sha256']!=provenance['exe_sha256']:
        raise RuntimeError('Tool reference/negative controls not validated')
    out.mkdir(parents=True,exist_ok=False)
    shutil.copytree(ROOT/'tools/templates',out/'templates')
    shutil.copy2(source,out/'input.bin')
    for name in NAMES:(out/'experiments/AlgorithmTesting'/name).mkdir(parents=True)
    # File generator; all tests; unchanged default parameters; one stream; format.
    answers='0\ninput.bin\n1\n0\n1\n{}\n'.format(0 if ascii_mode else 1)
    (out/'menu_input.txt').write_text(answers)
    env=os.environ.copy();env['PATH']='C:/msys64/mingw64/bin'+os.pathsep+env['PATH']
    proc=subprocess.run([str(exe),'1000000'],cwd=str(out),input=answers,text=True,
                        stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env=env,timeout=120)
    text=proc.stdout;(out/'console.log').write_text(text)
    # This original NIST main() returns 1 on its NORMAL success path.
    if proc.returncode!=1 or 'Statistical Testing Complete' not in text or 'ERROR' in text or 'Aborted' in text:
        raise RuntimeError('Original STS did not complete; inspect '+str(out/'console.log'))
    folder=out/'experiments/AlgorithmTesting'
    if 'BITSREAD = 1000000' not in (folder/'freq.txt').read_text():raise RuntimeError('Wrong bit count')
    tests=[]
    for name in NAMES:
        stats=(folder/name/'stats.txt').read_text()
        values=[float(v) for v in (folder/name/'results.txt').read_text().split()]
        if len(values)!=COUNTS[name] or any(not math.isfinite(p) or not 0<=p<=1 for p in values):
            raise RuntimeError('Incomplete/invalid STS values: '+name)
        unavailable='TEST NOT APPLICABLE' in stats
        if unavailable and name not in ('RandomExcursions','RandomExcursionsVariant'):
            raise RuntimeError('Unexpected unavailable test: '+name)
        tests.append({'test':name,'status':'NOT_APPLICABLE' if unavailable else ('HAS_P_BELOW_0.01' if any(p<.01 for p in values) else 'NO_P_BELOW_0.01'),
                      'alpha':.01,'p_values':None if unavailable else values,
                      'components':len(values),'low_p_components':None if unavailable else sum(p<.01 for p in values),
                      'note':'Insufficient return-to-zero cycles; preserve result, do not redraw' if unavailable else ''})
    result={'status':'SINGLE_SEQUENCE_PILOT_COMPLETED','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'source_bytes':source.stat().st_size,'sequence_bits':1000000,'sequences':1,
            'original_tool':'NIST STS 2.1.2; unmodified C source, native MinGW build',
            'tool_sha256':provenance['exe_sha256'],'tests_attempted':15,
            'applicable_test_families':sum(t['status']!='NOT_APPLICABLE' for t in tests),
            'pvalue_uniformity_assessed':False,'multi_sequence_pass_proportion_assessed':False,
            'entropy_estimate':None,'certified':False,'tests':tests,
            'note':'Single-sequence component P-values only. A few low P-values can occur by chance across many components. No all-tests/cryptographic-certification claim.'}
    (out/'pilot_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('input');ap.add_argument('output');ap.add_argument('--ascii',action='store_true')
    a=ap.parse_args();result=run(a.input,a.output,a.ascii)
    print(json.dumps({k:v for k,v in result.items() if k!='tests'},indent=2))
