# Author verification only; the student follows GUI instructions.
source [file join [file dirname [info script]] common.tcl]
source [file join $entropy_root vivado package_ip.tcl]
create_project entropy_ref [file join $entropy_root build reference_final] -part xc7z020clg400-1
set_property board_part [lindex [get_board_parts *pynq-z2*] end] [current_project]
set_property ip_repo_paths [list [file join $entropy_root build ip_repo]] [current_project]
update_ip_catalog
create_bd_design design_1
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_M_AXI_GP0_FREQMHZ {25} CONFIG.PCW_USE_M_AXI_GP0 {1} CONFIG.PCW_USE_S_AXI_HP0 {0} CONFIG.PCW_EN_CLK0_PORT {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {25}] [get_bd_cells processing_system7_0]
create_bd_cell -type ip -vlnv research.local:user:entropy_health_axi:1.0 entropy_ip
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_control
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_control]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_25M
set_property -dict [list CONFIG.C_EXT_RESET_HIGH {0} CONFIG.C_AUX_RESET_HIGH {0}] [get_bd_cells rst_ps7_0_25M]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_one
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_zero
set_property CONFIG.CONST_VAL {0} [get_bd_cells constant_zero]
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_control/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_control/M00_AXI] [get_bd_intf_pins entropy_ip/s_axi]
connect_bd_net [get_bd_pins constant_one/dout] [get_bd_pins rst_ps7_0_25M/aux_reset_in] [get_bd_pins rst_ps7_0_25M/dcm_locked]
connect_bd_net [get_bd_pins constant_zero/dout] [get_bd_pins rst_ps7_0_25M/mb_debug_sys_rst]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_25M/ext_reset_in]
foreach pin {processing_system7_0/M_AXI_GP0_ACLK entropy_ip/s_axi_aclk rst_ps7_0_25M/slowest_sync_clk axi_control/ACLK axi_control/S00_ACLK axi_control/M00_ACLK} {connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins $pin]}
connect_bd_net [get_bd_pins rst_ps7_0_25M/peripheral_aresetn] [get_bd_pins entropy_ip/s_axi_aresetn]
foreach pin {axi_control/ARESETN axi_control/S00_ARESETN axi_control/M00_ARESETN} {connect_bd_net [get_bd_pins rst_ps7_0_25M/interconnect_aresetn] [get_bd_pins $pin]}
assign_bd_address
set seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces processing_system7_0/Data] -filter {NAME =~ *entropy*}]
set_property offset 0x43C00000 $seg
set_property range 64K $seg
regenerate_bd_layout
validate_bd_design
save_bd_design
generate_target all [get_files design_1.bd]
add_files -norecurse [make_wrapper -files [get_files design_1.bd] -top]
add_files -fileset constrs_1 -norecurse [file join $entropy_root constraints entropy.xdc]
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1
puts "PASS reference BD ready"
