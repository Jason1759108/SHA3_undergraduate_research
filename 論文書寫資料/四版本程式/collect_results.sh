#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
items=()
for version in V0_C3_NoFT V1_State1600_SECDED_Replay V2_Lane64_SECDED_Replay V3_LaneParity_LocalReplay; do
    test -f "$version/rtl_latest.json" || { printf '[FAIL] Missing %s/rtl_latest.json\n' "$version"; exit 1; }
    test -d "$version/results/sweep" || { printf '[FAIL] Missing %s/results/sweep\n' "$version"; exit 1; }
    items+=("$version/results" "$version/rtl_latest.json")
done
archive="paper_results_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$archive" "${items[@]}"
printf '[SUCCESS] Saved %s (includes failed-point logs for diagnosis; inspect sweep_summary.json for validity).\n' "$archive"
