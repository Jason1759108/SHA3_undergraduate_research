#!/usr/bin/env python
"""Aggregate SDF/model timing-check probe; Python 2.7/3, local files only.

Usage: python probe_sdf_model.py sdf_annotation.log path/to/cell_model.v
The program prints no cell names, SDF contents, model text, or file paths.
It does not modify any files or run synthesis/simulation.
"""
from __future__ import print_function

import collections
import re
import sys


def read(path):
    with open(path, 'rb') as source:
        data = source.read()
    if sys.version_info[0] >= 3:
        return data.decode('utf-8', 'replace')
    return data


def classify_endpoint(block):
    check = re.search(r'SDF Warning: Cannot find timing check\s+\$hold\(', block)
    if not check:
        return 'unparsed'
    tail = block[check.end():]
    match = re.search(r',\s*(?:posedge|negedge)\s+([A-Za-z_][A-Za-z_0-9]*)', tail)
    if not match:
        return 'unparsed'
    pin = match.group(1).upper()
    if pin in ('R', 'RN', 'RST', 'RESET', 'RESETN', 'RESET_N',
               'S', 'SN', 'SET', 'SETN', 'SET_N', 'CLR', 'CLRN'):
        return 'reset_or_set_pin'
    if pin in ('D', 'DI', 'DATA'):
        return 'data_pin'
    return 'other_pin'


def model_module(model, name):
    pattern = r'(?ms)^\s*module\s+' + re.escape(name) + r'\b.*?^\s*endmodule\b'
    match = re.search(pattern, model)
    return match.group(0) if match else None


def has_async_event(body, check):
    # Only inspect event-pin spelling in this local model. This is a clue,
    # not a full parser for specify conditions or SDF matching rules.
    async_pins = r'(?:R|RN|RST|RESET|RESETN|RESET_N|S|SN|SET|SETN|SET_N|CLR|CLRN)'
    for found in re.finditer(r'\$' + check + r'\s*\((.*?);', body, re.S):
        if re.search(r'\b(?:posedge|negedge)\s+' + async_pins + r'\b', found.group(1)):
            return True
    return False


def main():
    if len(sys.argv) != 3:
        print('Usage: python probe_sdf_model.py sdf_annotation.log cell_model.v')
        return 2
    try:
        sdf = read(sys.argv[1])
        model = read(sys.argv[2])
    except IOError as error:
        print('[ERROR] Cannot read an input file: %s' % error.__class__.__name__)
        return 2

    blocks = sdf.split('Warning-[SDFCOM_CFTC]')[1:]
    endpoints = collections.Counter()
    kinds = collections.Counter()
    names = set()
    parsed = 0
    for block in blocks:
        if not re.search(r'Cannot find timing check\s+\$hold', block):
            kinds['not_hold_or_unparsed'] += 1
            continue
        kinds['hold'] += 1
        endpoints[classify_endpoint(block)] += 1
        found = re.search(r'\bmodule:\s*([A-Za-z_][A-Za-z_0-9]*)', block)
        if found:
            names.add(found.group(1))
            parsed += 1

    model_types = collections.Counter()
    for name in names:
        body = model_module(model, name)
        if body is None:
            model_types['module_missing'] += 1
            continue
        model_types['module_found'] += 1
        for check in ('hold', 'setuphold', 'recovery', 'removal', 'recrem'):
            if re.search(r'\$' + check + r'\s*\(', body):
                model_types['module_has_' + check] += 1
                if has_async_event(body, check):
                    model_types['module_has_' + check + '_async_event'] += 1

    print('SDFCOM_CFTC warnings found: %d' % len(blocks))
    print('Warning kinds: %s' % sorted(kinds.items()))
    print('Unmatched $hold second event: %s' % sorted(endpoints.items()))
    print('Warning blocks with a parsed module type: %d' % parsed)
    print('Unique warned model module types: %d' % len(names))
    print('Model timing-check presence by module type: %s' % sorted(model_types.items()))
    print('Interpretation: presence counts show whether named modules contain timing-check syntax;')
    print('they do not prove that condition expressions match or that all checks are covered.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
