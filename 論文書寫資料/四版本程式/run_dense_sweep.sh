#!/usr/bin/env bash
set -euo pipefail
# Integer tenths avoid floating-point accumulation: exactly 91 periods.
periods=()
for ((tenth=100; tenth>=10; tenth--)); do
    printf -v period '%d.%d' "$((tenth / 10))" "$((tenth % 10))"
    periods+=("$period")
done
if [[ "${1:-}" == "--list-only" ]]; then
    printf '%s\n' "${periods[@]}"
    exit 0
fi
if [[ $# -ne 1 ]]; then
    printf 'Usage: bash run_dense_sweep.sh VERSION_DIRECTORY\n' >&2
    exit 2
fi
version="$1"
case "$version" in
    V0_C3_NoFT|V1_State1600_SECDED_Replay|V2_Lane64_SECDED_Replay|V3_LaneParity_LocalReplay) ;;
    *) printf '[FAIL] Unknown version: %s\n' "$version" >&2; exit 2 ;;
esac
root="$(cd -- "$(dirname -- "$0")" && pwd)"
runner="$root/$version/02_SYN/run_sweep.sh"
if [[ ! -f "$runner" ]]; then
    printf '[FAIL] Missing runner: %s\n' "$runner" >&2
    exit 1
fi
printf '[INFO] %s: 10.0 down to 1.0 ns, step 0.1 ns; 91 periods x full/core = 182 synthesis runs.\n' "$version"
exec bash "$runner" --periods "${periods[@]}" --process TSMC40
