# Dedicated digital integration synthesis. Existing syn.tcl is not overwritten.
# cd 02_SYN; TARGET_LIBRARY=/path/to/cells.db dc_shell -f syn_puf_ro.tcl
if {![info exists env(TARGET_LIBRARY)]} {error "Set TARGET_LIBRARY to actual .db libraries"}
set target_library $env(TARGET_LIBRARY)
set link_library [concat "*" $target_library]
set TOP puf_ro_top
if {[info exists env(TOP)]} {set TOP $env(TOP)}
if {$TOP ni {puf_ro_top ro_measure_backend puf_device ro_frequency_counter puf_sketch}} {error "Digital tops only; physical RO mapping requires technology setup"}
set PERIOD 10.0
if {[info exists env(CLK_PERIOD)]} {set PERIOD $env(CLK_PERIOD)}
file mkdir Report Netlist
set f [open ../00_TESTBED/rtl_digital.f r]
set sources [list]
foreach line [split [read $f] "\n"] {set line [string trim $line];if {$line ne ""} {lappend sources $line}}
close $f
remove_design -all
analyze -format sverilog $sources
elaborate $TOP
link
check_design > Report/${TOP}_precheck.rpt
if {$TOP eq "puf_sketch"} {
    set_max_delay $PERIOD -from [all_inputs] -to [all_outputs]
} else {
    create_clock -name clk -period $PERIOD [get_ports clk]
    set_clock_uncertainty 0.1 [get_clocks clk]
    set ios [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
    if {$TOP in {puf_ro_top ro_measure_backend}} {
        # EXAMPLE independent RO clocks. Replace periods/CDC constraints for silicon.
        set groups [list set_clock_groups -asynchronous -group [get_clocks clk]]
        for {set i 0} {$i<640} {incr i} {
            create_clock -name RO_$i -period 3.0 [get_ports [format {ro_signals[%d]} $i]]
            lappend groups -group [get_clocks RO_$i]
        }
        eval $groups
        set ios [remove_from_collection $ios [get_ports ro_signals*]]
    } elseif {$TOP eq "ro_frequency_counter"} {
        create_clock -name ro_a -period 3.0 [get_ports ro_a]
        create_clock -name ro_b -period 3.0 [get_ports ro_b]
        set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks ro_a] -group [get_clocks ro_b]
        set ios [remove_from_collection $ios [get_ports {ro_a ro_b}]]
    }
    set_input_delay [expr 0.2*$PERIOD] -clock clk $ios
    set_output_delay [expr 0.2*$PERIOD] -clock clk [all_outputs]
    set_false_path -from [get_ports rst_n]
}
set_load 0.05 [all_outputs]
set_fix_multiple_port_nets -all -buffer_constants
compile_ultra
check_design > Report/${TOP}_check.rpt
report_area -hierarchy > Report/${TOP}_area.rpt
report_timing -max_paths 20 > Report/${TOP}_timing.rpt
write -format verilog -hierarchy -output Netlist/${TOP}_syn.v
write -format ddc -hierarchy -output Netlist/${TOP}.ddc
if {$TOP ne "puf_sketch"} {write_sdc Netlist/${TOP}.sdc}
quit
