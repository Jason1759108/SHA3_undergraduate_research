# Compatibility entry. Use run_sweep.sh for the complete paper flow.
if {![info exists env(PAPER_VERSION)]} {set env(PAPER_VERSION) V0_C3_NoFT}
if {![info exists env(PAPER_SCOPE)]} {set env(PAPER_SCOPE) full}
if {![info exists env(CLK_PERIOD)]} {set env(CLK_PERIOD) 10.0}
source paper_syn.tcl
