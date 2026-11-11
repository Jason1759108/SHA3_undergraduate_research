import os,subprocess,json,re
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
REF=ROOT/'references'
BIN=Path('C:/msys64/mingw64/bin')
os.environ['PATH']=str(BIN)+os.pathsep+os.environ['PATH']
inc=HERE/'include';inc.mkdir(exist_ok=True)
log=[]
def run(args):
    args=list(map(str,args));log.append(args)
    (HERE/'build_commands.json').write_text(json.dumps(log,indent=2))
    p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    with (HERE/'build.log').open('a',encoding='utf-8') as f:f.write(p.stdout)
    if p.returncode:print(p.stdout[-10000:]);raise SystemExit(p.returncode)
source=REF/'libdivsufsort'
config='#define PROJECT_VERSION_FULL "2.0.2"\n#define HAVE_INTTYPES_H 1\n#define HAVE_STDDEF_H 1\n#define HAVE_STDINT_H 1\n#define HAVE_STDLIB_H 1\n#define HAVE_STRING_H 1\n#define HAVE_STRINGS_H 1\n#define HAVE_MEMORY_H 1\n#define HAVE_SYS_TYPES_H 1\n#define INLINE inline\n'
(inc/'config.h').write_text(config)
template=(source/'include/divsufsort.h.cmake').read_text()
for bits in [32,64]:
    values={'W64BIT':'' if bits==32 else '64','INCFILE':'#include <stdint.h>\n#include <inttypes.h>','DIVSUFSORT_EXPORT':'','DIVSUFSORT_IMPORT':'','SAUCHAR_TYPE':'uint8_t','SAINT32_TYPE':'int32_t','SAINDEX_TYPE':'int32_t' if bits==32 else 'int64_t','SAINT_PRId':'PRId32','SAINDEX_PRId':'PRId32' if bits==32 else 'PRId64'}
    header=template
    for a,b in values.items():header=header.replace('@'+a+'@',b)
    assert not re.search(r'@[A-Z0-9_]+@',header)
    (inc/('divsufsort'+('64' if bits==64 else '')+'.h')).write_text(header)
objects=[]
for bits in [32,64]:
    for name in ['divsufsort','sssort','trsort','utils']:
        obj=HERE/('div'+str(bits)+'_'+name+'.o');objects.append(obj)
        run([BIN/'gcc.exe','-O2','-DHAVE_CONFIG_H=1']+(['-DBUILD_DIVSUFSORT64'] if bits==64 else [])+['-I'+str(inc),'-I'+str(source/'include'),'-c',source/('lib/'+name+'.c'),'-o',obj])
jsonsrc=REF/'jsoncpp'
for name in ['json_reader','json_value','json_writer']:
    obj=HERE/(name+'.o');objects.append(obj)
    run([BIN/'g++.exe','-O2','-std=c++17','-I'+str(jsonsrc/'include'),'-c',jsonsrc/('src/lib_json/'+name+'.cpp'),'-o',obj])
for program in ['non_iid','restart']:
    run([BIN/'g++.exe','-std=c++11','-fopenmp','-O2','-ffloat-store','-I'+str(inc),'-I'+str(jsonsrc/'include'),REF/('SP800-90B_EntropyAssessment/cpp/'+program+'_main.cpp'),*objects,'-lbz2','-lcrypto','-lpthread','-o',HERE/('ea_'+program+'.exe')])
print('Native build complete')
