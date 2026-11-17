"""Static handoff checks; does NOT execute or qualify VCS, DC, Vivado or hardware."""
import ast
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote


def main():
    root=Path(__file__).resolve().parents[1]
    expected=json.loads((root/'docs/SOURCE_MANIFEST.json').read_text())['rtl']
    for name,record in expected.items():
        content=(root/'rtl'/name).read_bytes()
        assert len(content)==record['bytes'] and hashlib.sha256(content).hexdigest()==record['sha256'],name
    manifests=0
    for path in (root/'sim').glob('*.f'):
        for line in path.read_text().splitlines():
            if line.strip():assert (path.parent/line.strip()).is_file(),(path,line)
        manifests+=1
    python_count=notebooks=0
    for folder in ['sim','verification','software','scripts']:
        for path in (root/folder).rglob('*.py'):
            if '__pycache__' in path.parts:continue
            source=path.read_text(encoding='utf-8')
            ast.parse(source,filename=str(path),**({'feature_version':(3,6)} if folder=='software' else {}))
            python_count+=1
        for path in (root/folder).rglob('*.ipynb'):
            nb=json.loads(path.read_text(encoding='utf-8'))
            for cell in nb['cells']:
                if cell['cell_type']=='code':
                    source=cell['source'];source=''.join(source) if isinstance(source,list) else source
                    ast.parse(source,filename=str(path),feature_version=(3,6))
            notebooks+=1
    # Historical documents intentionally retain original paths. Active docs must work.
    missing=[];links=0
    for path in root.rglob('*.md'):
        rel=path.relative_to(root)
        if any(part in {'history','build','sample_results','provenance','evidence'} for part in rel.parts) or path.name.endswith('.original.md'):continue
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)',path.read_text(encoding='utf-8')):
            target=target.strip('<>')
            if '://' in target or target.startswith('#'):continue
            target=unquote(target.split('#')[0])
            if not target:continue
            links+=1
            if not (path.parent/target).exists():missing.append((str(rel),target))
    assert not missing,missing
    assert (root/'scripts/vivado/board_files/pynq-z2').is_dir()
    assert len(expected)==10 and manifests==3
    result=dict(static_checks_passed=True,rtl_byte_identical=True,rtl_files=10,filelists=manifests,
                python_syntax_files=python_count,notebooks=notebooks,local_document_links=links,
                scope='Source/path/syntax checks only; no vendor synthesis, implementation, or board qualification.')
    output=root/'build/handoff';output.mkdir(parents=True,exist_ok=True)
    (output/'static_checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
