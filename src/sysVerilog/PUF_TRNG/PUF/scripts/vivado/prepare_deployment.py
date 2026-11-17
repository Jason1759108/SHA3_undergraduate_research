"""Prepare the independent FPGA PUF256 upload set after routed checks pass."""
import argparse
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]


def prepare(build, deploy):
    spec = importlib.util.spec_from_file_location('check_reports', str(ROOT / 'verification/check_reports.py'))
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    verdict = checker.inspect(build / 'reports')
    if not verdict['passed']:
        raise RuntimeError('Routed timing/CDC/DRC checks failed; no deployment prepared')
    methodology=json.loads((build/'reports/methodology_status.json').read_text(encoding='utf-8'))
    digest=hashlib.sha256((build/'final_routed.dcp').read_bytes()).hexdigest()
    if (not methodology.get('complete') or methodology.get('completed')!=234
            or methodology.get('unexpected_findings') or methodology.get('source_checkpoint_sha256')!=digest):
        raise RuntimeError('Methodology incomplete, changed checkpoint, or unexpected findings; review before deployment')
    # Check the source snapshot actually imported by Vivado, not just this kit.
    packed = list((build / 'ip_repo').rglob('ro_measure.sv'))
    if len(packed) != 1:
        raise RuntimeError('Cannot locate the unique imported RTL source snapshot')
    imported = packed[0].parent
    source_hashes = {}
    for f in sorted((ROOT / 'rtl').glob('*.sv')):
        if f.read_bytes() != (imported / f.name).read_bytes():
            raise RuntimeError('Built source differs from kit: ' + f.name)
        source_hashes[f.name] = hashlib.sha256(f.read_bytes()).hexdigest()
    notebook_dir = ROOT / 'software'
    notebook_path = notebook_dir / 'notebooks/PUF256_Validation.ipynb'
    notebook = json.loads(notebook_path.read_text(encoding='utf-8'))
    for cell in notebook['cells']:
        if cell['cell_type'] == 'code':
            ast.parse(''.join(cell['source']), feature_version=(3, 6))
    ready = ROOT / 'build/board_upload'
    ready.mkdir(parents=True,exist_ok=True)
    required=[deploy/'puf256.bit',deploy/'puf256.hwh']
    required+=sorted((notebook_dir/'notebooks').glob('*.ipynb'))
    required+=list(notebook_dir.glob('*.py'))
    for source in required:
        if source.suffix=='.py':ast.parse(source.read_text(encoding='utf-8'),feature_version=(3,6))
        shutil.copy2(source, ready / source.name)
    files = {f.name: dict(bytes=f.stat().st_size, sha256=hashlib.sha256(f.read_bytes()).hexdigest())
             for f in sorted(ready/source.name for source in required)}
    manifest = dict(stage='puf256-v1', pairs=320, selected_pairs=256, puf_bits=256,helper_bits=80,
                    repeats=5,min_count_margin=8,ro_count=640,counter_bits=16,
                    counter_mode='saturating', max_window_cycles=100000, vivado='2026.1',
                    part='xc7z020clg400-1', build=str(build.resolve()),
                    files=files, rtl_sha256=source_hashes, routed_checks=verdict,
                    final_routed_sha256=hashlib.sha256((build / 'final_routed.dcp').read_bytes()).hexdigest(),
                    methodology=dict(mode='separate per-check analysis of final_routed.dcp',
                                     complete_at_prepare=True,findings=methodology['completed_findings'],
                                     all_rules_clean=methodology['all_rules_clean']),
                    board_verified_at_prepare=False,
                    notebook_hash_note='Hash is the unexecuted upload file; saved execution outputs change the server notebook hash')
    (ready / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    reports = ROOT / 'build/validation/vivado'
    reports.mkdir(parents=True, exist_ok=True)
    for f in (build / 'reports').glob('*.rpt'):
        shutil.copy2(f, reports / f.name)
    (reports / 'verdict.json').write_text(json.dumps(verdict, indent=2), encoding='utf-8')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--deploy', type=Path, required=True)
    a = p.parse_args()
    prepare(a.build, a.deploy)
