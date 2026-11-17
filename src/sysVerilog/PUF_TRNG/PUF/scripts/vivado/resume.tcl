# Resume implementation of THIS KIT after a constraint-only change.
# Set RO_DIAG_PROJECT to the generated puf256.xpr, then source this file.
set root [file normalize [file join [file dirname [info script]] .. ..]]
if {![info exists ::env(RO_DIAG_PROJECT)]} {error "Set RO_DIAG_PROJECT to this kit's generated puf256.xpr"}
set project_file [file normalize $::env(RO_DIAG_PROJECT)]
if {[file tail $project_file] ne "puf256.xpr"} {error "Expected diagnostic puf256.xpr"}
set build [file dirname [file dirname $project_file]]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set jobs 4
open_project $project_file
if {[get_property TOP [current_fileset]] ne "design_1_wrapper"} {error "Unexpected diagnostic top"}
if {![string match {*Complete*} [get_property STATUS [get_runs synth_1]]]} {error "Synthesis must complete before resume"}
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $root scripts/vivado ro_constraints.tcl] [get_runs impl_1]
reset_run impl_1
source [file join $root scripts/vivado configure_reports.tcl]
launch_runs impl_1 -to_step route_design -jobs $jobs
wait_on_run impl_1
if {![string match {*Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed; inspect $build/project"}
set ::env(RO_DIAG_DEFER_METHODOLOGY) 1
source [file join $root scripts/vivado export.tcl]
set ::env(RO_DIAG_EXISTING_BUILD) $build
close_project
source [file join $root scripts/vivado methodology_separate.tcl]
