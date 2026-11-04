"""Save only the four RTL status records and final result CSV files.

Compatible with the workstation's Python 2.7 and Python 3.
"""
from __future__ import print_function
import glob
import os
import sys
import time
import zipfile

ROOT = os.path.abspath(os.path.dirname(__file__))
VERSIONS = (
    "V0_C3_NoFT",
    "V1_State1600_SECDED_Replay",
    "V2_Lane64_SECDED_Replay",
    "V3_LaneParity_LocalReplay",
)
KEEP = set(("rtl_latest.json", "sweep_summary.csv"))


def main():
    target = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(
        ROOT, "compact_results_{}.zip".format(time.strftime("%Y%m%d_%H%M%S")))
    count = 0
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for version in VERSIONS:
            base = os.path.join(ROOT, version)
            if not os.path.isdir(base):
                continue
            for folder, directories, filenames in os.walk(base):
                directories[:] = [d for d in directories if d not in
                                  ("00_TESTBED", "01_RTL", "02_SYN", "03_GATE", "csrc", "Netlist", "Report", "__pycache__")]
                for name in filenames:
                    if name not in KEEP:
                        continue
                    path = os.path.join(folder, name)
                    if os.path.islink(path):
                        continue
                    archive.write(path, os.path.relpath(path, ROOT).replace(os.sep, "/"))
                    count += 1
    with zipfile.ZipFile(target) as archive:
        bad = archive.testzip()
    if bad:
        raise RuntimeError("ZIP CRC failed: " + bad)
    print("[COMPACT_RESULTS] file_count={} bytes={} output={}".format(count, os.path.getsize(target), os.path.basename(target)))


if __name__ == "__main__":
    main()
