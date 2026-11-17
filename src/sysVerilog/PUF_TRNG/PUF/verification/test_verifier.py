"""Synthetic verifier fixtures only; these do not run or represent FPGA measurements."""
import copy
import hashlib
import json
from pathlib import Path
import unittest
from datetime import datetime
import verify_1000 as v


def write(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(obj,indent=2,sort_keys=True),encoding='utf-8')


class VerifierTests(unittest.TestCase):
    def setUp(self):
        self.kit=Path(__file__).resolve().parents[1]
        self.folder=self.kit/'build/verifier_fixtures'/('SYNTHETIC_1000_'+datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
        self.folder.mkdir(parents=True,exist_ok=False)
        original=self.kit/'docs/results/rebuild_1000/inputs/20100/own_enrollment_20100.json'
        self.frozen=v.read(original);self.enrol=self.frozen['enrollment']
        (self.folder/'frozen_input.json').write_bytes(original.read_bytes())
        self.expected=int(v.read(self.kit/'docs/results/rebuild_1000/provenance/20100/selection.json')['reference_candidate_hex'],16)
        write(self.folder/'environment.json',dict(board_label='20100',requested_attempts=1000,input_sha256=v.sha(original),
              module_sha256=v.sha(self.kit/'docs/results/rebuild_1000/evidence/rebuild_1000.py'),driver_sha256=self.frozen['driver_sha256'],
              bitstream_sha256=self.enrol['bitstream_sha256'],hwh_sha256=self.enrol['hwh_sha256'],linux_boot_id='SYNTHETIC'))
        write(self.folder/'initial_state.json',dict(fclk0_mhz=100.0,volatile_registers=dict.fromkeys(
            ['bitmap','helper_input','key_data','helper_output','puf_sequence','raw_sequence','helper_input_valid'],0)))
        self.rows=[dict(attempt=i,sequence=i,command=1,status=0,status_name='PUF_OK',error=0,key_hex=format(self.expected,'064x'),
                       key_sha256=self.frozen['expected_key_sha256'],matches_enrollment=True,corrected_words=0,
                       diagnostic_pair=None,duration_seconds=1.0,elapsed_seconds=2.0*i,
                       bitmap_readback_hex=self.enrol['bitmap_hex'],helper_readback_hex=self.enrol['helper_hex']) for i in range(1,1001)]

    def emit(self):
        from collections import Counter
        (self.folder/'attempts.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in self.rows),encoding='utf-8')
        matching=sum(r['status']==0 and r['matches_enrollment'] for r in self.rows)
        original=self.kit/'docs/results/rebuild_1000/inputs/20100/own_enrollment_20100.json'
        write(self.folder/'summary.json',dict(board_label='20100',requested_attempts=1000,completed_attempts=len(self.rows),completed=True,
              successful_matching=matching,hardware_rejections=sum(r['status']!=0 for r in self.rows),
              accepted_mismatches=sum(r['status']==0 and not r['matches_enrollment'] for r in self.rows),
              status_counts=dict(Counter(str(r['status']) for r in self.rows)),
              corrected_word_distribution=dict(Counter(str(r['corrected_words']) for r in self.rows if r['status']==0)),
              total_corrected_words=sum(r['corrected_words'] for r in self.rows),bitmap_hex=self.enrol['bitmap_hex'],
              helper_hex=self.enrol['helper_hex'],expected_key_sha256=self.frozen['expected_key_sha256'],input_sha256=v.sha(original),
              attempts_sha256=v.sha(self.folder/'attempts.jsonl'),files_unchanged=True,fclk0_end_mhz=100.0,
              elapsed_seconds=2001.0,passed=matching==1000))

    def test_exact_1000(self):
        self.emit();result=v.verify(self.folder)
        self.assertTrue(result['records_verified']);self.assertTrue(result['passed'])

    def test_linux_serialized_input_preserves_source_hash_binding(self):
        (self.folder/'frozen_input.json').write_bytes(json.dumps(self.frozen,indent=2,sort_keys=True).encode('utf-8'))
        self.emit();self.assertTrue(v.verify(self.folder)['records_verified'])

    def test_weak_rejection_remains_failure(self):
        pair=next(p for p in range(320) if int(self.enrol['bitmap_hex'],16)>>p&1)
        self.rows[500].update(status=4,status_name='PUF_WEAK_PAIR',error=1,key_hex=None,key_sha256=None,
                              matches_enrollment=False,diagnostic_pair=pair)
        self.emit();result=v.verify(self.folder)
        self.assertTrue(result['records_verified']);self.assertFalse(result['passed'])
        self.assertEqual(result['successful_matching'],999);self.assertEqual(result['hardware_rejections'],1)

    def test_accepted_changed_identity_remains_failure(self):
        changed=self.expected^1
        self.rows[500].update(key_hex=format(changed,'064x'),key_sha256=hashlib.sha256(changed.to_bytes(32,'little')).hexdigest(),matches_enrollment=False)
        self.emit();result=v.verify(self.folder)
        self.assertFalse(result['passed']);self.assertEqual(result['accepted_mismatches'],1)

    def test_duplicate_hardware_sequence_rejected(self):
        self.rows[500]['sequence']=500;self.emit()
        with self.assertRaises(ValueError):v.verify(self.folder)

    def test_changed_helper_rejected(self):
        self.rows[500]['helper_readback_hex']='0'*20;self.emit()
        with self.assertRaises(ValueError):v.verify(self.folder)

    def test_missing_attempt_rejected(self):
        self.rows.pop();self.emit()
        with self.assertRaises(ValueError):v.verify(self.folder)


if __name__=='__main__':unittest.main()
