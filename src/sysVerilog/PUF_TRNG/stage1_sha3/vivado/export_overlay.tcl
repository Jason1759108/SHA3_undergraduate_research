source [file join [file dirname [info script]] common.tcl]
open_bd_design [get_files design_1.bd]
validate_bd_design
source [file join $stage1_root vivado check_aux_reset.tcl]
if {[get_property NEEDS_REFRESH [get_runs synth_1]] || [get_property NEEDS_REFRESH [get_runs impl_1]]} {
    error "The hardware sources changed. Rebuild synthesis and implementation before exporting."
}
set project_root [get_property DIRECTORY [current_project]]
set bit [file join [get_property DIRECTORY [get_runs impl_1]] design_1_wrapper.bit]
set hwh [file join $project_root sha3_pynq.gen sources_1 bd design_1 hw_handoff design_1.hwh]
if {![file exists $bit] || ![file exists $hwh]} {error "The matching bitstream and HWH pair is incomplete."}
set pending [file join $stage1_root build overlay_pending]
file mkdir $pending
file copy -force $bit [file join $pending sha3_pynq.bit]
file copy -force $hwh [file join $pending sha3_pynq.hwh]
file copy -force [file join $stage1_root python sha3_pynq.py] [file join $pending sha3_pynq.py]
file copy -force [file join $stage1_root python SHA3_Bringup.ipynb] [file join $pending SHA3_Bringup.ipynb]
puts [exec python [file join $stage1_root python make_release.py] $pending]
set out [file join $stage1_root build overlay]
file mkdir $out
foreach name {sha3_pynq.bit sha3_pynq.hwh sha3_pynq.py SHA3_Bringup.ipynb release_manifest.json} {
    file copy -force [file join $pending $name] [file join $out $name]
}
puts "SUCCESS overlay files exported to $out"
