# Run in Vivado Tcl Console: source C:/.../scripts/vivado/build.tcl
# Or: vivado -mode batch -source scripts/vivado/build.tcl
# Needs a PYNQ-Z2 board definition installed in this Vivado version.
set root [file normalize [file join [file dirname [info script]] .. ..]]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set build [file join $root build vivado_$stamp]
if {[info exists ::env(RO_DIAG_BUILD_ROOT)]} {
    set build [file normalize [file join $::env(RO_DIAG_BUILD_ROOT) vivado_$stamp]]
}
if {[file exists $build]} {error "Build folder already exists: $build"}
file mkdir $build
set jobs 4
if {[info exists ::env(RO_DIAG_JOBS)]} {set jobs $::env(RO_DIAG_JOBS)}
if {![string is integer -strict $jobs] || $jobs<1} {error "RO_DIAG_JOBS must be a positive integer"}
set bundled_boards [file join $root scripts/vivado board_files]
if {[file isdirectory $bundled_boards]} {
    set_param board.repoPaths [concat [get_param board.repoPaths] [list $bundled_boards]]
}
set boards [lsort [get_board_parts -quiet *:pynq-z2:*]]
if {![llength $boards]} {
    error "PYNQ-Z2 board files not installed. Install TUL PYNQ-Z2 board files, restart Vivado, and rerun. Build folder: $build"
}
set board [lindex $boards end]
set part xc7z020clg400-1
set repo [file join $build ip_repo]

# Package only sources belonging to this diagnostic kit.
create_project puf256_ip [file join $build ip_project] -part $part
set_property board_part $board [current_project]
foreach name {puf_types puf_sketch puf_core puf_device ro_edge_counter ro_measure puf_axi ro_lut_cell ro_bank puf_fpga_top} {
    read_verilog -sv [file join $root rtl ${name}.sv]
}
set_property top puf_fpga_top [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir [file join $repo puf256] -vendor user.org -library user -taxonomy /UserIP -import_files -set_current true
set core [ipx::current_core]
set_property name puf256 $core
set_property display_name {RO PUF256} $core
set_property version 1.0 $core
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
set bus [ipx::get_bus_interfaces S_AXI -of_objects $core]
if {[llength $bus]!=1} {error "AXI interface inference failed"}
set proto [ipx::get_bus_parameters PROTOCOL -of_objects $bus]
if {![llength $proto]} {set proto [ipx::add_bus_parameter PROTOCOL $bus]}
set_property value AXI4LITE $proto
ipx::associate_bus_interfaces -busif S_AXI -clock s_axi_aclk $core
set mmap [ipx::get_memory_maps S_AXI -of_objects $core]
if {![llength $mmap]} {set mmap [ipx::add_memory_map S_AXI $core]}
set_property slave_memory_map_ref S_AXI $bus
foreach old [ipx::get_address_blocks -of_objects $mmap] {ipx::remove_address_block [get_property name $old] $mmap}
set block [ipx::add_address_block regs $mmap]
set_property base_address 0 $block
set_property range 4096 $block
set_property width 32 $block
set_property usage register $block
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
close_project

# Optional integration handoff: produce the reusable AXI IP without rebuilding PS7.
if {[info exists ::env(PUF_PACKAGE_ONLY)] && $::env(PUF_PACKAGE_ONLY) eq "1"} {
    puts "PUF_IP_PACKAGE_COMPLETE $repo"
    return
}

create_project puf256 [file join $build project] -part $part
set_property board_part $board [current_project]
set_property ip_repo_paths $repo [current_project]
update_ip_catalog
create_bd_design design_1
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} [get_bd_cells ps7]
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1} CONFIG.PCW_EN_CLK0_PORT {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100.000000}] [get_bd_cells ps7]
create_bd_cell -type ip -vlnv user.org:user:puf256:1.0 puf256_0
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi
set_property CONFIG.NUM_MI 1 [get_bd_cells axi]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset
# Reset polarity is propagated from PS7 FCLK_RESET0_N by IP Integrator.
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
set_property CONFIG.CONST_VAL 1 [get_bd_cells one]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero
set_property CONFIG.CONST_VAL 0 [get_bd_cells zero]
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins axi/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi/M00_AXI] [get_bd_intf_pins puf256_0/S_AXI]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins ps7/M_AXI_GP0_ACLK] [get_bd_pins axi/ACLK] [get_bd_pins axi/S00_ACLK] [get_bd_pins axi/M00_ACLK] [get_bd_pins reset/slowest_sync_clk] [get_bd_pins puf256_0/s_axi_aclk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins reset/ext_reset_in] [get_bd_pins reset/aux_reset_in]
connect_bd_net [get_bd_pins one/dout] [get_bd_pins reset/dcm_locked]
connect_bd_net [get_bd_pins zero/dout] [get_bd_pins reset/mb_debug_sys_rst]
# Both reset inputs follow the PS's active-low reset; never tie an active-low
# auxiliary reset to zero, which would hold the entire AXI subsystem in reset.
connect_bd_net [get_bd_pins reset/interconnect_aresetn] [get_bd_pins axi/ARESETN] [get_bd_pins axi/S00_ARESETN] [get_bd_pins axi/M00_ARESETN]
connect_bd_net [get_bd_pins reset/peripheral_aresetn] [get_bd_pins puf256_0/s_axi_aresetn]
assign_bd_address -offset 0x43C00000 -range 4K -target_address_space [get_bd_addr_spaces ps7/Data] [get_bd_addr_segs puf256_0/S_AXI/regs]
validate_bd_design
if {[get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells reset]] != 0} {
    error "PS FCLK_RESET0_N must feed an active-low auxiliary reset input"
}
if {[get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells reset]] != 0} {
    error "PS FCLK_RESET0_N must feed an active-low external reset input"
}
save_bd_design
set bd [get_files design_1.bd]
# Keep the entire netlist available for RO placement/CDC constraints.
set_property synth_checkpoint_mode None $bd
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files -norecurse $wrapper
set_property top design_1_wrapper [current_fileset]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $root scripts/vivado ro_constraints.tcl] [get_runs impl_1]
if {[info exists ::env(PUF_BD_ONLY)] && $::env(PUF_BD_ONLY) eq "1"} {
    puts "PUF_BLOCK_DESIGN_COMPLETE $build"
    close_project
    return
}
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {![string match {*Complete*} [get_property STATUS [get_runs synth_1]]]} {error "Synthesis failed; inspect $build/project"}
source [file join $root scripts/vivado configure_reports.tcl]
launch_runs impl_1 -to_step route_design -jobs $jobs
wait_on_run impl_1
if {![string match {*Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed; inspect $build/project"}
set ::env(RO_DIAG_DEFER_METHODOLOGY) 1
source [file join $root scripts/vivado export.tcl]
set ::env(RO_DIAG_EXISTING_BUILD) $build
close_project
source [file join $root scripts/vivado methodology_separate.tcl]
