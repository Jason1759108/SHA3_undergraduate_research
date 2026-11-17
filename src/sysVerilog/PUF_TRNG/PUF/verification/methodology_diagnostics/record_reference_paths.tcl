if {[get_param sta.enableClockUncertainty]!=1} {error "Reference must use the original default"}
puts "PUF_REFERENCE_ORIGINAL_DEFAULT clock_uncertainty=[get_param sta.enableClockUncertainty]"
set properties {STARTPOINT_PIN ENDPOINT_PIN STARTPOINT_CLOCK ENDPOINT_CLOCK CORNER DELAY_TYPE EXCEPTION SLACK REQUIREMENT ARRIVAL_TIME REQUIRED_TIME DATAPATH_DELAY SKEW CLOCK_PESSIMISM UNCERTAINTY USER_UNCERTAINTY}
foreach delay_type {max min} {
    set paths [get_timing_paths -delay_type $delay_type -max_paths 200000 -nworst 1]
    set count [llength $paths]
    if {$count==0 || $count>=200000} {error "Empty or truncated path snapshot"}
    array unset values
    foreach property $properties {
        set values($property) [get_property $property $paths]
        if {[llength $values($property)]!=$count} {error "Property count mismatch: $property"}
    }
    set f [open [file join $output paths_${delay_type}.tsv] w]
    puts $f [join $properties "\t"]
    for {set index 0} {$index<$count} {incr index} {
        set row {}
        foreach property $properties {lappend row [lindex $values($property) $index]}
        puts $f [join $row "\t"]
    }
    close $f
    puts "PUF_FULL_PATHS $delay_type $count"
    flush stdout
    unset paths
}
report_timing_summary -report_unconstrained -file [file join $output timing_summary.rpt]
write_xdc -type timing -force [file join $output complete_timing.xdc]
report_clocks -file [file join $output clocks.rpt]
set checks [open [file join $output check_enablement.tsv] w]
foreach check [lsort -dictionary [get_methodology_checks]] {puts $checks "$check\t[get_property IS_ENABLED $check]"}
close $checks
puts "PUF_REFERENCE_PATHS_COMPLETE"
