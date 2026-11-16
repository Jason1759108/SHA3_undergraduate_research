source [file join [file dirname [info script]] common.tcl]
open_project [file join $stage4_root build trng_integrated trng_integrated.xpr]
open_bd_design [get_files design_1.bd]
source [file join $stage4_root vivado verify_bd.tcl]
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed"}
source [file join $stage4_root vivado audit.tcl]
