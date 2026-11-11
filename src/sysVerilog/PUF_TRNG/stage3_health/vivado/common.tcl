set entropy_root [file normalize [file join [file dirname [info script]] ..]]
set_param board.repoPaths [list [file join $entropy_root .. stage1_sha3 third_party board_files]]
set rtl_files [list [file join $entropy_root rtl ro_cell.sv] [file join $entropy_root rtl ro_bank.sv] [file join $entropy_root rtl entropy_axi.sv] [file join $entropy_root rtl entropy_health_monitor.sv]]
