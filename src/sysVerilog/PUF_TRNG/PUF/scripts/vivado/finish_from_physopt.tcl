# Recover a completed placement without rerunning synthesis/placement. Save the
# routed design BEFORE expensive diagnostic reports so analysis can run apart.
set root [file normalize [file join [file dirname [info script]] .. ..]]
if {![info exists ::env(RO_DIAG_EXISTING_BUILD)]} {error "Set RO_DIAG_EXISTING_BUILD"}
set build [file normalize $::env(RO_DIAG_EXISTING_BUILD)]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set source_dcp [file join $build project puf256.runs impl_1 design_1_wrapper_physopt.dcp]
if {![file exists $source_dcp]} {error "Missing completed physopt checkpoint"}
set_param general.maxThreads 2
open_checkpoint $source_dcp
if {[get_property PART [current_project]] ne "xc7z020clg400-1"} {error "Unexpected device"}
route_design
write_checkpoint -force [file join $build final_routed.dcp]
set already_open_routed_checkpoint 1
set ::env(RO_DIAG_DEFER_METHODOLOGY) 1
source [file join $root scripts/vivado export.tcl]
