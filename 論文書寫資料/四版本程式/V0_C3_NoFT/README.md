# V0_C3_NoFT

Prepared paper package, 2026-10-27. Original source: 93cdc28337f97c38a1170f958b1065d55cf4bccb.
V1 only: the original 1600-bit overlay is already integrated into its 01_RTL.

1. From 00_TESTBED: `bash run_all_rtl.sh`
2. From 02_SYN: `bash run_sweep.sh --periods 10 8 6 4 2 1 --process TSMC40`

The sweep compiles full SHA3 and standalone core separately. All reports and netlists
are preserved under results/. The sweep rejects changed RTL/test sources after validation.
See the Chinese workstation guide in the parent paper workspace for exact procedures.

source_manifest.json and source_hashes.csv describe the ORIGINAL exported source, not
the prepared files. prepared_hashes.csv describes the current runnable package.
Changes: supplemental cross-lane tests where applicable, core reference tests, timing
monitor and aggregate runners; standalone core wrapper; common dual-scope synthesis.
V0/V1/V2 use packed RHO_OFFSET/PI_Y_MAP constant declarations with unchanged values and
indices for Windows Verilator portability. No original src/ files were edited.

Local Verilator passed. Workstation complete VCS RTL suite reported PASS: 20261027_190128.
Evidence: user-provided console output. Raw workstation logs/rtl_latest.json are pending import; corrected DC smoke-test success was reported by the user; full dense-sweep results are pending import.
All Python 2.7 compatibility and core-input loading timing fixes are integrated. No patch ZIP is required.
Do not label synthesis estimates as post-layout or trace-based energy measurements.
