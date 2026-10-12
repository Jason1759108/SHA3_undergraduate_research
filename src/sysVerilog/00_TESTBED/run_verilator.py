"""Reproducible RTL regression; tool installation is deliberately separate.

Linux: python3 run_verilator.py --mode all
Windows: pass --verilator PATH/TO/verilator_bin.exe --zig PATH/TO/zig.exe.
Logs, generated C++, executables and compiler caches go under repo/.tmp.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
TESTBED = Path("src/sysVerilog/00_TESTBED")


def run_logged(command, log, env):
    with log.open("w", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=600)
    if result.returncode:
        print(log.read_text(encoding="utf-8", errors="replace")[-6000:])
        raise SystemExit(f"Failed ({result.returncode}); see {log}")


def run_mode(mode, args):
    build = ROOT / ".tmp" / "sha3_validation" / mode
    build.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    exe = Path(args.verilator).resolve()
    if exe.name == "verilator_bin.exe":
        # The Windows executable escapes spaces in an absolute VERILATOR_ROOT.
        env["VERILATOR_ROOT"] = os.path.relpath(exe.parent.parent, ROOT)
    top = "tb_parity_predictor" if mode == "unit" else "TESTBED"
    command = [str(exe), "--timing", "--assert", "-Wno-fatal",
               "-Wno-TIMESCALEMOD", "--top-module", top, "--prefix", "VTEST",
               "--Mdir", str(build.relative_to(ROOT)), "-DNO_DUMP"]
    if mode == "unit":
        command += ["src/sysVerilog/01_RTL/sha3_pkg.sv",
                    "src/sysVerilog/01_RTL/keccak_parity_predictor.sv",
                    "src/sysVerilog/01_RTL/keccak_lane_parity.sv",
                    str(TESTBED / "tb_parity_predictor.sv")]
    else:
        command += ["-F", str(TESTBED / "filelist.f")]
        if mode == "ft":
            command += ["-DFT_PATTERN"]
        elif mode == "baseline":
            command += ["-DFT_DISABLED"]
    if args.zig:
        command += ["--cc", "--main"]
    else:
        command += ["--binary", "-j", "2"]
    run_logged(command, build / "verilator.log", env)
    if args.zig:
        runtime = exe.parent.parent / "include"
        tmp = ROOT / ".tmp"
        env.update(ZIG_GLOBAL_CACHE_DIR=str(tmp / "zig-global-cache"),
                   ZIG_LOCAL_CACHE_DIR=str(tmp / "zig-local-cache"),
                   TEMP=str(tmp), TMP=str(tmp))
        output = build / ("sim.exe" if os.name == "nt" else "sim")
        compile_cmd = [str(Path(args.zig).resolve()), "c++", "-std=c++20", "-O1",
                       "-DVL_TIME_CONTEXT", "-Wno-nullability-completeness",
                       "-I" + str(runtime), "-I" + str(build)]
        if os.name == "nt":
            compile_cmd += ["-target", "x86_64-windows-gnu"]
        compile_cmd += [str(p) for p in sorted(build.glob("*.cpp"))]
        compile_cmd += [str(runtime / name) for name in
                        ("verilated.cpp", "verilated_threads.cpp", "verilated_timing.cpp")]
        compile_cmd += ["-o", str(output)]
        run_logged(compile_cmd, build / "build.log", env)
    else:
        output = build / ("VTEST.exe" if os.name == "nt" else "VTEST")
    run_logged([str(output)], build / "simulation.log", env)
    result = (build / "simulation.log").read_text(encoding="utf-8")
    if "[SUCCESS]" not in result or "[FAIL]" in result:
        raise SystemExit(f"No successful regression result: {build / 'simulation.log'}")
    print(f"{mode}: " + next(line for line in result.splitlines() if "[SUCCESS]" in line))
    print(f"  logs: {build}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("all", "unit", "normal", "ft", "baseline"), default="all")
    parser.add_argument("--verilator", default=shutil.which("verilator"))
    parser.add_argument("--zig", help="Optional Zig C++ compiler (used for native Windows)")
    args = parser.parse_args()
    if not args.verilator:
        parser.error("Verilator not found; install it or pass --verilator")
    for mode in (("unit", "normal", "ft", "baseline") if args.mode == "all" else (args.mode,)):
        run_mode(mode, args)
