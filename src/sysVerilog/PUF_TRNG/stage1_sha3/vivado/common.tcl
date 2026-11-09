set stage1_root [file normalize [file join [file dirname [info script]] ..]]
set_param board.repoPaths [list [file join $stage1_root third_party board_files]]
set core_dir [file join $stage1_root rtl core]
set core_names {
    sha3_pkg.sv sha3_ctrl_fsm.sv sha3_pad_domain.sv sha3_absorb_xor.sv
    keccak_round_scheduler.sv keccak_parity_predictor.sv keccak_theta_serial.sv
    keccak_rho_pi_wire.sv keccak_chi_row.sv keccak_iota.sv keccak_lane_parity.sv
    sha3_output_formatter.sv keccak_state_bank.sv sha3_ultra_low_power_top.sv
}
set rtl_files {}
foreach name $core_names {lappend rtl_files [file join $core_dir $name]}
lappend rtl_files [file join $stage1_root rtl sha3_axis_top.sv]

proc add_stage1_rtl {} {
    global rtl_files
    add_files -norecurse $rtl_files
    set_property top sha3_axis_top [current_fileset]
    update_compile_order -fileset sources_1
}
