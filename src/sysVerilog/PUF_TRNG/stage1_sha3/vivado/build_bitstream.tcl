source [file join [file dirname [info script]] common.tcl]
if {[current_project -quiet] eq ""} {
    open_project [file join $stage1_root build sha3_pynq sha3_pynq.xpr]
}
set_property board_part [lindex [get_board_parts *pynq-z2*] end] [current_project]
open_bd_design [get_files design_1.bd]
validate_bd_design
source [file join $stage1_root vivado check_aux_reset.tcl]
save_bd_design
generate_target all [get_files design_1.bd]
if {[get_property NEEDS_REFRESH [get_runs synth_1]]} {
    reset_run synth_1
} elseif {[get_property NEEDS_REFRESH [get_runs impl_1]]} {
    reset_run impl_1
}
if {![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
    launch_runs impl_1 -to_step write_bitstream -jobs 2
    wait_on_run impl_1
}
if {![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "Bitstream build failed. Inspect the Vivado Messages and implementation log."
}
open_run impl_1
set reports [file join $stage1_root build reports]
file mkdir $reports
report_timing_summary -report_unconstrained -file [file join $reports timing_summary.rpt]
report_utilization -file [file join $reports utilization.rpt]
report_drc -file [file join $reports drc.rpt]
report_clocks -file [file join $reports clocks.rpt]
set worst_setup [get_timing_paths -delay_type max -max_paths 1]
set worst_hold [get_timing_paths -delay_type min -max_paths 1]
if {[llength $worst_setup] == 0 || [llength $worst_hold] == 0} {error "No timed paths found."}
if {[get_property SLACK $worst_setup] < 0 || [get_property SLACK $worst_hold] < 0} {
    error "Implementation has negative timing slack. Inspect reports before exporting."
}
source [file join $stage1_root vivado export_overlay.tcl]
