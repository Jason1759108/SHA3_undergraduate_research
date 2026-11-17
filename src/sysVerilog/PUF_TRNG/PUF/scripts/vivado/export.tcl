# Shared final checks/export; called by build.tcl or resume.tcl.
if {![info exists already_open_routed_checkpoint]} {
    open_run impl_1
    write_checkpoint -force [file join $build final_routed.dcp]
}
set reports [file join $build reports]
file mkdir $reports
report_timing_summary -report_unconstrained -file [file join $reports timing_summary.rpt]
report_cdc -details -file [file join $reports cdc.rpt]
report_utilization -file [file join $reports utilization.rpt]
report_drc -file [file join $reports drc.rpt]
report_clocks -file [file join $reports clocks.rpt]
report_bus_skew -file [file join $reports bus_skew.rpt]
# The completed implementation run already reports methodology on this exact
# routed netlist. Reuse that report; do not repeat the expensive 1280-clock scan.
set routed_methodology [file join $build project puf256.runs impl_1 design_1_wrapper_methodology_drc_routed.rpt]
if {[file exists $routed_methodology] && [file size $routed_methodology]>0} {
    file copy -force $routed_methodology [file join $reports methodology.rpt]
} elseif {[info exists ::env(RO_DIAG_DEFER_METHODOLOGY)] && $::env(RO_DIAG_DEFER_METHODOLOGY) eq "1"} {
    puts "METHODOLOGY DEFERRED: run methodology_separate.tcl on final_routed.dcp; no timing/CDC/DRC/skew checks are skipped."
} else {
    report_methodology -file [file join $reports methodology.rpt]
}
foreach prefix {ro_raw_ ro_div_} {
    set clocks [get_clocks -regexp ${prefix}\[0-9\]+]
    if {[llength $clocks] != 640} {error "Expected 640 $prefix clocks, found [llength $clocks]"}
}
proc read_report {path} {
    set f [open $path r]
    set contents [read $f]
    close $f
    return $contents
}
set timing_report [read_report [file join $reports timing_summary.rpt]]
set timing_start [string first {| Design Timing Summary} $timing_report]
if {$timing_start<0} {error "Missing design timing summary"}
set timing_table [string range $timing_report $timing_start end]
if {![regexp {WNS\(ns\)[^\n]*\n[^\n]*\n\s*([-0-9.]+)\s+([-0-9.]+)\s+(\d+)\s+(\d+)\s+([-0-9.]+)\s+([-0-9.]+)\s+(\d+)\s+(\d+)\s+([-0-9.]+)\s+([-0-9.]+)\s+(\d+)\s+(\d+)} $timing_table -> wns tns setup_fail setup_total whs ths hold_fail hold_total wpws tpws pulse_fail pulse_total]} {
    error "Cannot parse setup/hold/pulse timing summary; inspect reports before exporting"
}
if {$wns<0 || $whs<0 || $wpws<0 || $setup_fail || $hold_fail || $pulse_fail} {
    error "Setup/hold/pulse-width timing failed; bitstream not exported"
}
foreach check {no_clock unconstrained_internal_endpoints} {
    if {![regexp "checking $check \\(0\\)" $timing_report]} {error "Unexpected $check timing check"}
}
set cdc_report [read_report [file join $reports cdc.rpt]]
if {[regexp {CDC-[0-9]+\s+(Critical|Error)} $cdc_report]} {
    error "Unexpected critical CDC issue; inspect reports"
}
foreach delay_type {max min} {
    set path [get_timing_paths -delay_type $delay_type -max_paths 1]
    if {![llength $path] || [get_property SLACK $path]<0} {
        error "Timing ($delay_type) did not pass. Bitstream not exported; inspect $reports"
    }
}
set skew_file [open [file join $reports bus_skew.rpt] r]
set skew_report [read $skew_file]
close $skew_file
if {[regexp {Slack\s+\(VIOLATED\)} $skew_report] || [regexp {\sNA\s} $skew_report]} {
    error "Gray CDC bus skew did not pass. Bitstream not exported; inspect $reports"
}
set severe [get_drc_violations -quiet -filter {SEVERITY == "Error" || SEVERITY == "Critical Warning"}]
if {[llength $severe]} {error "Unresolved DRC violations: $severe. Inspect $reports; do not globally suppress them."}
set hwh [glob -nocomplain [file join $build project puf256.gen sources_1 bd design_1 hw_handoff design_1.hwh]]
if {![llength $hwh]} {set hwh [glob -nocomplain [file join $build project puf256.srcs sources_1 bd design_1 hw_handoff design_1.hwh]]}
if {[llength $hwh]!=1} {error "Cannot locate HWH in build $build"}
set deploy [file join $root deploy $stamp]
file mkdir $deploy
write_bitstream [file join $deploy puf256.bit]
file copy -force [lindex $hwh 0] [file join $deploy puf256.hwh]
set f [open [file join $deploy build_info.txt] w]
puts $f "Vivado: [version -short]\nBoard: [get_property BOARD_PART [current_project]]\nPart: [get_property PART [current_project]]\nBuild: $build\nClock: 100 MHz\nRO min period timing assumption: 2 ns\n"
close $f
puts "RO_DIAG BUILD COMPLETE: $deploy. Review timing/CDC/DRC reports before board measurements."
