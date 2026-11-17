# Defer the AUTOMATIC report job, never disable a methodology rule. build.tcl
# runs every rule separately after saving/exporting the exact routed checkpoint.
set deferred_reports 0
foreach report [get_report_configs -of_objects [get_runs impl_1]] {
    if {[get_property REPORT_TYPE $report] eq "report_methodology:1.0"} {
        set_property IS_ENABLED false $report
        incr deferred_reports
    }
}
if {$deferred_reports != 1} {error "Expected one automatic routed methodology report; inspect Vivado report configuration"}
puts "Deferred one automatic report job. Methodology RULE enablement is unchanged."
