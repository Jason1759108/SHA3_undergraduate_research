# Complete paper source package

All four versions include the final Python 2.7 support and core loading testbench fix.
See WORKSTATION_GUIDE.md for the full build/merge and execution instructions.
User-reported complete workstation VCS RTL suites passed on 2026-10-27.
See workstation_rtl_validation.json for the run IDs and evidence limits.
User reports the corrected DC smoke test passed. Full dense-sweep results and raw workstation RTL/DC evidence remain pending import.

Existing validated workstation projects: do not overwrite 00/01 or their runtime summaries; proceed to the documented 02 sweep.
Fresh school build projects: merge source/test files but preserve the school's Makefiles and original syn.tcl/tool launch scripts. Run our complete runners, not the single-case school shortcuts. The bundled Makefiles are provided for standalone source completeness.

No patch ZIP is required. Original source provenance is recorded separately from prepared_hashes.csv. Raw results are not included in this source archive.

Dense sweep entry: bash run_dense_sweep.sh VERSION_DIRECTORY (10.0 to 1.0 ns, step 0.1 ns, 91 points, full/core).

See ARCHITECTURE_GUIDE.md for each file, original/new sweep comparison, reports and verification limits.
