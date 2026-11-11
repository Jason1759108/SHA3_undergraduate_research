source [file join [file dirname [info script]] common.tcl]
if {[current_project -quiet] eq ""} {error "Open the entropy system project first"}
open_bd_design [get_files design_1.bd]
validate_bd_design
proc same_pin_net {a b} {
    set an [get_bd_nets -of_objects [get_bd_pins $a]]
    set bn [get_bd_nets -of_objects [get_bd_pins $b]]
    if {[llength $an]!=1 || $an ne $bn} {error "Incorrect scalar connection: $a -> $b"}
}
proc same_bus_net {a b} {
    set an [get_bd_intf_nets -of_objects [get_bd_intf_pins $a]]
    set bn [get_bd_intf_nets -of_objects [get_bd_intf_pins $b]]
    if {[llength $an]!=1 || $an ne $bn} {error "Incorrect AXI connection: $a -> $b"}
}
set ps [get_bd_cells processing_system7_0]
if {[get_property CONFIG.PCW_USE_M_AXI_GP0 $ps]!=1 || [get_property CONFIG.PCW_USE_S_AXI_HP0 $ps]!=0 || [get_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $ps]!=25} {error "Expected 25 MHz GP0-only PS"}
set reset [get_bd_cells rst_ps7_0_25M]
if {[get_property CONFIG.C_EXT_RESET_HIGH $reset]!=0 || [get_property CONFIG.C_AUX_RESET_HIGH $reset]!=0} {error "Both external and aux reset must be active LOW"}
if {[get_property CONFIG.CONST_VAL [get_bd_cells constant_one]]!=1 || [get_property CONFIG.CONST_VAL [get_bd_cells constant_zero]]!=0} {error "Incorrect constant values"}
foreach c {constant_one constant_zero} {if {[get_property CONFIG.CONST_WIDTH [get_bd_cells $c]]!=1} {error "Constant width must be 1"}}
same_pin_net constant_one/dout rst_ps7_0_25M/aux_reset_in
same_pin_net constant_one/dout rst_ps7_0_25M/dcm_locked
same_pin_net constant_zero/dout rst_ps7_0_25M/mb_debug_sys_rst
same_pin_net processing_system7_0/FCLK_RESET0_N rst_ps7_0_25M/ext_reset_in
foreach pin {processing_system7_0/M_AXI_GP0_ACLK entropy_ip/s_axi_aclk rst_ps7_0_25M/slowest_sync_clk axi_control/ACLK axi_control/S00_ACLK axi_control/M00_ACLK} {same_pin_net processing_system7_0/FCLK_CLK0 $pin}
same_pin_net rst_ps7_0_25M/peripheral_aresetn entropy_ip/s_axi_aresetn
foreach pin {axi_control/ARESETN axi_control/S00_ARESETN axi_control/M00_ARESETN} {same_pin_net rst_ps7_0_25M/interconnect_aresetn $pin}
same_bus_net processing_system7_0/M_AXI_GP0 axi_control/S00_AXI
same_bus_net axi_control/M00_AXI entropy_ip/s_axi
set seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces processing_system7_0/Data] -filter {NAME =~ *entropy*}]
if {[llength $seg]!=1 || [get_property OFFSET $seg]!=0x43c00000} {error "Entropy control must map to 0x43C00000"}
set ent [get_bd_cells entropy_ip]
foreach {param value} {DEPTH 1024 WARMUP 1024 STARTUP_SAMPLES 1024 RCT_C 41 APT_WINDOW 1024 APT_C 793 WATCHDOG 20000000} {
    if {[get_property CONFIG.$param $ent]!=$value} {error "Restore default entropy parameter $param=$value"}
}
if {[llength [get_bd_cells -hier -filter {VLNV =~ xilinx.com:ip:axi_dma:*}]]!=0} {error "No DMA expected in this stage"}
puts "PASS BD GUARD clock reset polarity constants GP0 topology parameters and address"
