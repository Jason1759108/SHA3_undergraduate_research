import os,subprocess,json,hashlib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];folder=ROOT/'build/monitor'
subprocess.run([sys.executable,str(ROOT/'sim/prepare_health_vectors.py')],check=True)
env=os.environ.copy();bin=Path('D:/VIVADO/2025.2/Vivado/bin');env['PATH']=str(bin)+os.pathsep+env['PATH']
for name in ['small','default']:
    for step,args in [('compile',['xvlog.bat','--sv',ROOT/'rtl/entropy_health_monitor.sv',folder/('tb_monitor_'+name+'.sv')]),('elaborate',['xelab.bat','tb_monitor_'+name,'-s','monitor_'+name,'--timescale','1ns/1ps']),('simulate',['xsim.bat','monitor_'+name,'-runall'])]:
        cmd=[str(bin/args[0])]+list(map(str,args[1:]));log=folder/(name+'_'+step+'.log')
        with log.open('w') as f:q=subprocess.run(cmd,cwd=str(folder),env=env,stdout=f,stderr=subprocess.STDOUT)
        if q.returncode:print(log.read_text()[-2500:]);raise SystemExit('Monitor failed '+name+' '+step)
    text=(folder/(name+'_simulate.log')).read_text()
    if 'SUCCESS HEALTH MONITOR '+name not in text or 'Fatal:' in text:raise SystemExit(text[-3000:])
    print(text[-900:])
inputs=[ROOT/'rtl/entropy_health_monitor.sv',ROOT/'python/health_model.py',ROOT/'sim/prepare_health_vectors.py',ROOT/'sim/run_monitor.py']
(ROOT/'build/monitor_pass.json').write_text(json.dumps({'status':'PASS','configurations':['small','default'],'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}},indent=2)+'\n')
