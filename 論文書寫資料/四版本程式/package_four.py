"""Create the workstation overlay ZIP without logs, netlists, or PDK files."""
from pathlib import Path
import csv
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parent
NAMES = (
    "V0_C3_NoFT",
    "V1_State1600_SECDED_Replay",
    "V2_Lane64_SECDED_Replay",
    "V3_LaneParity_LocalReplay",
)
OUTPUT = ROOT / "SERIAL320_four_compact.zip"
OMIT = {"sweep_dc_original.sh", "post_sweep.py"}

for name in NAMES:
    project = ROOT / name
    with (project / "prepared_hashes.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(("path", "sha256"))
        for folder in ("00_TESTBED", "01_RTL", "02_SYN", "03_GATE"):
            for path in sorted((project / folder).rglob("*")):
                if path.is_file() and path.name not in OMIT and not any(part in ("results", "__pycache__") for part in path.relative_to(project).parts):
                    writer.writerow((path.relative_to(project).as_posix(), hashlib.sha256(path.read_bytes()).hexdigest()))

with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for name in NAMES:
        project = ROOT / name
        for path in sorted(project.rglob("*")):
            if path.is_file() and path.name not in OMIT and not any(part in ("results", "__pycache__") for part in path.relative_to(project).parts):
                z.write(path, (Path("SERIAL320") / name / path.relative_to(project)).as_posix())
    for filename in ("check_serial320_10ns.sh", "collect_compact_results.py",
                     "PROJECT_10NS_GUIDE.md"):
        z.write(ROOT / filename, (Path("SERIAL320") / filename).as_posix())

with zipfile.ZipFile(OUTPUT) as z:
    if z.testzip() is not None:
        raise RuntimeError("ZIP CRC verification failed")
    print("[ZIP_OK] {} files={} bytes={}".format(OUTPUT.name, len(z.namelist()), OUTPUT.stat().st_size))
