"""Execute Vivado-generated full-system simulation scripts and record the HWH tested."""
import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vivado-bin", default="D:/VIVADO/2025.2/Vivado/bin")
    args = parser.parse_args()
    folder = ROOT / "build/sha3_pynq/sha3_pynq.sim/sim_1/behav/xsim"
    env = os.environ.copy()
    env["PATH"] = args.vivado_bin + os.pathsep + env["PATH"]
    result_file = ROOT / "build/system_sim_result.json"
    result_file.unlink(missing_ok=True)
    for name in ("compile", "elaborate", "simulate"):
        log = folder / (name + "_driver.log")
        with log.open("w", encoding="utf-8") as out:
            result = subprocess.run([str(folder / (name + ".bat"))], cwd=str(folder), env=env,
                                    stdout=out, stderr=subprocess.STDOUT)
        if result.returncode:
            print(log.read_text(encoding="utf-8", errors="replace")[-7000:])
            raise SystemExit("Full-system {} failed. See {}".format(name, log))
    text = (folder / "simulate_driver.log").read_text(encoding="utf-8", errors="replace")
    marker = "SUCCESS FULL SYSTEM reset MMIO DDR-read DMA SHA3 HP0-write and recovery"
    if marker not in text or "Fatal:" in text or "FATAL" in text or re.search(r"(?m)^ERROR:", text):
        print(text[-7000:])
        raise SystemExit("Full-system simulation did not pass")
    hwh = ROOT / "build/sha3_pynq/sha3_pynq.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh"
    summary = {"status": "PASS", "rx_check": "independent HP0 byte scoreboard, not VIP DDR backdoor readback", "hwh_sha256": hashlib.sha256(hwh.read_bytes()).hexdigest(),
               "sha3_cases": text.count("PASS SYSTEM case="), "marker": marker}
    if summary["sha3_cases"] != 36:
        raise SystemExit("Expected all 36 SHA-3 system comparisons, including recovery")
    inputs = list((ROOT / "rtl").rglob("*.sv")) + [ROOT / "sim/tb_sha3_system.sv"]
    summary["source_sha256"] = {str(p.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in sorted(inputs)}
    result_file.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(text[-5000:])
    print("Recorded", result_file)


if __name__ == "__main__":
    main()
