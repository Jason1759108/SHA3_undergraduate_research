#!/usr/bin/env python
"""Read local VCS/SDF logs and print aggregate diagnostics only (Python 2/3).

Run inside 03_GATE after the SDF-enabled gate simulation. The script does not
read or copy the proprietary cell model and does not alter simulation inputs.
"""
from __future__ import print_function

import collections
import os
import re
import sys


def read_file(path):
    with open(path, 'rb') as stream:
        raw = stream.read()
    if sys.version_info[0] >= 3:
        return raw.decode('utf-8', 'replace')
    return raw


def main():
    sdf_path = sys.argv[1] if len(sys.argv) > 1 else 'sdf_annotation.log'
    vcs_path = sys.argv[2] if len(sys.argv) > 2 else 'vcs.log'
    for path in (sdf_path, vcs_path):
        if not os.path.isfile(path):
            print('[MISSING] %s' % path)
            return 2

    sdf = read_file(sdf_path)
    vcs = read_file(vcs_path)
    codes = collections.Counter(re.findall(r'Warning-\[([A-Z0-9_]+)\]', sdf))
    checks = collections.Counter(re.findall(
        r'SDF Warning: Cannot find timing check\s+\$(\w+)', sdf))
    total = re.search(r'Total warnings:\s*(\d+)', sdf)
    errors = re.search(r'Total errors:\s*(\d+)', sdf)
    tfipc = len(re.findall(r'Warning-\[TFIPC\]', vcs))
    timing = len(re.findall(r'Timing violation', vcs, re.I))
    success = bool(re.search(r'\[SUCCESS\] All 18 SHA3-256 test cases passed!', vcs))
    failure = bool(re.search(r'\[FAIL\]|\bFatal:', vcs))
    print('SDF completed: %s' % ('SDF annotation completed' in sdf))
    print('SDF reported errors: %s' % (errors.group(1) if errors else 'UNKNOWN'))
    print('SDF reported warnings: %s' % (total.group(1) if total else 'UNKNOWN'))
    print('SDF warning codes: %s' % (sorted(codes.items()),))
    print('Unmatched SDF check types: %s' % (sorted(checks.items()),))
    print('SDF warning count reconciled: %s' % (
        bool(total and sum(codes.values()) == int(total.group(1)))))
    print('VCS TFIPC warnings: %d' % tfipc)
    print('VCS timing violations: %d' % timing)
    print('All 18 functional cases passed: %s' % success)
    print('VCS failure marker present: %s' % failure)
    return 0


if __name__ == '__main__':
    sys.exit(main())
