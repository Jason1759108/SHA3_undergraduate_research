source [file join [file dirname [info script]] common.tcl]
set build_dir [file join $stage1_root build]
set package_dir [file join $build_dir ip_repo sha3_axis_top]
set project_dir [file join $build_dir sha3_pynq]
if {[file exists [file join $project_dir sha3_pynq.xpr]]} {
    error "Project already exists. Open build/sha3_pynq/sha3_pynq.xpr to continue."
}
set_param board.repoPaths [list [file join $stage1_root third_party board_files]]
set boards [get_board_parts -quiet *pynq-z2*]
if {[llength $boards] == 0} {error "PYNQ-Z2 board definition was not loaded from third_party/board_files."}
set board [lindex $boards end]

# Package the RTL exactly as in the lecture's Create and Package New IP flow.
create_project sha3_pack [file join $build_dir ip_pack] -part xc7z020clg400-1 -force
add_stage1_rtl
ipx::package_project -root_dir $package_dir -vendor research.local -library user -taxonomy /UserIP -import_files -set_current true
set core [ipx::current_core]
set_property name sha3_axis_top $core
set_property display_name {SHA3-256 buffered AXI Stream} $core
set_property version 1.0 $core
ipx::associate_bus_interfaces -busif S_AXIS -clock axis_aclk $core
ipx::associate_bus_interfaces -busif M_AXIS -clock axis_aclk $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
close_project

create_project sha3_pynq $project_dir -part xc7z020clg400-1
set_property board_part $board [current_project]
set_property ip_repo_paths [list [file join $build_dir ip_repo]] [current_project]
update_ip_catalog
create_bd_design design_1
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
    make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"
} [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1} CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {25.000000}] [get_bd_cells processing_system7_0]

create_bd_cell -type hier sha3
create_bd_cell -type ip -vlnv research.local:user:sha3_axis_top:1.0 sha3/sha3_ip
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 sha3/sha3_dma
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} \
    CONFIG.c_addr_width {32} CONFIG.c_m_axi_mm2s_data_width {32} \
    CONFIG.c_m_axi_s2mm_data_width {32} CONFIG.c_m_axis_mm2s_tdata_width {32} \
    CONFIG.c_s_axis_s2mm_tdata_width {32} CONFIG.c_mm2s_burst_size {16} \
    CONFIG.c_s2mm_burst_size {16} CONFIG.c_include_mm2s_dre {0} CONFIG.c_include_s2mm_dre {0}] \
    [get_bd_cells sha3/sha3_dma]
connect_bd_intf_net [get_bd_intf_pins sha3/sha3_dma/M_AXIS_MM2S] [get_bd_intf_pins sha3/sha3_ip/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins sha3/sha3_ip/M_AXIS] [get_bd_intf_pins sha3/sha3_dma/S_AXIS_S2MM]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_control
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_control]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_memory
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] [get_bd_cells axi_memory]
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_control/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_control/M00_AXI] [get_bd_intf_pins sha3/sha3_dma/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins sha3/sha3_dma/M_AXI_MM2S] [get_bd_intf_pins axi_memory/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins sha3/sha3_dma/M_AXI_S2MM] [get_bd_intf_pins axi_memory/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_memory/M00_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_25M
# Reset polarity is propagated from the PS FCLK_RESET0_N active-low interface.
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_one
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_zero
set_property CONFIG.CONST_VAL {0} [get_bd_cells constant_zero]
connect_bd_net [get_bd_pins constant_one/dout] [get_bd_pins rst_ps7_0_25M/dcm_locked] [get_bd_pins rst_ps7_0_25M/aux_reset_in]
connect_bd_net [get_bd_pins constant_zero/dout] [get_bd_pins rst_ps7_0_25M/mb_debug_sys_rst]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_25M/ext_reset_in]
set clock_pins {
    processing_system7_0/M_AXI_GP0_ACLK processing_system7_0/S_AXI_HP0_ACLK
    sha3/sha3_dma/s_axi_lite_aclk sha3/sha3_dma/m_axi_mm2s_aclk sha3/sha3_dma/m_axi_s2mm_aclk
    sha3/sha3_ip/axis_aclk rst_ps7_0_25M/slowest_sync_clk
    axi_control/ACLK axi_control/S00_ACLK axi_control/M00_ACLK
    axi_memory/ACLK axi_memory/S00_ACLK axi_memory/S01_ACLK axi_memory/M00_ACLK
}
foreach pin $clock_pins {connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins $pin]}
foreach pin {sha3/sha3_dma/axi_resetn sha3/sha3_ip/axis_aresetn} {
    connect_bd_net [get_bd_pins rst_ps7_0_25M/peripheral_aresetn] [get_bd_pins $pin]
}
foreach pin {
    axi_control/ARESETN axi_control/S00_ARESETN axi_control/M00_ARESETN
    axi_memory/ARESETN axi_memory/S00_ARESETN axi_memory/S01_ARESETN axi_memory/M00_ARESETN
} {connect_bd_net [get_bd_pins rst_ps7_0_25M/interconnect_aresetn] [get_bd_pins $pin]}
assign_bd_address
regenerate_bd_layout
validate_bd_design
source [file join $stage1_root vivado check_aux_reset.tcl]
save_bd_design
set bd_file [get_files design_1.bd]
generate_target all $bd_file
set wrapper [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1
puts "SUCCESS project created. Open the block design, then Generate Bitstream or source build_bitstream.tcl."
