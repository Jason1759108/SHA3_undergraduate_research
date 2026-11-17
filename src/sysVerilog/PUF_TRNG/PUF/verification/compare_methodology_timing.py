"""Compare full routed endpoint records before accepting the analysis workaround."""
import argparse
from collections import Counter
import csv
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re

FIELDS = ('ENDPOINT_PIN', 'STARTPOINT_CLOCK', 'ENDPOINT_CLOCK', 'CORNER',
          'DELAY_TYPE', 'EXCEPTION', 'SLACK', 'REQUIREMENT', 'ARRIVAL_TIME',
          'REQUIRED_TIME', 'DATAPATH_DELAY', 'SKEW', 'CLOCK_PESSIMISM', 'UNCERTAINTY')
NUMERIC = set(FIELDS[6:])


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def canonical_xdc(path):
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'\\\r?\n[ \t]*', ' ', text)
    return '\n'.join(' '.join(line.split()) for line in text.splitlines()
                     if line.strip() and not line.lstrip().startswith('#'))


def snapshot(path):
    records = Counter()
    endpoints = set()
    uncertainty = Counter()
    pins = Counter()
    slack = []
    with path.open(encoding='utf-8', newline='') as f:
        reader = csv.DictReader(f, delimiter='\t')
        require(set(FIELDS) <= set(reader.fieldnames or []), 'Missing path columns')
        for row in reader:
            values = []
            for name in FIELDS:
                value = row[name]
                if name in NUMERIC:
                    if value == '' and name in ('SKEW', 'CLOCK_PESSIMISM', 'UNCERTAINTY'):
                        require('-datapath_only' in row['EXCEPTION'] or
                                (name == 'UNCERTAINTY' and row['DELAY_TYPE'] == 'min'),
                                'Missing clock timing value on a clocked path')
                        values.append(None)
                        continue
                    try:
                        value = Decimal(value)
                    except InvalidOperation as e:
                        raise ValueError(f'Non-numeric {name}: {value}') from e
                    require(value.is_finite(), 'Non-finite timing value')
                values.append(value)
            records[tuple(values)] += 1
            endpoints.add(row['ENDPOINT_PIN'])
            uncertainty[row['UNCERTAINTY']] += 1
            pins[row['ENDPOINT_PIN'].rsplit('/', 1)[-1]] += 1
            slack.append(Decimal(row['SLACK']))
    require(0 < len(slack) < 200000, 'Empty or truncated snapshot')
    return records, dict(rows=len(slack), unique_endpoints=len(endpoints),
                         min_slack_ns=float(min(slack)), uncertainty_counts=dict(uncertainty),
                         endpoint_pin_counts=dict(pins), sha256=sha256(path))


def compare(reference, candidate):
    reference, candidate = Path(reference), Path(candidate)
    original = json.loads((reference / 'result.json').read_text())
    revised = json.loads((candidate / 'result.json').read_text())
    for label, run in (('reference', original), ('candidate', revised)):
        require(run['verdict'] == 'RETURNED', f'{label} did not return')
        require(run['keep_ro'] == -1 and run['ready'] == 'clocks=1281 original=1281 keep_ro=-1',
                f'{label} has an incomplete clock model')
        require(not any(run.get(k) for k in ('group_ro', 'stop_feedback', 'explicit_input_jitter',
                                            'setup_tcl', 'restore_xdc')), f'{label} changed timing constraints')
        console = (Path(reference if label == 'reference' else candidate) / 'console.log').read_text(errors='replace')
        require('Exiting Vivado' in console and not re.search(r'^ERROR:', console, re.M), f'{label} tool error')
    require(not original.get('pre_open_tcl'), 'Reference has a parameter override')
    require('PUF_REFERENCE_ORIGINAL_DEFAULT clock_uncertainty=1' in (reference / 'console.log').read_text(),
            'Reference did not confirm original analysis default')
    require(revised['checks'] == 'TIMING-*', 'Candidate did not run all Timing checks')
    require(original['checkpoint_sha256'] == revised['checkpoint_sha256'], 'Checkpoint mismatch')
    require(canonical_xdc(reference / 'complete_timing.xdc') == canonical_xdc(candidate / 'complete_timing.xdc'),
            'User timing commands changed')
    require((reference / 'check_enablement.tsv').read_text() == (candidate / 'check_enablement.tsv').read_text(),
            'Rule enablement changed')
    enabled = dict(line.split('\t') for line in (candidate / 'check_enablement.tsv').read_text().splitlines())
    require(len(enabled) == 234 and all(value.lower() in ('1', 'true') for value in enabled.values()),
            'Not all 234 methodology rules are enabled')
    proof = dict(equivalent=True, conservative=True, source_checkpoint_sha256=original['checkpoint_sha256'],
                 user_timing_commands_identical=True, rule_enablement_identical=True, all_rules_enabled=True,
                 comparison='Max records identical; min endpoint records identical or stricter only at the RO divider clock-as-data feedback. No endpoint slack may increase.',
                 compared_fields=list(FIELDS), paths={})
    for delay_type in ('max', 'min'):
        old, old_stats = snapshot(reference / f'paths_{delay_type}.tsv')
        new, new_stats = snapshot(candidate / f'paths_{delay_type}.tsv')
        changed = []
        if old != new:
            require(delay_type == 'min', 'Setup/recovery timing changed')
            # Removing redundant uncertainty bookkeeping preserves setup values
            # but can retain an extra 35 ps on generated-clock-as-data hold paths.
            # This is accepted only when every affected worst endpoint is tighter.
            def endpoint_map(records):
                result = {}
                for row, count in records.items():
                    item = dict(zip(FIELDS, row))
                    key = (item['ENDPOINT_PIN'], item['ENDPOINT_CLOCK'], item['DELAY_TYPE'])
                    require(count == 1 and key not in result, 'Ambiguous endpoint comparison')
                    result[key] = item
                return result
            before, after = endpoint_map(old), endpoint_map(new)
            require(before.keys() == after.keys(), 'Hold endpoint coverage changed')
            for key, first in before.items():
                second = after[key]
                if first == second:
                    continue
                require(first['UNCERTAINTY'] in (None, Decimal(0)) and second['UNCERTAINTY'] == Decimal('0.035'),
                        'A changed hold budget is not the expected conservative addition')
                match = re.search(r'/g_counter\[(\d+)\]\.u_counter/divider_reg\[2\]/D$', first['ENDPOINT_PIN'])
                require(match is not None, 'Unexpected changed hold endpoint')
                index = match[1]
                require(first['ENDPOINT_CLOCK'] == second['ENDPOINT_CLOCK'] == f'ro_raw_{index}' and
                        second['STARTPOINT_CLOCK'] == f'ro_div_{index}', 'Unexpected changed clock relationship')
                for name in ('CORNER', 'EXCEPTION', 'REQUIREMENT'):
                    require(first[name] == second[name], f'Changed hold {name}')
                delta = first['SLACK'] - second['SLACK']
                require(Decimal(0) <= delta <= Decimal('0.036'), 'Hold slack became looser or changed unexpectedly')
                changed.append(dict(endpoint=first['ENDPOINT_PIN'], previous_slack_ns=str(first['SLACK']),
                                    revised_slack_ns=str(second['SLACK']), added_uncertainty_ns='0.035'))
            proof['equivalent'] = False
        proof['paths'][delay_type] = dict(reference=old_stats, candidate=new_stats, equal=old == new,
                                         stricter_budget_records=len(changed), weakened_endpoint_records=0)
        if changed:
            proof['changed_hold_records'] = changed
    from check_reports import inspect
    proof['routed_checks'] = inspect(candidate)
    require(proof['routed_checks']['passed'], 'Candidate routed checks failed')
    proof['total_records'] = sum(x['reference']['rows'] for x in proof['paths'].values())
    proof['reference_directory'] = str(reference.resolve())
    proof['candidate_directory'] = str(candidate.resolve())
    proof['input_sha256'] = {
        label: {name: sha256(directory / name) for name in
                ('result.json', 'complete_timing.xdc', 'check_enablement.tsv', 'paths_max.tsv', 'paths_min.tsv')}
        for label, directory in (('reference', reference), ('candidate', candidate))}
    return proof


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', type=Path, required=True)
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--save', type=Path)
    a = p.parse_args()
    proof = compare(a.reference, a.candidate)
    if a.save:
        a.save.write_text(json.dumps(proof, indent=2), encoding='utf-8')
    summary = {k: v for k, v in proof.items() if k != 'changed_hold_records'}
    summary['changed_hold_record_details'] = str(a.save) if a.save else 'Use --save to retain the detailed list'
    print(json.dumps(summary, indent=2))
