#!/usr/bin/env bash
set -u
printf '[INFO] Diagnostic only: no simulation, synthesis, installation or deletion.\n'
printf '[INFO] Current shell process: %s; inherited SHELL: %s\n' "$BASH_VERSION" "${SHELL:-unknown}"
found=0
for p in "${PYTHON:-python}" python2.7 python2 python3 python3.14 python3.13 python3.12 python3.11 python3.10 python3.9 python3.8 python "$HOME/miniconda3/bin/python" "$HOME/anaconda3/bin/python" /usr/local/bin/python3 /opt/rh/rh-python38/root/usr/bin/python3; do
    if command -v "$p" >/dev/null 2>&1; then
        printf '[FOUND] %s: ' "$(command -v "$p")"
        "$p" --version 2>&1
        if "$p" -c 'import sys; sys.exit(0 if (sys.version_info[:2] == (2,7) or sys.version_info >= (3,4)) else 1)' >/dev/null 2>&1; then
            printf '[PASS] Compatible Python (2.7 or >= 3.4): %s\n' "$(command -v "$p")"
            found=1
        fi
    fi
done
if [ "$found" -eq 0 ]; then
    printf '[MISSING] Python 2.7 or >= 3.4 not found in checked locations.\n'
fi
missing=0
for tool in vcs dcnxt_shell make tar; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '[FOUND] %s: %s\n' "$tool" "$(command -v "$tool")"
    else
        printf '[MISSING] %s is not on PATH.\n' "$tool"
        missing=1
    fi
done
lib=/usr/cad/CBDK_TSMC40_Arm_f2.0/CIC/SynopsysDC/db/sc9_base_rvt/sc9_cln40g_base_rvt_tt_typical_max_0p90v_25c.db
if [ -r "$lib" ]; then
    printf '[PASS] TSMC40 target library is readable.\n'
else
    printf '[MISSING] Target library not readable: %s\n' "$lib"
    missing=1
fi
if [ "$found" -eq 1 ] && [ "$missing" -eq 0 ]; then
    printf '[SUCCESS] Basic prerequisites found. Licenses and actual VCS/DC execution remain untested.\n'
else
    printf '[ACTION] Send this complete output back before running RTL/sweep.\n'
    exit 1
fi
