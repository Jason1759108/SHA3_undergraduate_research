source [file join [file dirname [info script]] common.tcl]
if {[current_project -quiet] eq ""} {
    open_project [file join $stage1_root build sha3_pynq sha3_pynq.xpr]
}
set tb [file join $stage1_root sim tb_sha3_system.sv]
if {[llength [get_files -quiet $tb]] == 0} {add_files -fileset sim_1 -norecurse $tb}
set_property top tb_sha3_system [get_filesets sim_1]
set_property include_dirs [list [file join $stage1_root sim vectors]] [get_filesets sim_1]
set_property -name xsim.elaborate.xelab.more_options -value {--timescale 1ns/1ps} -objects [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -scripts_only
set sim_dir [file join [get_property DIRECTORY [current_project]] sha3_pynq.sim sim_1 behav xsim]
foreach name {tx.hex rx.hex cases.hex} {
    file copy -force [file join $stage1_root sim vectors $name] [file join $sim_dir $name]
}
puts "SYSTEM_SIM_DIRECTORY=$sim_dir"
