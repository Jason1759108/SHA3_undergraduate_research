source [file join [file dirname [info script]] common.tcl]
open_project [file join $entropy_root build reference_final entropy_ref.xpr]
source [file join $entropy_root vivado verify_bd.tcl]
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed"}
