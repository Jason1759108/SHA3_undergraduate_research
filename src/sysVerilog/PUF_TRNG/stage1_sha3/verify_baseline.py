"""Check that the original RTL still matches the baseline frozen for this overlay."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
manifest = json.loads((ROOT / "baseline_manifest.json").read_text(encoding="utf-8"))
baseline = ROOT.parents[1] / "01_RTL"
changed = []
for name, expected in manifest["sha256"].items():
    path = baseline / name
    actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else "missing"
    if actual != expected:
        changed.append(name)
if changed:
    raise SystemExit("Baseline changed since this snapshot: " + ", ".join(changed))
print("PASS original 01_RTL matches all {} frozen source hashes".format(len(manifest["sha256"])))
