# Performance reproduction only. keep_ro < 640 intentionally creates an
# incomplete timing model and MUST NEVER qualify or export hardware.
set checkpoint [file normalize $::env(PUF_PROBE_CHECKPOINT)]
set output [file normalize $::env(PUF_PROBE_OUTPUT)]
set keep_ro $::env(PUF_PROBE_KEEP_RO)
file mkdir $output
set_param general.maxThreads $::env(PUF_PROBE_THREADS)
puts "PUF_PROBE_PID [pid]"
flush stdout
if {[info exists ::env(PUF_PROBE_PRE_OPEN_TCL)] && $::env(PUF_PROBE_PRE_OPEN_TCL) ne ""} {source $::env(PUF_PROBE_PRE_OPEN_TCL)}
set restore_mode [expr {[info exists ::env(PUF_PROBE_RESTORE_XDC)] && $::env(PUF_PROBE_RESTORE_XDC) ne ""}]
if {$restore_mode} {
    if {$keep_ro>=0 || $::env(PUF_PROBE_GROUP_RO) eq "1" || $::env(PUF_PROBE_STOP_FEEDBACK) eq "1" || $::env(PUF_PROBE_EXPLICIT_INPUT_JITTER) eq "1" || $::env(PUF_PROBE_SETUP_TCL) ne ""} {error "Do not combine cold restore with other probes"}
    open_checkpoint -ignore_timing $checkpoint
    if {[llength [get_clocks -quiet]]!=0} {error "Timing was not fully ignored before restoration"}
    source $::env(PUF_PROBE_RESTORE_XDC)
    # Clock enumeration can force lazy preparation. Audit AFTER the report.
    set original_clocks deferred
} else {
    open_checkpoint $checkpoint
    set original_clocks [llength [get_clocks]]
}
if {$keep_ro>=0} {
    set original_xdc [file join $output original_timing.xdc]
    write_xdc -type timing -force $original_xdc
    set input [open $original_xdc r]
    set text [read $input]
    close $input
    set filtered [open [file join $output reduced_timing.tcl] w]
    set command {}
    set removed 0
    foreach line [split $text "\n"] {
        append command $line "\n"
        if {![info complete $command]} {continue}
        set skip 0
        if {[regexp {^\s*create_(?:generated_)?clock\s} $command] &&
            [regexp -- {-name\s+(?:\{|\")?(ro_(?:raw|div)_([0-9]+))} $command -> name index] &&
            $index >= $keep_ro} {
            set skip 1
            incr removed
        }
        if {!$skip} {puts -nonewline $filtered $command}
        set command {}
    }
    if {[string trim $command] ne ""} {error "Incomplete exported timing command"}
    close $filtered
    reset_timing
    source [file join $output reduced_timing.tcl]
    set expected [expr {$original_clocks-$removed}]
    if {[llength [get_clocks]] != $expected || $expected != 2*$keep_ro+1} {
        error "Unexpected diagnostic clock count"
    }
}
if {$restore_mode} {set remaining_clocks deferred} else {set remaining_clocks [llength [get_clocks]]}
if {$::env(PUF_PROBE_GROUP_RO) eq "1"} {
    if {$keep_ro>=0} {error "Do not combine independent probes"}
    source [file join [file dirname [info script]] ro_clock_relationships.tcl]
}
if {$::env(PUF_PROBE_STOP_FEEDBACK) eq "1"} {
    if {$keep_ro>=0 || $::env(PUF_PROBE_GROUP_RO) eq "1"} {error "Do not combine independent probes"}
    set feedback_pins [get_pins -hier -filter {NAME =~ *u_bank/g_ro* && NAME =~ */u_gate/I0}]
    if {[llength $feedback_pins]!=640} {error "Expected exactly 640 feedback input pins"}
    set_clock_sense -stop_propagation $feedback_pins
    puts "PUF_PROBE_FEEDBACK_STOP [llength $feedback_pins]"
}
if {$::env(PUF_PROBE_EXPLICIT_INPUT_JITTER) eq "1"} {
    if {$keep_ro>=0 || $::env(PUF_PROBE_GROUP_RO) eq "1" || $::env(PUF_PROBE_STOP_FEEDBACK) eq "1"} {error "Do not combine independent probes"}
    set raw_clocks [get_clocks -regexp {ro_raw_[0-9]+}]
    if {[llength $raw_clocks]!=640} {error "Expected 640 raw clocks"}
    set saved_jitter {}
    set saved_system_jitter [get_property SYSTEM_JITTER [lindex $raw_clocks 0]]
    foreach c $raw_clocks {
        set jitter [get_property INPUT_JITTER $c]
        if {$jitter eq ""} {error "Missing original input jitter property"}
        dict set saved_jitter $c $jitter
        set_input_jitter $c $jitter
    }
    foreach c $raw_clocks {
        if {abs([get_property INPUT_JITTER $c]-[dict get $saved_jitter $c])>1e-12} {error "Input jitter changed"}
    }
    if {[get_property SYSTEM_JITTER [lindex $raw_clocks 0]] ne $saved_system_jitter} {error "System jitter changed"}
    puts "PUF_PROBE_EXPLICIT_JITTER 640 clocks, input/system values unchanged; system=$saved_system_jitter"
}
if {[info exists ::env(PUF_PROBE_SETUP_TCL)] && $::env(PUF_PROBE_SETUP_TCL) ne ""} {
    source $::env(PUF_PROBE_SETUP_TCL)
}
set requested [get_methodology_checks $::env(PUF_PROBE_CHECKS)]
set inventory [open [file join $output requested_checks.txt] w]
puts $inventory [join [lsort -dictionary $requested] "\n"]
close $inventory
puts "PUF_PROBE_READY clocks=$remaining_clocks original=$original_clocks keep_ro=$keep_ro"
flush stdout
set started [clock milliseconds]
report_methodology -checks $requested -file [file join $output report.rpt]
if {[info exists ::env(PUF_PROBE_POST_TCL)] && $::env(PUF_PROBE_POST_TCL) ne ""} {source $::env(PUF_PROBE_POST_TCL)}
if {$restore_mode} {
    set audited [lsort -dictionary [get_clocks]]
    set audit [open [file join $output clock_audit.tsv] w]
    foreach c $audited {puts $audit "$c\t[get_property PERIOD $c]\t[get_property WAVEFORM $c]\t[get_property IS_GENERATED $c]"}
    close $audit
    puts "PUF_PROBE_CLOCK_AUDIT [llength $audited]"
    write_xdc -type timing -force [file join $output restored_timing.xdc]
}
puts "PUF_PROBE_DONE elapsed_ms=[expr {[clock milliseconds]-$started}]"
flush stdout
