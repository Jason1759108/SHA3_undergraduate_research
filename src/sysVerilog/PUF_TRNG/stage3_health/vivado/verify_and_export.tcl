source [file join [file dirname [info script]] common.tcl]
source [file join $entropy_root vivado verify_bd.tcl]
if {[get_property NEEDS_REFRESH [get_runs synth_1]] || [get_property NEEDS_REFRESH [get_runs impl_1]] || ![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {error "Generate a fresh bitstream first"}
open_run impl_1
set reports [file join $entropy_root build reports [get_property NAME [current_project]]]
file mkdir $reports
report_timing_summary -report_unconstrained -file [file join $reports timing.rpt]
report_drc -file [file join $reports drc.rpt]
report_methodology -file [file join $reports methodology.rpt]
report_cdc -file [file join $reports cdc.rpt]
report_utilization -file [file join $reports utilization.rpt]
report_clocks -file [file join $reports clocks.rpt]
set setup [get_timing_paths -delay_type max -max_paths 1]
set hold [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup]==0 || [llength $hold]==0 || [get_property SLACK $setup]<0 || [get_property SLACK $hold]<0} {error "Timing has not passed"}
set bad [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
if {[llength $bad]} {error "Unresolved critical DRC: $bad"}
# Audit actual physical LUT primitives, not the behavioral simulation source.
set gates [get_cells -hier -quiet -filter {NAME =~ *u_bank*g_ro*u_ro/u_gate && REF_NAME == LUT2}]
set invs [get_cells -hier -quiet -filter {NAME =~ *u_bank*g_ro*u_ro/g_inv*u_inv && REF_NAME == LUT1}]
if {[llength $gates]!=8 || [llength $invs]!=88} {error "Physical RO topology missing/optimized: gates=[llength $gates] invs=[llength $invs]"}
for {set k 0} {$k<8} {incr k} {
    set tag [format {g_ro[%d].u_ro/} $k]
    set count 0
    foreach c $invs {if {[string first $tag $c]>=0} {incr count}}
    if {$count != 4+2*$k} {error "Wrong physical length in RO $k"}
}
if {[llength [get_files -quiet -of_objects [get_filesets constrs_1] -filter {NAME =~ *entropy.xdc}]]!=1} {error "Add entropy.xdc to the system project constraints"}
foreach g $gates {if {[get_property INIT $g] ne "4'h7"} {error "Unexpected NAND INIT on $g"}}
set metas [get_cells -hier -quiet -filter {NAME =~ *sync_meta_reg*}]
set syncs [get_cells -hier -quiet -filter {NAME =~ *sync_data_reg*}]
if {[llength $metas]!=8 || [llength $syncs]!=8} {error "Expected two synchronizer stages on 8 channels"}
foreach c [concat $metas $syncs] {if {![get_property ASYNC_REG $c]} {error "Missing ASYNC_REG on $c"}}
set pending [file join $entropy_root build overlay_pending]
file mkdir $pending
set project_dir [get_property DIRECTORY [current_project]]
set pname [get_property NAME [current_project]]
set hwh [file join $project_dir $pname.gen sources_1 bd design_1 hw_handoff design_1.hwh]
set bit [file join [get_property DIRECTORY [get_runs impl_1]] design_1_wrapper.bit]
file copy -force $bit [file join $pending entropy_health.bit]
file copy -force $hwh [file join $pending entropy_health.hwh]
foreach name {entropy_health_pynq.py analyze_raw.py entropy_characterize.py entropy_campaign.py Entropy_Health_Bringup.ipynb} {file copy -force [file join $entropy_root python $name] [file join $pending $name]}
set af [open [file join $pending physical_audit.json] w]
puts $af "{\"ro_gates\":8,\"ro_inverters\":88,\"synchronizer_flops\":16,\"wns_ns\":[get_property SLACK $setup],\"whs_ns\":[get_property SLACK $hold]}"
close $af
puts [exec python [file join $entropy_root python make_release.py] $pending $project_dir $pname]
set out [file join $entropy_root build overlay]
file mkdir $out
foreach name {entropy_health.bit entropy_health.hwh entropy_health_pynq.py analyze_raw.py entropy_characterize.py entropy_campaign.py Entropy_Health_Bringup.ipynb release_manifest.json} {file copy -force [file join $pending $name] [file join $out $name]}
puts "SUCCESS ENTROPY RELEASE EXPORTED $out"
