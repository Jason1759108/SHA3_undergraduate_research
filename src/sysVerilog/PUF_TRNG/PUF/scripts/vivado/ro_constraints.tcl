# Runs AFTER synthesis / netlist linking and BEFORE opt_design.
# Intentional RO feedback is acknowledged only on each known ring's net.
# No global DRC downgrade, clock-group false path, or timing waiver is used.
proc one_pin {cell pin_name} {
    set p [get_pins -of_objects $cell -filter "REF_PIN_NAME == $pin_name"]
    if {[llength $p] != 1} {error "Expected $cell/$pin_name"}
    return $p
}

# Index the linked netlist once. Avoid thousands of whole-netlist queries when
# applying constraints to 640 RO domains. Exact structural counts fail closed.
array set gates {}; array set inversions {}; array set fixed {}
array set grays {}; array set metas {}
foreach c [get_cells -hier] {
    if {[regexp {.*u_bank/g_ro\[([0-9]+)\][/.]u_ro/u_gate$} $c -> i]} {
        set gates($i) $c
    } elseif {[regexp {.*u_bank/g_ro\[([0-9]+)\][/.]u_ro/g_inv\[([0-9]+)\][/.]u_inv$} $c -> i k]} {
        set inversions($i,$k) $c
    } elseif {[regexp {.*g_counter\[([0-9]+)\][/.]u_counter/(divider|raw_reset|gray)_reg\[([0-9]+)\]$} $c -> i kind k]} {
        if {$kind eq "gray"} {lappend grays($i) $c} else {set fixed($i,$kind,$k) $c}
    } elseif {[regexp {.*u_measure/g_counter\[([0-9]+)\][/.]gray_meta_reg\[[0-9]+\]\[[0-9]+\]$} $c -> i]} {
        lappend metas($i) $c
    }
}
if {[array size gates]!=640 || [array size inversions]!=2560 || [array size fixed]!=3200 || [array size grays]!=640 || [array size metas]!=640} {
    error "Expected exactly 640 rings, 3200 fixed FFs and 640 Gray CDC buses; inspect linked netlist"
}

# Use 320 non-overlapping groups of four vertical SLICEL sites.
# Both ROs in a pair have the same LUT/BEL arrangement, separated by two sites.
# Routing is not fixed; matching and physical PUF quality require board data.
set groups {}
set slicel_sites [lsort -dictionary [get_sites -filter {SITE_TYPE == SLICEL}]]
array set slicel {}
foreach site $slicel_sites {set slicel($site) 1}
foreach site $slicel_sites {
    if {![regexp {SLICE_X([0-9]+)Y([0-9]+)$} $site -> x y]} {continue}
    if {$y < 20 || $y % 4 != 0} {continue}
    set valid 1
    for {set j 0} {$j < 4} {incr j} {
        set other SLICE_X${x}Y[expr {$y+$j}]
        if {![info exists slicel($other)]} {set valid 0; break}
    }
    if {$valid} {lappend groups [list $x $y]}
    if {[llength $groups] == 320} {break}
}
if {[llength $groups] != 320} {error "Could not find 320 SLICEL placement groups on selected part"}

for {set i 0} {$i < 640} {incr i} {
    lassign [lindex $groups [expr {$i/2}]] x y
    set y [expr {$y + 2*($i%2)}]
    set cells [list $gates($i)]
    for {set k 1} {$k < 5} {incr k} {
        lappend cells $inversions($i,$k)
    }
    set bels {A6LUT B6LUT C6LUT D6LUT A6LUT}
    for {set k 0} {$k < 5} {incr k} {
        set c [lindex $cells $k]
        set_property LOC SLICE_X${x}Y[expr {$y+($k==4)}] $c
        set_property BEL [lindex $bels $k] $c
        if {$k==0} {set_property LOCK_PINS {I0:A1 I1:A2} $c} else {set_property LOCK_PINS {I0:A1} $c}
    }
    # The 500 MHz prescaler must remain local to its RO. Divider and reset
    # release flops use separate slices because their reset control sets differ.
    set divider_cells {}
    foreach k {0 1 2} bel {BFF CFF DFF} lut_bel {B6LUT C6LUT D6LUT} {
        set c $fixed($i,divider,$k)
        set_property BEL $bel $c
        lappend divider_cells $c
        # Keep each next-state LUT beside its destination FF. The fifth RO LUT
        # occupies A6LUT here; B/C/D remain available for the three-bit divider.
        set d_net [get_nets -of_objects [one_pin $c D]]
        set drivers [get_pins -leaf -of_objects $d_net -filter {DIRECTION == OUT}]
        set lut [get_cells -of_objects $drivers]
        if {[llength $lut] != 1 || ![string match LUT* [get_property REF_NAME $lut]]} {
            error "RO $i divider bit $k must have one next-state LUT driver"
        }
        set_property LOC SLICE_X${x}Y[expr {$y+1}] $lut
        set_property BEL $lut_bel $lut
    }
    set_property LOC SLICE_X${x}Y[expr {$y+1}] $divider_cells
    set release_cells {}
    foreach k {0 1} bel {AFF BFF} {
        set c $fixed($i,raw_reset,$k)
        set_property BEL $bel $c
        lappend release_cells $c
    }
    set_property LOC SLICE_X${x}Y${y} $release_cells
    set raw_pin [one_pin [lindex $cells 4] O]
    set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -of_objects $raw_pin]
    # 2 ns (500 MHz) is an engineering bound, not an RO frequency prediction.
    create_clock -name ro_raw_$i -period 2.000 $raw_pin
    set div_cell $fixed($i,divider,2)
    set div_pin [one_pin $div_cell Q]
    create_generated_clock -name ro_div_$i -source $raw_pin -divide_by 8 $div_pin

    set gray_cells $grays($i)
    set meta_cells $metas($i)
    if {[llength $gray_cells]!=16 || [llength $meta_cells]!=16} {
        error "RO $i Gray CDC register names changed: inspect synthesized netlist before adapting constraints"
    }
    set source_pins [get_pins -of_objects $gray_cells -filter {REF_PIN_NAME == Q}]
    set dest_pins [get_pins -of_objects $meta_cells -filter {REF_PIN_NAME == D}]
    # Constrain Gray bus routing to less than one fastest divided-clock period.
    # Do NOT override these limits with asynchronous set_clock_groups.
    # Use register CELLS, not their Q pins: a Q-pin startpoint segments Vivado's
    # timing graph and prevents report_bus_skew from finding valid paths.
    set_max_delay -datapath_only 8.000 -from $gray_cells -to $meta_cells
    set_bus_skew 8.000 -from $gray_cells -to $meta_cells
}

# Asynchronous assertion / synchronizer input paths. Keep recovery/removal timing
# enabled from synchronized reset-release outputs to the actual RO counters.
set async_reset_pins [get_pins -hier -filter {REF_PIN_NAME == CLR || REF_PIN_NAME == PRE}]
set async_only {}
foreach p $async_reset_pins {
    if {![regexp {u_counter/(divider|binary|gray)_reg\[[0-9]+\]/CLR$} $p]} {lappend async_only $p}
}
if {[llength $async_only]} {set_false_path -to $async_only}
puts "RO_DIAG: constrained 640 rings, raw/divided clocks and 640 Gray CDC buses."
