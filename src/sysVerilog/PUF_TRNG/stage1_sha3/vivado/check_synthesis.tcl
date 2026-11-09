source [file join [file dirname [info script]] common.tcl]
set out [file join $stage1_root build synthesis_check]
file mkdir $out
create_project -in_memory -part xc7z020clg400-1
add_stage1_rtl
synth_design -top sha3_axis_top -part xc7z020clg400-1
create_clock -period 40.000 [get_ports axis_aclk]
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -file [file join $out timing.rpt]
report_clocks -file [file join $out clocks.rpt]
report_drc -file [file join $out drc.rpt]
write_checkpoint -force [file join $out sha3_axis_synth.dcp]
puts "SUCCESS SHA3 FPGA synthesis completed. Implementation timing is checked separately."
