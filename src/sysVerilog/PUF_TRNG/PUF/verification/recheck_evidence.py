"""Recheck immutable historical measurements; never access the boards."""
import json
import gzip
import hashlib
import shutil
from pathlib import Path
import compare_boards as c
from verify_1000 import verify as verify_1000
from check_reports import inspect


def main():
    root=Path(__file__).resolve().parents[1]
    out=root/'build/evidence_check';out.mkdir(parents=True,exist_ok=True)
    original_reports=root/'docs/results/single_board/vivado'
    reports=out/'vivado';reports.mkdir(exist_ok=True)
    for source in original_reports.glob('*.rpt'):shutil.copy2(source,reports/source.name)
    for name,record in json.loads((original_reports/'COMPRESSED_REPORTS.json').read_text()).items():
        raw=gzip.decompress((original_reports/record['stored']).read_bytes())
        if len(raw)!=record['raw_bytes'] or hashlib.sha256(raw).hexdigest()!=record['raw_sha256']:
            raise ValueError('Compressed original report changed '+name)
        (reports/name).write_bytes(raw)
    routed=inspect(reports)
    if not routed['passed']:raise ValueError('Original routed report check changed')
    two=root/'docs/results/two_boards'
    a=two/'sample_results/baseline_20100/results_20261112_181403'
    b=two/'sample_results/baseline_20200/results_20261112_235911'
    frozen=out/'regenerated_frozen'
    c.freeze(a,b,frozen)
    for name in ['common_bitmap.json','reference_20100.json','reference_20200.json']:
        if (frozen/name).read_bytes()!=(two/'frozen'/name).read_bytes():
            raise ValueError('Historical training-only plan changed '+name)
    cross=c.compare(two/'sample_results/common_20100/common_20100_20261112_220713',
                    two/'sample_results/common_20200_characterized/characterized_20200_20261113_001833',
                    two/'frozen/common_bitmap.json',two/'frozen',allow_rejections=True)
    if cross['passed'] or cross['hamming_distance_bits']!=72 or cross['board_20200']['rejected_reconstructions']!=49:
        raise ValueError('Historical negative result was hidden/changed')
    strict=two/'sample_results/common_20200_strict/common_20200_20261113_000917/reconstructions.json'
    prefix=two/'sample_results/common_20200_characterized/characterized_20200_20261113_001833/strict_prefix_reconstructions.json'
    if strict.read_bytes()!=prefix.read_bytes():raise ValueError('Original strict failure prefix changed')
    thousand=root/'docs/results/rebuild_1000/sample_results'
    results={}
    for label,dirname in [('20100','rebuild1000_20100_20261112_225841'),('20200','rebuild1000_20200_20261113_005848')]:
        results[label]=verify_1000(thousand/label/dirname,kit=root)
        if not results[label]['passed']:raise ValueError('Historical own-bitmap 1000 run changed')
    verdict=dict(records_verified=True,original_routed_report_checks=routed,training_plan_byte_identical=True,strict_failure_prefix_byte_identical=True,
                 cross_board_identities_differ=cross['identities_differ'],cross_board_hamming_bits=72,
                 common_bitmap_all_passed=False,common_bitmap_20200_refusals=49,
                 own_bitmap_1000={label:{k:res[k] for k in ['attempts','successful_matching','hardware_rejections','accepted_mismatches','total_corrected_words']}
                                 for label,res in results.items()})
    (out/'verdict.json').write_text(json.dumps(verdict,indent=2,sort_keys=True),encoding='utf-8')
    print(json.dumps(verdict,indent=2,sort_keys=True))


if __name__=='__main__':main()
