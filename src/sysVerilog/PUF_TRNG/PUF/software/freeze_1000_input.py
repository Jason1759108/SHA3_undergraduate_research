"""Bind a NEW own-board baseline to the 1000-attempt runner; no measurement here."""
import argparse
import hashlib
import json
from pathlib import Path
from board_validation import sha256


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--board',choices=['20100','20200'],required=True,help='Laboratory role label, not a chip identity')
    p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    load=lambda name:json.loads((a.baseline/name).read_text(encoding='utf-8'))
    if not load('summary.json')['passed']:raise RuntimeError('Baseline validation did not pass')
    selection=load('selection.json');enrollment=load('enrollment.json');trials=load('reconstructions.json')
    candidate=int(selection['reference_candidate_hex'],16)
    digest=hashlib.sha256(candidate.to_bytes(32,'little')).hexdigest()
    if not selection['complete'] or any(r['status'] or not r['match'] or r['key_sha256']!=digest for r in trials):
        raise RuntimeError('Baseline hardware output differs from selected reference')
    value=dict(format='puf256-own-enrollment-1000-v1',board_label=a.board,enrollment=enrollment,
               expected_key_sha256=digest,driver_sha256=sha256(Path(__file__).with_name('puf256.py')),
               source_baseline=a.baseline.name,source_sha256={n:sha256(a.baseline/n) for n in
                   ['enrollment.json','reconstructions.json','selection.json','environment.json']})
    a.out.parent.mkdir(parents=True,exist_ok=True)
    with a.out.open('x',encoding='utf-8') as stream:json.dump(value,stream,indent=2,sort_keys=True)
    print(a.out)


if __name__=='__main__':main()
