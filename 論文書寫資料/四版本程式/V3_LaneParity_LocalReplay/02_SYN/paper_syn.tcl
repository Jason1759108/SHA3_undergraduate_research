# Paper flow: identical constraints for the four versions, two physical boundaries.
# Run with run_sweep.sh so sources, setup, constraints and raw reports are retained.
file mkdir Report Netlist
set CYCLE $env(CLK_PERIOD)
set SCOPE $env(PAPER_SCOPE)
set VERSION $env(PAPER_VERSION)
if {$SCOPE ni {full core}} {error "PAPER_SCOPE must be full or core"}
if {![string is double -strict $CYCLE] || $CYCLE <= 0} {error "Invalid clock period"}
set TOP_MODULE [expr {$SCOPE eq "core" ? "paper_keccak_core" : "sha3_ultra_low_power_top"}]
set DESIGN ${VERSION}_${SCOPE}
remove_design -all
set hdlin_auto_save_templates true
analyze -format sverilog ../01_RTL/sha3_pkg.sv
set f [open ../00_TESTBED/filelist.f r]
set sources [split [read $f] \n]
close $f
foreach line $sources {
    set line [string trim $line]
    if {[string match "../01_RTL/*.sv" $line] && ![string match "*/sha3_pkg.sv" $line]} {
        analyze -format sverilog $line
    }
}
analyze -format sverilog ../01_RTL/paper_keccak_core.sv
if {[string match V3_* $VERSION]} {
    elaborate $TOP_MODULE -parameters "FT_ENABLE=1"
} else {
    elaborate $TOP_MODULE
}
set ELAB_TOP [get_object_name [current_design]]
if {![link]} {error "Link failed"}
uniquify
redirect Report/pre_compile.check {check_design}
create_clock -name clk -period $CYCLE [get_ports clk]
set_dont_touch_network [get_clocks clk]
# Keep the hold-fixing request used by the original synthesis script.
set_fix_hold [get_clocks clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition 0.1 [get_clocks clk]
set inputs [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_input_delay -max [expr 0.5*$CYCLE] -clock clk $inputs
set_input_delay -min 0 -clock clk $inputs
# load_state feeds a falling-edge gate-enable register: 0.5T input arrival
# would consume the entire half-cycle. Require arrival by 0.1T instead.
# This is an explicit core interface requirement, not a false/multicycle path.
if {$SCOPE eq "core"} {
    set_input_delay -max [expr 0.1*$CYCLE] -clock clk [get_ports load_state]
}
set_input_delay 0 -clock clk [get_ports {clk rst_n}]
set_output_delay -max [expr 0.5*$CYCLE] -clock clk [all_outputs]
set_output_delay -min 0 -clock clk [all_outputs]
# Common external slew assumption for all four versions. The old 0.5 ns
# exceeded the 0.38 ns limits reported by this library before any logic.
set_input_transition 0.1 [all_inputs]
set_load 0.05 [all_outputs]
set_max_transition 3 [all_inputs]
set_max_capacitance 0.15 [all_inputs]
set_max_fanout 10 [all_inputs]
set_wire_load_mode top
# Reset is asynchronous and not part of throughput timing.
set_false_path -from [get_ports rst_n]
# No-error implementation operating point. Preserve the actual protection blocks below.
set inject_ports [get_ports -quiet ft_*]
if {[sizeof_collection $inject_ports]} {
    set_case_analysis 0 $inject_ports
    set_false_path -from $inject_ports
}
# Explicit common vectorless activity; this is NOT trace-based measured energy.
# Record successful explicit input annotations, not measured/propagated activity.
# This audit uses Tcl file I/O because this DC has no report_switching_activity.
set activity_fd [open Report/activity.rpt w]
puts $activity_fd "method=vectorless; no SAIF/VCD annotation"
puts $activity_fd "coverage=explicit input settings only; internal propagated activity not reported"
puts $activity_fd "rows are in application order; later rows override earlier rows for a port"
puts $activity_fd "clock=clk; period_ns=$CYCLE; nonzero toggle rate is per base-clock cycle"
puts $activity_fd "port,static_probability,toggle_rate,base_clock"
set_switching_activity -static_probability 0.5 -toggle_rate 0.1 -base_clock clk $inputs
foreach_in_collection port $inputs {
    puts $activity_fd "[get_object_name $port],0.5,0.1,clk"
}
set_switching_activity -static_probability 1.0 -toggle_rate 0 [get_ports rst_n]
puts $activity_fd "rst_n,1.0,0,none"
if {[sizeof_collection $inject_ports]} {
    set_switching_activity -static_probability 0 -toggle_rate 0 $inject_ports
    foreach_in_collection port $inject_ports {
        puts $activity_fd "[get_object_name $port],0,0,none"
    }
}
close $activity_fd
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]

# Preserve only real checking instances, not encoder-only u_reencode instances.
# Uniquify first: a dedicated checker design can be compiled before freezing,
# without freezing the unused decoder outputs of encoder-only instances.
set keep_names {}
set expected 0
if {[string match V1_* $VERSION]} {set expected 5}
if {[string match V2_* $VERSION]} {set expected 29}
if {[string match V3_* $VERSION]} {set expected 2}
foreach_in_collection c [get_cells -hierarchical *] {
    set n [get_object_name $c]
    set r [get_attribute $c ref_name]
    if {([string match *u_hamming $n] || [string match *u_d_ham $n]) ||
        ([string match keccak_theta_parity* $r] || [string match keccak_chi_parity* $r])} {
        lappend keep_names $n
    }
}
if {[llength $keep_names] != $expected} {
    error "Protection count mismatch: expected $expected, got [llength $keep_names]"
}
set keep_report [open Report/protection_instances.csv w]
puts $keep_report "instance,reference,area_report"
proc paper_exact_cell {name} {
    # Generated instance names contain brackets; use equality, not a glob.
    return [get_cells -hierarchical -filter "full_name == \"$name\""]
}
foreach n $keep_names {
    current_design $ELAB_TOP
    set r [get_attribute [paper_exact_cell $n] ref_name]
    current_design $r
    set_max_delay $CYCLE -from [all_inputs] -to [all_outputs]
    # Common external slew assumption for all four versions. The old 0.5 ns
# exceeded the 0.38 ns limits reported by this library before any logic.
set_input_transition 0.1 [all_inputs]
    set_load 0.05 [all_outputs]
    compile_ultra
    set_dont_touch [get_designs $r] true
    current_design $ELAB_TOP
    set_boundary_optimization [paper_exact_cell $n] false
    set_ungroup [paper_exact_cell $n] false
    set_dont_touch [paper_exact_cell $n] true
}
current_design $ELAB_TOP
compile_ultra
set keep_index 0
foreach n $keep_names {
    current_design $ELAB_TOP
    set cell [paper_exact_cell $n]
    if {[sizeof_collection $cell] != 1} {error "Protection instance removed: $n"}
    set r [get_attribute $cell ref_name]
    current_design $r
    if {![get_attribute [current_design] is_mapped]} {
        error "Protection reference is not mapped: $n ($r)"
    }
    # Hierarchical instance 'area' is absent in this workstation DC.
    # Use report_area on its mapped reference, as in the original flow.
    set area_report [format "protection_%03d_area.rpt" $keep_index]
    redirect Report/$area_report {report_area -hierarchy}
    puts $keep_report "$n,$r,$area_report"
    incr keep_index
}
current_design $ELAB_TOP
close $keep_report
if {![get_attribute [current_design] is_mapped]} {error "Top is not fully mapped"}
if {![check_design]} {error "Post-compile check_design failed"}
redirect Report/check_design.rpt {check_design}
redirect Report/check_timing.rpt {check_timing}
redirect Report/area.rpt {report_area -hierarchy}
redirect Report/power.rpt {report_power}
redirect Report/power_hierarchy.rpt {report_power -hierarchy}
redirect Report/timing.rpt {report_timing -max_paths 20 -nets -transition_time -capacitance}
redirect Report/constraints.rpt {report_constraint -all_violators}
redirect Report/qor.rpt {report_qor}
redirect Report/clocks.rpt {report_clock}
redirect Report/ports.rpt {report_port -verbose}
redirect Report/references.rpt {report_reference -hierarchy}
redirect Report/design.rpt {report_design}
redirect Report/libraries.rpt {list_libs}
# Report/activity.rpt was written when explicit input settings were applied.
redirect Report/units.rpt {report_units}
set paths [get_timing_paths -max_paths 1]
if {[sizeof_collection $paths] != 1} {error "No constrained timing path found"}
set slack [get_attribute $paths slack]
set fd [open Report/run_metadata.txt w]
puts $fd "version=$VERSION\nscope=$SCOPE\nperiod_ns=$CYCLE\nworst_slack_ns=$slack"
puts $fd "power_method=vectorless_0.1_toggles_per_cycle\nprotection_instances=$expected"
puts $fd "target_library=$target_library\nlink_library=$link_library"
puts $fd "constraint_policy=paper_v2_slew0p1_coreload0p1T"
puts $fd "input_transition_ns=0.1; output_load_library_units=0.05"
puts $fd "input_delay_max_fraction=0.5; output_delay_max_fraction=0.5"
if {$SCOPE eq "core"} {puts $fd "load_state_input_delay_max_fraction=0.1"}
close $fd
change_names -hierarchy -rules verilog
write -format verilog -hierarchy -output Netlist/${DESIGN}_SYN.v
write -format ddc -hierarchy -output Netlist/${DESIGN}_SYN.ddc
write_sdf -version 3.0 Netlist/${DESIGN}_SYN.sdf
write_sdc Netlist/${DESIGN}_SYN.sdc
# The runner verifies reports and reports timing failures separately.
set fd [open Report/COMPLETE w]; puts $fd "Synthesis completed"; close $fd
exit
