"""Create and validate the hardware-pair manifest in an exported overlay folder."""
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from sha3_pynq import validate_artifacts

folder = Path(sys.argv[1]).resolve()
files = (folder / "sha3_pynq.bit", folder / "sha3_pynq.hwh")
root = Path(__file__).resolve().parents[1]
system_test = json.loads((root / "build/system_sim_result.json").read_text(encoding="utf-8"))
if system_test["status"] != "PASS" or system_test["hwh_sha256"] != hashlib.sha256(files[1].read_bytes()).hexdigest():
    raise RuntimeError("Run the full-system simulation for this HWH before exporting")
for name, expected in system_test["source_sha256"].items():
    if hashlib.sha256((root / name).read_bytes()).hexdigest() != expected:
        raise RuntimeError("Sources changed since full-system simulation: " + name)
# Vivado can duplicate CR in copied Windows sources; normalize CR only.
for source in (root / "rtl").rglob("*.sv"):
    expected = source.read_bytes().replace(b"\r", b"")
    for base in (root / "build/ip_repo/sha3_axis_top/src",
                 root / "build/sha3_pynq/sha3_pynq.ip_user_files/bd/design_1/ipshared",
                 root / "build/sha3_pynq/sha3_pynq.gen/sources_1/bd/design_1/ipshared"):
        copies = list(base.rglob(source.name))
        if not copies or any(p.read_bytes().replace(b"\r", b"") != expected for p in copies):
            raise RuntimeError("Repackage/regenerate stale IP sources: " + source.name)
host_test = json.loads((root / "build/pynq25_compat/host_checks_passed.json").read_text(encoding="utf-8"))
if (host_test["status"] != "PASS" or
        host_test["driver_sha256"] != hashlib.sha256((folder / "sha3_pynq.py").read_bytes()).hexdigest()):
    raise RuntimeError("Run sim/check_host.py before exporting")
manifest = {
    "build_id": "sha3-reset-fixed-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
    "sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in files},
    "system_simulation": system_test,
    "pynq25_host_checks": host_test,
}
(folder / "release_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("PASS release preflight", validate_artifacts(files[0]))
