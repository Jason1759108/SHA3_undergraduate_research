"""Run and conservatively qualify Timing checks in a separate Vivado process.

Never change synthesis, routing, user timing constraints, or rule severities.
The internal analysis option is accepted only after comparing all endpoint
records against an original-default reference on the same routed checkpoint.
"""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--kit', type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument('--vivado', default=str(Path(os.environ.get('XILINX_VIVADO', 'C:/AMDDesignTools/2026.1/Vivado')) / 'bin/vivado.bat'))
    p.add_argument('--resume', type=Path, help='Revalidate and collect an existing returned reference/candidate pair without rerunning Vivado')
    a = p.parse_args()
    build, kit = a.build.resolve(), a.kit.resolve()
    dcp = build / 'final_routed.dcp'
    checks_dir = build / 'reports/methodology_checks'
    inventory = set((checks_dir / 'requested_checks.txt').read_text().split())
    done = {row.split('\t')[0] for row in (checks_dir / 'progress.tsv').read_text().splitlines()
            if '\tDONE\t' in row}
    non_timing = {name for name in inventory if not name.startswith('TIMING-')}
    if len(inventory) != 234 or len(non_timing) != 177 or not non_timing <= done:
        raise ValueError('Run methodology_separate.tcl to complete the original non-Timing rules first')
    with dcp.open('rb') as f:
        digest = hashlib.file_digest(f, 'sha256').hexdigest()
    if a.resume:
        root = a.resume.resolve()
        root.relative_to((build / 'reports/methodology_runtime').resolve())
        if not root.is_dir():
            raise ValueError('Resume directory does not exist')
    else:
        root = build / 'reports/methodology_runtime' / datetime.now().strftime('%Y%m%d_%H%M%S_%f')
        root.mkdir(parents=True, exist_ok=False)
    state_path = root / 'state.json'
    state = dict(checkpoint=str(dcp), checkpoint_sha256=digest, complete=False, resumed=bool(a.resume))
    def stage(name):
        state['stage'] = name
        state_path.write_text(json.dumps(state, indent=2), encoding='utf-8')
        print(f'METHODOLOGY_PIPELINE {name}: {root}', flush=True)
    bed = kit / 'verification'
    helpers = bed / 'methodology_diagnostics'
    harness = bed / 'diagnose_methodology.py'
    common = [sys.executable, str(harness), '--vivado', a.vivado, '--checkpoint', str(dcp), '--analysis-timeout', '1800']
    try:
        if not a.resume:
            stage('original_default_reference')
            subprocess.run(common + ['--output', str(root / 'reference'), '--checks', 'LUTAR-1',
                           '--post-tcl', str(helpers / 'record_reference_paths.tcl')], check=True)
            stage('all_57_timing_rules')
            subprocess.run(common + ['--output', str(root / 'candidate'), '--checks', 'TIMING-*',
                           '--pre-open-tcl', str(helpers / 'uncertainty_preopen_diagnostic.tcl'),
                           '--post-tcl', str(helpers / 'record_full_paths.tcl')], check=True)
        stage('conservative_qualification')
        with (root / 'qualification.log').open('w', encoding='utf-8') as qualification_log:
            subprocess.run([sys.executable, str(bed / 'compare_methodology_timing.py'),
                            '--reference', str(root / 'reference'), '--candidate', str(root / 'candidate'),
                            '--save', str(root / 'conservative_validation.json')], check=True, stdout=qualification_log)
        stage('recording_completed_checks')
        subprocess.run([sys.executable, str(bed / 'finalize_methodology.py'), '--run', str(root / 'candidate'),
                        '--reference', str(root / 'reference'), '--build', str(build), '--kit', str(kit)], check=True)
        state['complete'] = True
        stage('complete_with_vendor_findings_retained')
    except BaseException:
        stage('failed_or_incomplete')
        raise


if __name__ == '__main__':
    main()
