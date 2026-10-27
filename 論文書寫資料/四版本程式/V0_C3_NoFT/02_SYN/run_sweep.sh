#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

# Standard-library runner supports Python 2.7 and Python 3.4+.
python_ok() {
    command -v "$1" >/dev/null 2>&1 &&
        "$1" -c 'import sys; sys.exit(0 if (sys.version_info[:2] == (2, 7) or sys.version_info >= (3, 4)) else 1)' >/dev/null 2>&1
}
selected=""
if [[ -n "${PYTHON:-}" ]]; then
    if python_ok "$PYTHON"; then
        selected="$PYTHON"
    else
        printf '[FAIL] PYTHON=%s is unavailable or not a supported Python (2.7 or >= 3.4).\n' "$PYTHON" >&2
        exit 127
    fi
else
    for candidate in python python2.7 python2 python3 python3.14 python3.13 python3.12 python3.11 python3.10 python3.9 python3.8 python \
        "$HOME/miniconda3/bin/python" "$HOME/anaconda3/bin/python"; do
        if python_ok "$candidate"; then selected="$candidate"; break; fi
    done
fi
if [[ -z "$selected" ]]; then
    printf '%s\n' '[FAIL] No Python 2.7 or >= 3.4 found. No simulation or synthesis was started.' \
        'If Python is installed elsewhere, run: env PYTHON=/absolute/path/to/python3 bash run_sweep.sh' >&2
    exit 127
fi
printf '[INFO] Python executable: %s\n' "$(command -v "$selected")"
exec "$selected" run_sweep.py "$@"
