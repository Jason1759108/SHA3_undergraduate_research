import json,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/"python"))
from entropy_characterize import collect
from review_characterization import review,features,correlation
class FakeSession:
    def __init__(self,fault_at=None,interrupt_at=None,close_error=False):
        self.release={"build_id":"test-fixture-only"};self.mmio=self;self.calls=[];self.closed=False;self.fault_at=fault_at;self.interrupt_at=interrupt_at;self.close_error=close_error
    def read(self,offset):return {0x14:0x524f4832,0x0c:1024,0x20:0}[offset]
    def capture(self,divider):
        self.calls.append(divider)
        if len(self.calls)==self.interrupt_at:raise KeyboardInterrupt()
        fault=len(self.calls)==self.fault_at;size=128 if fault else 1024
        return {"health":{"status":194,"count":1024,"ro_enable":0,"fault_mask":0,"rct_mask":0,"apt_mask":0,"observed":2048,"startup_seen":1024},"raw":bytes((i*29+len(self.calls))%256 for i in range(size)),"count":size,"status":6 if fault else 194,"alarm":fault,"fault_mask":255 if fault else 0,"divider":divider,"clock_mhz":25,"build_id":self.release["build_id"]}
    def close(self):
        self.closed=True
        if self.close_error:raise RuntimeError("mock close failure")
class Checks(unittest.TestCase):
    def test_normal_32_and_integrity(self):
        with tempfile.TemporaryDirectory()as tmp:
            s=FakeSession();a=collect(s,"fixture","2026-11-10",tmp);self.assertEqual(a["status"],"complete");self.assertEqual(a["batches"],32);self.assertTrue(s.closed)
            self.assertEqual({d:s.calls.count(d)for d in [64,128,256,512]},{64:8,128:8,256:8,512:8})
            data=review(a["folder"]);self.assertEqual(data["total_samples"],32768);self.assertEqual(len(data["groups"]),4)
            b=next(Path(a["folder"]).glob("capture_*.bin"));b.write_bytes(b"corrupted")
            with self.assertRaises(ValueError):review(a["folder"])
    def test_fault_saved_and_no_further_capture(self):
        with tempfile.TemporaryDirectory()as tmp:
            s=FakeSession(fault_at=3);a=collect(s,"fixture","2026-11-10",tmp);self.assertEqual(len(s.calls),3);self.assertEqual(a["status"],"stopped_on_fault");self.assertTrue(a["ro_off_confirmed"])
            data=review(a["folder"]);self.assertEqual(data["total_samples"],2176);self.assertTrue(data["per_batch"][-1]["alarm"])
    def test_interrupt_preserves_completed_batch(self):
        with tempfile.TemporaryDirectory()as tmp:
            s=FakeSession(interrupt_at=2)
            with self.assertRaises(KeyboardInterrupt):collect(s,"fixture","2026-11-10",tmp)
            m=json.loads(next(Path(tmp).rglob("run_manifest.json")).read_text());self.assertEqual(m["status"],"interrupted");self.assertEqual(len(m["batches"]),1);self.assertTrue(s.closed)
    def test_cleanup_failure_not_success(self):
        with tempfile.TemporaryDirectory()as tmp:
            a=collect(FakeSession(close_error=True),"fixture","2026-11-10",tmp,dividers=(256,),rounds=1);self.assertEqual(a["status"],"cleanup_failed");self.assertFalse(a["ro_off_confirmed"])
    def test_parameter_bound_before_hardware(self):
        with tempfile.TemporaryDirectory()as tmp:
            s=FakeSession()
            with self.assertRaises(ValueError):collect(s,"fixture","2026-11-10",tmp,rounds=1000)
            self.assertEqual(s.calls,[]);self.assertEqual(list(Path(tmp).iterdir()),[])
    def test_real_release_snapshot_with_mock_capture(self):
        bit=ROOT/"build/overlay/entropy_health.bit"
        if not bit.exists():self.skipTest("No local release")
        with tempfile.TemporaryDirectory()as tmp:
            s=FakeSession();s.bitfile=str(bit);s.release["build_id"]=json.loads((bit.parent/"release_manifest.json").read_text())["build_id"]
            a=collect(s,"fixture","2026-11-10",tmp,dividers=(256,),rounds=1)
            self.assertEqual(review(a["folder"])["integrity"],"PASS")
            p=Path(a["folder"])/"release_manifest.json";p.write_text("{}")
            with self.assertRaises(ValueError):review(a["folder"])
    def test_statistics_known_patterns(self):
        a=[0,1]*64;self.assertEqual(correlation(a,a),1);self.assertEqual(correlation(a,[1-x for x in a]),-1);self.assertIsNone(correlation([0]*128,a))
        data=features(bytes([0,255])*64);self.assertEqual(data["pairwise"][0]["correlation"],1);self.assertEqual(data["lag"][0]["correlation"],-1)
if __name__=="__main__":unittest.main()
