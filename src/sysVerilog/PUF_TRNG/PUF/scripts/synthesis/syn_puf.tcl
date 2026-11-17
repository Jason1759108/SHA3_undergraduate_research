# DC entry for synchronous PUF digital logic only; no FPGA LUT oscillators.
# cd scripts/synthesis; TARGET_LIBRARY="/path/cells.db" dc_shell -f syn_puf.tcl
set root [file normalize [file join [file dirname [info script]] .. ..]]
if {![info exists ::env(TARGET_LIBRARY)] || [string trim $::env(TARGET_LIBRARY)] eq ""} {
    error "Set TARGET_LIBRARY to a Tcl list of licensed standard-cell .db paths"
}
set target_library $::env(TARGET_LIBRARY)
foreach library $target_library {
    if {![file isfile $library]} {error "Missing target library: $library"}
}
set link_library [concat [list *] $target_library]
if {[info exists ::env(LINK_LIBRARY)]} {set link_library [concat $link_library $::env(LINK_LIBRARY)]}
set top puf_device
if {[info exists ::env(PUF_SYN_TOP)]} {set top $::env(PUF_SYN_TOP)}
if {$top ni {puf_device puf_core puf_sketch}} {
    error "Supported digital tops: puf_device, puf_core, puf_sketch. Full RO FPGA top uses Vivado."
}
set period 10.0
if {[info exists ::env(CLK_PERIOD)]} {set period $::env(CLK_PERIOD)}
if {![string is double -strict $period] || $period<=0} {error "CLK_PERIOD must be positive ns"}
set out [file join $root build dc $top [clock format [clock seconds] -format %Y%m%d_%H%M%S]]
if {[info exists ::env(PUF_SYN_OUT)]} {set out [file normalize $::env(PUF_SYN_OUT)]}
if {[file exists $out]} {error "Output exists; choose a new PUF_SYN_OUT: $out"}
file mkdir $out
define_design_lib WORK -path [file join $out work]
set sources {}
foreach name {puf_types puf_sketch puf_core puf_device} {
    lappend sources [file join $root rtl ${name}.sv]
}
analyze -format sverilog $sources
elaborate $top
current_design $top
if {![link]} {error "Unresolved references; inspect library and source setup"}
redirect [file join $out precheck.rpt] {check_design}
set ios [all_inputs]
if {$top eq "puf_sketch"} {
    # Combinational helper/ECC block: budget input-to-output delay explicitly.
    set_max_delay $period -from [all_inputs] -to [all_outputs]
} else {
    create_clock -name clk -period $period [get_ports clk]
    set_clock_uncertainty 0.1 [get_clocks clk]
    set ios [remove_from_collection $ios [get_ports {clk rst_n}]]
    set_input_delay [expr {$period*0.2}] -clock clk $ios
    set_output_delay [expr {$period*0.2}] -clock clk [all_outputs]
    # Example synchronous system interface; reset assertion is asynchronous.
    # Review reset recovery/removal in the actual target implementation flow.
    set_false_path -from [get_ports rst_n]
}
set_load 0.05 [all_outputs]
set_fix_multiple_port_nets -all -buffer_constants
compile_ultra
redirect [file join $out check_design.rpt] {check_design}
redirect [file join $out check_timing.rpt] {check_timing}
redirect [file join $out area.rpt] {report_area -hierarchy}
redirect [file join $out timing_max.rpt] {report_timing -delay_type max -max_paths 20}
redirect [file join $out timing_min.rpt] {report_timing -delay_type min -max_paths 20}
redirect [file join $out constraints.rpt] {report_constraint -all_violators}
redirect [file join $out references.rpt] {report_reference -hierarchy}
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output [file join $out ${top}_syn.v]
write -format ddc -hierarchy -output [file join $out ${top}.ddc]
write_sdc [file join $out ${top}.sdc]
set record [open [file join $out RUN_COMPLETED.txt] w]
puts $record "DC command flow completed: $top\nPeriod ns: $period\nLibraries: $target_library\nThis is NOT a timing/physical signoff verdict. Review all generated reports."
close $record
puts "PUF_DIGITAL_SYNTHESIS_OUTPUT $out"
quit
