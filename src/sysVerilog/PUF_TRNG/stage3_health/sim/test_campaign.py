import ast
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'python'))
from entropy_campaign import collect_campaign, export_datasets
from test_characterization import FakeSession


class CampaignChecks(unittest.TestCase):
    def test_notebook_functional_capture_campaign_and_zip(self):
        from entropy_health_pynq import save_capture, HealthFailure
        nb=json.loads((ROOT/'python/Entropy_Health_Bringup.ipynb').read_text(encoding='utf-8'))
        cells=[''.join(c['source']) for c in nb['cells'] if c['cell_type']=='code']
        for source in cells:ast.parse(source,feature_version=(3,6))
        previous=Path.cwd()
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            try:
                os.chdir(tmp)
                session=FakeSession()
                scope={'session':session,'board_id':'fixture','experiment_date':'2026-11-11',
                       'Path':Path,'json':json,'zipfile':zipfile,'save_capture':save_capture,
                       'HealthFailure':HealthFailure,'collect_campaign':collect_campaign,
                       'export_datasets':export_datasets}
                for source in cells[3:]:exec(compile(source,'health_notebook','exec'),scope)
                self.assertEqual(len(session.calls),1016)
                self.assertTrue(scope['functional_ok'])
                self.assertEqual(scope['dataset']['total_samples'],1024000)
                with zipfile.ZipFile(str(scope['zip_path'])) as z:
                    self.assertIsNone(z.testzip())
                    self.assertEqual(sum(n.startswith('health_functional/') and n.endswith('.bin') for n in z.namelist()),16)
                    self.assertTrue(any(n.endswith('datasets/dataset_manifest.json') for n in z.namelist()))
            finally:os.chdir(str(previous))
    def test_1000_batches_and_export(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            s=FakeSession();r=collect_campaign(s,'fixture','2026-11-11',tmp)
            data=export_datasets(r['folder']);self.assertEqual(data['total_samples'],1024000)
            folder=Path(r['folder'])/'datasets'
            raw=(folder/'raw_joint_concat.bin').read_bytes();rows=(folder/'restart_joint_rows.bin').read_bytes()
            self.assertEqual(len(rows),1000000)
            for i in [0,15,16,991,999]:self.assertEqual(rows[i*1000:(i+1)*1000],raw[i*1024:i*1024+1000])
            for ch in range(8):self.assertEqual((folder/('channel_{}_concat.bin'.format(ch))).read_bytes(),bytes((b>>ch)&1 for b in raw))
            self.assertEqual(len(s.calls),1000);self.assertTrue(r['ro_off_confirmed'])
    def test_fault_stops_and_preserves(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            s = FakeSession(fault_at=18)
            r = collect_campaign(s, 'fixture', '2026-11-11', tmp, target_batches=33)
            self.assertEqual(len(s.calls), 18)
            self.assertEqual(r['status'], 'stopped_on_fault')
            self.assertTrue(r['ro_off_confirmed'])
            self.assertEqual(len(list(Path(r['folder']).rglob('capture_*.bin'))), 18)
            with self.assertRaises(ValueError):
                export_datasets(r['folder'])

    def test_interrupt_keeps_unindexed_segment(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            s = FakeSession(interrupt_at=18)
            with self.assertRaises(KeyboardInterrupt):
                collect_campaign(s, 'fixture', '2026-11-11', tmp, target_batches=33)
            m = json.loads(next(Path(tmp).rglob('campaign_manifest.json')).read_text())
            self.assertEqual(m['status'], 'interrupted')
            self.assertTrue(m['ro_off_confirmed'])
            self.assertEqual(len(list(Path(tmp).rglob('capture_*.bin'))), 17)

    def test_tamper_rejected_and_partial_final_segment(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            r = collect_campaign(FakeSession(), 'fixture', '2026-11-11', tmp, target_batches=17)
            self.assertEqual(export_datasets(r['folder'])['total_samples'], 17408)
            p = next(Path(r['folder']).rglob('capture_*.bin'))
            raw = p.read_bytes()
            p.write_bytes(bytes([raw[0] ^ 1]) + raw[1:])
            with self.assertRaises(ValueError):
                export_datasets(r['folder'])

    def test_cleanup_failure_and_bounds(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            r = collect_campaign(FakeSession(close_error=True), 'fixture', '2026-11-11', tmp, target_batches=17)
            self.assertEqual(r['status'], 'stopped_on_fault')
            self.assertFalse(r['ro_off_confirmed'])
            with self.assertRaises(ValueError):
                export_datasets(r['folder'])
            s = FakeSession()
            with self.assertRaises(ValueError):
                collect_campaign(s, 'fixture', '2026-11-11', tmp, target_batches=1001)
            self.assertEqual(s.calls, [])


if __name__ == '__main__':
    unittest.main()
