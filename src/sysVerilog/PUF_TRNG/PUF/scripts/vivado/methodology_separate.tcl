# Run EVERY available methodology check on the exact final routed checkpoint.
# Non-timing checks are recorded individually. Timing checks share one call to
# avoid repeating the expensive clock/timing preparation for every rule.
if {![info exists ::env(RO_DIAG_EXISTING_BUILD)]} {error "Set RO_DIAG_EXISTING_BUILD"}
set build [file normalize $::env(RO_DIAG_EXISTING_BUILD)]
set dcp [file join $build final_routed.dcp]
if {![file exists $dcp]} {error "Missing final routed checkpoint"}
set_param general.maxThreads 2
open_checkpoint $dcp
set directory [file join $build reports methodology_checks]
file mkdir $directory
set identity [list $dcp [file size $dcp] [file mtime $dcp]]
set identity_path [file join $directory checkpoint_identity.txt]
if {[file exists $identity_path]} {
    set old_identity [open $identity_path r]
    set saved_identity [string trim [read $old_identity]]
    close $old_identity
    if {$saved_identity ne $identity} {error "Checkpoint changed; do not reuse old methodology results"}
} else {
    set identity_file [open $identity_path w]
    puts $identity_file $identity
    close $identity_file
}
set identity_tsv [open [file join $directory checkpoint_identity.tsv] w]
puts $identity_tsv "path\t$dcp\nbytes\t[file size $dcp]\nmtime\t[file mtime $dcp]"
close $identity_tsv
array set completed {}
set progress_path [file join $directory progress.tsv]
if {[file exists $progress_path]} {
    set previous [open $progress_path r]
    foreach line [split [read $previous] "\n"] {
        set fields [split $line "\t"]
        if {[llength $fields]>=2 && [lindex $fields 1] eq "DONE"} {
            set completed([lindex $fields 0]) 1
        }
    }
    close $previous
}
set progress [open $progress_path a]
if {[file size $progress_path]==0} {puts $progress "check\tstate\telapsed_seconds\tutc"}
set all_checks [lsort -dictionary [get_methodology_checks]]
set inventory [open [file join $directory requested_checks.txt] w]
puts $inventory [join $all_checks "\n"]
close $inventory
set combined [open [file join $build reports methodology.rpt] a]
puts $combined "Every check below runs against $dcp. See methodology_checks/progress.tsv for coverage and duration."
flush $combined
set groups {}
set timing_checks {}
foreach check $all_checks {
    if {[info exists completed($check)]} {continue}
    if {[string match TIMING-* $check]} {lappend timing_checks $check} else {lappend groups [list $check]}
}
if {[llength $timing_checks]} {lappend groups $timing_checks}
foreach checks $groups {
    set group_name [expr {[llength $checks]>1 ? "TIMING_ALL" : [lindex $checks 0]}]
    if {[string match TIMING* $group_name] && $::tcl_platform(platform) eq "windows" && [version -short] eq "2026.1"} {
        # The option must be set in a fresh Vivado process before loading STA.
        # A separate default reference and full endpoint comparison gate DONE.
        close $combined
        close $progress
        close_project
        set methodology_dir [file dirname [file normalize [info script]]]
        if {[info exists ::env(RO_DIAG_PYTHON)]} {
            set python $::env(RO_DIAG_PYTHON)
        } else {
            set install_root [file dirname $::env(XILINX_VIVADO)]
            set candidates [lsort -dictionary [glob -nocomplain [file join $install_root tps win64 python-* python.exe]]]
            if {![llength $candidates]} {error "Set RO_DIAG_PYTHON to Python 3.11 or later"}
            set python [lindex $candidates end]
        }
        set vivado_cli [file join $::env(XILINX_VIVADO) bin vivado.bat]
        puts "METHODOLOGY_CONSERVATIVE_PIPELINE: original-default reference, all 57 checks, then full endpoint qualification"
        puts [exec $python [file join $methodology_dir run_methodology.py] --build $build --kit [file normalize [file join $methodology_dir .. ..]] --vivado $vivado_cli 2>@1]
        return
    }
    set start [clock seconds]
    puts "METHODOLOGY_GROUP_START $group_name count=[llength $checks]"
    foreach check $checks {
        puts $progress "$check\tSTART\t0\t[clock format $start -gmt 1 -format %Y-%m-%dT%H:%M:%SZ]"
    }
    flush $progress
    set path [file join $directory ${group_name}.rpt]
    report_methodology -checks $checks -file $path
    set finish [clock seconds]
    set file [open $path r]
    puts $combined "\n===== $group_name =====\n[read $file]"
    close $file
    flush $combined
    foreach check $checks {
        puts $progress "$check\tDONE\t[expr {$finish-$start}]\t[clock format $finish -gmt 1 -format %Y-%m-%dT%H:%M:%SZ]"
    }
    flush $progress
    puts "METHODOLOGY_GROUP_DONE $group_name [expr {$finish-$start}]s"
}
close $combined
close $progress
set done [open [file join $directory COMPLETE.txt] w]
puts $done "Completed all [llength $all_checks] checks on $dcp"
close $done
puts "METHODOLOGY_ALL_CHECKS_COMPLETE [llength $all_checks]"
