"""Import a returned full Timing run, without promoting diagnostic variants.

The 177 earlier reports and 57 Timing rules must refer to the same immutable
checkpoint. Completion is distinct from a clean report: findings keep their
original vendor severities.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil

if not __debug__:
    raise RuntimeError('Run qualification without Python -O; validation guards are required')


def sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def findings(text):
    return [dict(rule=m[1].strip(), severity=m[2].strip(),
                 description=m[3].strip(), count=int(m[4]))
            for m in re.finditer(
                r'^\|\s*([A-Z][A-Z0-9_-]*-\d+)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*(\d+)\s*\|',
                text, re.M)]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run', required=True, type=Path)
    p.add_argument('--build', required=True, type=Path)
    p.add_argument('--kit', type=Path, default=Path(__file__).resolve().parent.parent)
    p.add_argument('--reference', type=Path, help='Original-default endpoint records for a conservatively qualified workaround')
    a = p.parse_args()
    run = a.run.resolve()
    build = a.build.resolve()
    result = json.loads((run / 'result.json').read_text(encoding='utf-8'))
    proof = None
    if a.reference:
        from compare_methodology_timing import compare
        proof = compare(a.reference, run)
        if not proof['conservative']:
            raise ValueError('Analysis workaround is not conservative')
    assert result['verdict'] == 'RETURNED', 'The vendor call has not returned'
    assert result['checks'] == 'TIMING-*'
    assert result['keep_ro'] == -1
    for flag in ('group_ro', 'stop_feedback', 'explicit_input_jitter'):
        assert result.get(flag) is False, f'Diagnostic constraint change: {flag}'
    assert not result.get('setup_tcl'), 'Diagnostic setup is not qualified'
    assert proof is not None or not result.get('pre_open_tcl'), 'Alternative analysis needs conservative qualification'
    assert not result.get('restore_xdc'), 'Alternative loading needs separate equivalence qualification'
    assert result['ready'] == 'clocks=1281 original=1281 keep_ro=-1'
    dcp = build / 'final_routed.dcp'
    assert Path(result['checkpoint']).resolve() == dcp
    digest = sha256(dcp)
    assert result['checkpoint_sha256'] == digest
    sample = a.kit.resolve() / 'build/validation/vivado'
    old_status_path = sample / 'methodology_status.json'
    old_status = json.loads(old_status_path.read_text(encoding='utf-8')) if old_status_path.exists() else {}
    directory = build / 'reports/methodology_checks'
    identity_path = directory / 'checkpoint_identity.tsv'
    if identity_path.exists():
        identity = dict(line.split('\t', 1) for line in identity_path.read_text().splitlines())
        assert Path(identity['path']).resolve() == dcp
        assert int(identity['bytes']) == dcp.stat().st_size and int(identity['mtime']) == int(dcp.stat().st_mtime)
    else:
        assert old_status.get('source_checkpoint_sha256') == digest, 'Legacy report provenance mismatch'
    matching_board_evidence = old_status.get('source_checkpoint_sha256') == digest
    requested = set((directory / 'requested_checks.txt').read_text().split())
    timing = {f'TIMING-{i}' for i in range(1, 58)}
    assert len(requested) == 234 and requested & timing == timing
    assert set((run / 'requested_checks.txt').read_text().split()) == timing
    progress_path = directory / 'progress.tsv'
    progress = progress_path.read_text()
    completed = {line.split('\t')[0] for line in progress.splitlines()
                 if len(line.split('\t')) >= 2 and line.split('\t')[1] == 'DONE'}
    assert requested - timing <= completed, 'Earlier checks are incomplete'
    for check in requested - timing:
        text = (directory / f'{check}.rpt').read_text(encoding='utf-8')
        assert 'Report Methodology' in text and f'Checks: {check}' in text
    report = (run / 'report.rpt').read_text(encoding='utf-8')
    console = (run / 'console.log').read_text(encoding='utf-8', errors='replace')
    assert 'PUF_PROBE_DONE elapsed_ms=' in console
    assert 'Exiting Vivado' in console and not re.search(r'^ERROR:', console, re.M)
    assert 'Report Methodology' in report and '<entire design considered>' in report
    header = re.search(r'^\s*Checks:\s*(.*?)\n\s*Max checks:', report, re.M | re.S)
    assert header and set(header[1].split()) == timing, 'Report rule coverage mismatch'
    shutil.copy2(run / 'report.rpt', directory / 'TIMING_ALL.rpt')
    now = datetime.now(timezone.utc).isoformat()
    done_lines = ''.join(f'{check}\tDONE\t{result["analysis_elapsed_s"]:.3f}\t{now}\n' for check in sorted(timing))
    reports = [directory / f'{check}.rpt' for check in sorted(requested - timing)]
    reports.append(directory / 'TIMING_ALL.rpt')
    combined = '\n'.join(f'===== {path.name} =====\n{path.read_text(encoding="utf-8")}'
                         for path in reports)
    (build / 'reports/methodology.rpt').write_text(combined, encoding='utf-8')
    all_findings = findings(combined)
    expected = {
        'TIMING-2': ('Critical Warning', 640),
        'TIMING-4': ('Critical Warning', 640),
        'TIMING-14': ('Critical Warning', 640),
        'TIMING-23': ('Warning', 640),
        'LUTAR-1': ('Warning', 1),
        'ULMTCS-2': ('Warning', 1),
        'XDCB-1': ('Warning', 1),
    }
    unexpected = [f for f in all_findings
                  if expected.get(f['rule']) != (f['severity'], f['count'])]
    status = dict(complete=True, requested=234, completed=234, pending=[],
                  completed_findings=all_findings, unexpected_findings=unexpected,
                  all_rules_clean=not all_findings, running=False,
                  state='complete_with_findings' if all_findings else 'complete_clean',
                  source_checkpoint_sha256=digest, timing_analysis_seconds=result['analysis_elapsed_s'],
                  completed_utc=now, source_constraints_changed=False,
                  board_measurements_verified=bool(matching_board_evidence and old_status.get('board_measurements_verified')),
                  board_rows=old_status.get('board_rows', 0) if matching_board_evidence else 0,
                  note='All 234 rules completed. Findings retain vendor severities; completion is not a zero-warning PASS.')
    if proof is not None:
        status['analysis_workaround'] = dict(parameter='sta.enableClockUncertainty', value=False,
            scope='Read-only methodology on this immutable routed checkpoint; set before open_checkpoint',
            validation='Original user timing commands and rule enablement identical; max paths identical; min endpoints equal or stricter',
            path_records=proof['total_records'], stricter_hold_budget_records=proof['paths']['min']['stricter_budget_records'],
            weakened_endpoint_records=0, equivalent=proof['equivalent'], conservative=True,
            vendor_internal_parameter=True)
        timing_duration = re.search(r'report_methodology: Time \(s\): cpu = [0-9:]+ ; elapsed = (\d+):(\d+):(\d+)', console)
        assert timing_duration, 'Missing native methodology duration'
        hours, minutes, seconds = map(int, timing_duration.groups())
        status['timing_methodology_native_elapsed_seconds'] = hours * 3600 + minutes * 60 + seconds
        status['timing_run_with_validation_seconds'] = status['timing_analysis_seconds']
        status['timing_analysis_seconds'] = status['timing_methodology_native_elapsed_seconds']
    (sample / 'methodology_checks').mkdir(parents=True, exist_ok=True)
    for path in directory.iterdir():
        if path.is_file():
            shutil.copy2(path, sample / 'methodology_checks' / path.name)
    shutil.copy2(build / 'reports/methodology.rpt', sample / 'methodology.rpt')
    evidence = sample / 'methodology_runtime'
    evidence.mkdir(exist_ok=True)
    for name in ('result.json', 'console.log', 'requested_checks.txt'):
        shutil.copy2(run / name, evidence / name)
    if proof is not None:
        (evidence / 'conservative_validation.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
        for label, source in (('reference', a.reference.resolve()), ('candidate', run)):
            target = evidence / label
            target.mkdir(exist_ok=True)
            for name in ('result.json', 'console.log', 'requested_checks.txt', 'complete_timing.xdc',
                         'check_enablement.tsv', 'paths_max.tsv', 'paths_min.tsv', 'timing_summary.rpt', 'clocks.rpt'):
                shutil.copy2(source / name, target / name)
        for name in ('cdc.rpt', 'bus_skew.rpt', 'drc.rpt'):
            shutil.copy2(run / name, evidence / 'candidate' / name)
        (evidence / 'candidate/verdict.json').write_text(json.dumps(proof['routed_checks'], indent=2), encoding='utf-8')
    # Publish completion only after every required report/evidence copy succeeds.
    with progress_path.open('a', encoding='utf-8') as f:
        f.write(done_lines)
    shutil.copy2(progress_path, sample / 'methodology_checks/progress.tsv')
    (sample / 'methodology_status.json').write_text(json.dumps(status, indent=2), encoding='utf-8')
    (build / 'reports/methodology_status.json').write_text(json.dumps(status, indent=2), encoding='utf-8')
    complete = directory / 'COMPLETE.txt'
    complete.write_text(f'Completed all 234 checks on {dcp}\nSHA256 {digest}\n', encoding='utf-8')
    shutil.copy2(complete, sample / 'methodology_checks/COMPLETE.txt')
    print(json.dumps(status, indent=2))


if __name__ == '__main__':
    main()
