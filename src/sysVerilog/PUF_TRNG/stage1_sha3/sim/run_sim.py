"""Run the actual FPGA RTL in Vivado Simulator, with hashlib reference vectors."""
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(command, cwd, log):
    with log.open("w", encoding="utf-8") as out:
        result = subprocess.run([str(x) for x in command], cwd=str(cwd), stdout=out, stderr=subprocess.STDOUT)
    if result.returncode:
        print(log.read_text(encoding="utf-8", errors="replace")[-8000:])
        raise SystemExit("Command failed. See {}".format(log))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vivado-bin", default="D:/VIVADO/2025.2/Vivado/bin")
    parser.add_argument("--suite", choices=("axis", "normal", "ft"), default="axis")
    args = parser.parse_args()
    tool_dir = Path(args.vivado_bin)
    suffix = ".bat" if sys.platform == "win32" else ""
    build = ROOT / "build" / ("simulation" if args.suite == "axis" else "regression_" + args.suite)
    build.mkdir(parents=True, exist_ok=True)
    run([sys.executable, ROOT / "sim" / "make_vectors.py"], ROOT, build / "vectors.log")
    for source in (ROOT / "sim" / "vectors").iterdir():
        (build / source.name).write_bytes(source.read_bytes())
    names = [
        "sha3_pkg", "sha3_ctrl_fsm", "sha3_pad_domain", "sha3_absorb_xor",
        "keccak_round_scheduler", "keccak_parity_predictor", "keccak_theta_serial",
        "keccak_rho_pi_wire", "keccak_chi_row", "keccak_iota", "keccak_lane_parity",
        "sha3_output_formatter", "keccak_state_bank", "sha3_ultra_low_power_top",
    ]
    sources = [ROOT / "rtl" / "core" / (name + ".sv") for name in names]
    defines = ["-d", "NO_DUMP"]
    if args.suite == "axis":
        top, marker = "tb_sha3_axis", "SUCCESS SHA3 AXI"
        sources += [ROOT / "rtl" / "sha3_axis_top.sv", ROOT / "sim" / "tb_sha3_axis.sv"]
    else:
        top, marker = "TESTBED", "[SUCCESS]"
        baseline = ROOT / "sim" / "baseline"
        sources += [baseline / name for name in ("PATTERN.sv", "PATTERN_FT.sv", "TESTBED.sv")]
        if args.suite == "ft":
            defines += ["-d", "FT_PATTERN"]
    run([tool_dir / ("xvlog" + suffix), "--sv", "-i", build, *defines, *sources], build, build / "compile.log")
    run([tool_dir / ("xelab" + suffix), top, "-s", "sha3_axis_sim", "--debug", "typical", "--timescale", "1ns/1ps"], build, build / "elaborate.log")
    run([tool_dir / ("xsim" + suffix), "sha3_axis_sim", "-runall"], build, build / "simulation.log")
    text = (build / "simulation.log").read_text(encoding="utf-8", errors="replace")
    if marker not in text or "Fatal:" in text or "FATAL" in text or "[FAIL]" in text:
        print(text[-8000:])
        raise SystemExit("Simulation did not pass")
    print(text[-3500:])


if __name__ == "__main__":
    main()

