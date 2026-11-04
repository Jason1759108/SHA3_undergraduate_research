#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
exec 8>.original_sweep.lock
flock -n 8 || { echo '[FAIL] A sweep is already using this 02_SYN'; exit 1; }
PAPER_PYTHON="${PYTHON:-python}"
"$PAPER_PYTHON" -c 'import sys; assert sys.version_info[:2] == (2,7) or sys.version_info >= (3,4)'
export PAPER_PYTHON
"$PAPER_PYTHON" post_sweep_minimal.py preflight
mkdir -p Report Netlist
chmod +x 01_run_dc
export DESIGN="SHA3_1600"
export RUN_SCRIPT=./01_run_dc
export REPORT_DIR=./Report
export OUTPUT_ROOT=../results/sweep
export PROCESS=TSMC40

# These are exports consumed by the original Makefile, not rewritten commands.
exec bash sweep_dc.sh "$@"
