source [file join [file dirname [info script]] common.tcl]
open_project [file join $stage1_root build sha3_pynq sha3_pynq.xpr]
set_property board_part [lindex [get_board_parts *pynq-z2*] end] [current_project]
open_bd_design [get_files design_1.bd]
