#!/usr/bin/env bash
# Run the complete RTL suite, original 10 ns DC flow, and matching SDF gate
# simulation for each candidate. Execute from the built ~/SERIAL320 directory.
set -euo pipefail
cd -- "$(dirname -- "$0")"
logdir="check_logs"
mkdir -p "$logdir"
failed=0

for version in V0_C3_NoFT V1_State1600_SECDED_Replay V2_Lane64_SECDED_Replay V3_LaneParity_LocalReplay; do
    if [[ ! -f "$version/00_TESTBED/run_all_rtl.sh" || ! -f "$version/02_SYN/run_sweep.sh" ]]; then
        echo "[MISSING_PROJECT] $version; build and overlay this version first"
        failed=1
        continue
    fi
    echo "[START_RTL] $version"
    if (cd "$version/00_TESTBED" && bash run_all_rtl.sh) > "$logdir/$version.rtl.log" 2>&1; then
        echo "[RTL_PASS] $version"
    else
        echo "[RTL_FAIL] $version; see $logdir/$version.rtl.log"
        failed=1
        continue
    fi
    echo "[START_10NS_SYN_GATE] $version"
    if (cd "$version/02_SYN" && bash run_sweep.sh 10 10 1 240) > "$logdir/$version.sweep.log" 2>&1; then
        echo "[SWEEP_EXECUTED] $version"
    else
        echo "[SWEEP_FAILED] $version; see $logdir/$version.sweep.log"
        failed=1
        continue
    fi
    if ! grep -q '^\[GATE_PASS_WITH_SDF_WARNING\]\|^\[GATE_PASS\]' "$logdir/$version.sweep.log"; then
        echo "[GATE_NOT_PASS] $version; see $logdir/$version.sweep.log"
        failed=1
        continue
    fi
    if ! grep -q '^\[COMPLETED_CLEAN\]' "$logdir/$version.sweep.log"; then
        echo "[POINT_NOT_CLEAN] $version; see $logdir/$version.sweep.log"
        failed=1
        continue
    fi
    echo "[PASS_10NS] $version"
    grep -E '^\[(RESULT|HISTORY_DIFFERENT|HISTORY_MATCH|GATE_PASS|FULL_SHA3|POINT|SUMMARY|COMPLETED_CLEAN)' "$logdir/$version.sweep.log" | tail -n 8
done

if ((failed)); then
    echo "[FOUR_10NS_INCOMPLETE] See each version's CSV and $logdir"
    exit 1
fi
echo "[ALL_FOUR_10NS_PASS] $logdir"
