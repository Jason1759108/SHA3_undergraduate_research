"""Fail closed on the actual routed 320-pair Vivado reports."""
import argparse
import json
from pathlib import Path
import re


def inspect(folder):
    timing = (folder / 'timing_summary.rpt').read_text(encoding='utf-8')
    cdc = (folder / 'cdc.rpt').read_text(encoding='utf-8')
    drc = (folder / 'drc.rpt').read_text(encoding='utf-8')
    skew = (folder / 'bus_skew.rpt').read_text(encoding='utf-8')
    table = timing.split('| Design Timing Summary', 1)[1]
    match = re.search(r'WNS\(ns\)[^\n]*\n[^\n]*\n\s*([-0-9.]+)\s+([-0-9.]+)\s+(\d+)\s+(\d+)\s+([-0-9.]+)\s+([-0-9.]+)\s+(\d+)\s+(\d+)\s+([-0-9.]+)\s+([-0-9.]+)\s+(\d+)\s+(\d+)', table)
    if not match:
        raise ValueError('Cannot parse routed timing summary')
    v = list(map(float, match.groups()))
    buses = re.findall(r'^\s+(?:Slow|Fast)\s+([0-9.]+)\s+([0-9.]+)\s+([-0-9.]+)\s*$', skew, re.M)
    no_clock = re.search(r'checking no_clock \(0\)', timing) is not None
    unconstrained = re.search(r'checking unconstrained_internal_endpoints \(0\)', timing) is not None
    result = dict(wns_ns=v[0], setup_failing=int(v[2]), whs_ns=v[4], hold_failing=int(v[6]),
                  wpws_ns=v[8], pulse_failing=int(v[10]), gray_buses=len(buses),
                  max_bus_skew_ns=max(float(b[1]) for b in buses) if buses else None,
                  min_bus_skew_slack_ns=min(float(b[2]) for b in buses) if buses else None,
                  no_missing_clock=no_clock, no_unconstrained_internal_endpoints=unconstrained,
                  critical_cdc=bool(re.search(r'CDC-\d+\s+(?:Critical|Error)', cdc)),
                  severe_drc=bool(re.search(r'^\S+\s+(?:Error|Critical Warning)\s', drc, re.M)),
                  expected_gray_cdc=bool(re.search(r'^CDC-6\s+Warning\s+640\s', cdc, re.M)),
                  expected_reset_cdc=bool(re.search(r'^CDC-9\s+Info\s+1280\s', cdc, re.M)))
    result['passed'] = (all(v[i] >= 0 for i in [0, 4, 8]) and all(v[i] == 0 for i in [2, 6, 10])
                        and len(buses) == 640 and all(float(b[0]) == 8 and float(b[2]) >= 0 for b in buses)
                        and not re.search(r'\sNA\s|Slack\s+\(VIOLATED\)', skew)
                        and no_clock and unconstrained and not result['critical_cdc']
                        and not result['severe_drc'] and result['expected_gray_cdc'] and result['expected_reset_cdc'])
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reports', type=Path)
    p.add_argument('--save', type=Path)
    args = p.parse_args()
    verdict = inspect(args.reports)
    text = json.dumps(verdict, indent=2)
    print(text)
    if args.save:
        args.save.parent.mkdir(parents=True, exist_ok=True)
        args.save.write_text(text, encoding='utf-8')
    raise SystemExit(0 if verdict['passed'] else 1)
