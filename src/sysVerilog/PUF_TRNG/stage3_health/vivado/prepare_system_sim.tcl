source [file join [file dirname [info script]] common.tcl]
if {[current_project -quiet] eq ""} {error "Open your completed entropy project first"}
open_bd_design [get_files design_1.bd]
validate_bd_design
generate_target all [get_files design_1.bd]
set tb [file join $entropy_root sim tb_entropy_system.sv]
if {[llength [get_files -quiet $tb]]==0} {add_files -fileset sim_1 -norecurse $tb}
set_property top tb_entropy_system [get_filesets sim_1]
set_property -name xsim.elaborate.xelab.more_options -value {--timescale 1ns/1ps} -objects [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -scripts_only
set folder [file join [get_property DIRECTORY [current_project]] [get_property NAME [current_project]].sim sim_1 behav xsim]
set f [open [file join $entropy_root build system_sim_path.txt] w]; puts $f $folder; close $f
puts "PASS system simulation prepared: $folder"
