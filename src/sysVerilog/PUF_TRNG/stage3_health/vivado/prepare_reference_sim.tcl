source [file join [file dirname [info script]] common.tcl]
open_project [file join $entropy_root build reference_final entropy_ref.xpr]
source [file join $entropy_root vivado verify_bd.tcl]
source [file join $entropy_root vivado prepare_system_sim.tcl]
