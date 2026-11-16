source [file join [file dirname [info script]] common.tcl]
if {[current_project -quiet] eq ""} {error "Open the entropy system project first"}
open_bd_design [get_files design_1.bd]
validate_bd_design
# Walk net aliases across hierarchical boundary pins without traversing IP logic.
proc connected_net {a b intf} {
    if {$intf} {set nc get_bd_intf_nets; set pc get_bd_intf_pins} else {set nc get_bd_nets; set pc get_bd_pins}
    set queue [$nc -boundary_type both -of_objects [$pc $a]]
    set targets [$nc -boundary_type both -of_objects [$pc $b]]
    set seen {}
    while {[llength $queue]} {
        set n [lindex $queue 0]; set queue [lrange $queue 1 end]
        if {[lsearch -exact $targets $n]>=0} {return}
        if {[lsearch -exact $seen $n]>=0} {continue}
        lappend seen $n
        foreach pin [$pc -of_objects $n] {
            foreach alias [$nc -boundary_type both -of_objects $pin] {
                if {[lsearch -exact $seen $alias]<0} {lappend queue $alias}
            }
        }
    }
    error "Incorrect connection: $a -> $b"
}
proc same_pin_net {a b} {connected_net $a $b 0}
proc same_bus_net {a b} {connected_net $a $b 1}
set ps [get_bd_cells processing_system7_0]
if {[get_property CONFIG.PCW_USE_M_AXI_GP0 $ps]!=1 || [get_property CONFIG.PCW_USE_S_AXI_HP0 $ps]!=1 || [get_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $ps]!=25} {error "Expected 25 MHz GP0+HP0 PS"}
set reset [get_bd_cells rst_ps7_0_25M]
if {[get_property CONFIG.C_EXT_RESET_HIGH $reset]!=0 || [get_property CONFIG.C_AUX_RESET_HIGH $reset]!=0} {error "Both external and aux reset must be active LOW"}
if {[get_property CONFIG.CONST_VAL [get_bd_cells constant_one]]!=1 || [get_property CONFIG.CONST_VAL [get_bd_cells constant_zero]]!=0} {error "Incorrect constant values"}
foreach c {constant_one constant_zero} {if {[get_property CONFIG.CONST_WIDTH [get_bd_cells $c]]!=1} {error "Constant width must be 1"}}
same_pin_net constant_one/dout rst_ps7_0_25M/aux_reset_in
same_pin_net constant_one/dout rst_ps7_0_25M/dcm_locked
same_pin_net constant_zero/dout rst_ps7_0_25M/mb_debug_sys_rst
same_pin_net processing_system7_0/FCLK_RESET0_N rst_ps7_0_25M/ext_reset_in
foreach pin {processing_system7_0/M_AXI_GP0_ACLK entropy_ip/s_axi_aclk rst_ps7_0_25M/slowest_sync_clk axi_control/ACLK axi_control/S00_ACLK axi_control/M00_ACLK axi_control/M01_ACLK axi_memory/ACLK axi_memory/S00_ACLK axi_memory/S01_ACLK axi_memory/M00_ACLK processing_system7_0/S_AXI_HP0_ACLK sha3/sha3_dma/s_axi_lite_aclk sha3/sha3_dma/m_axi_mm2s_aclk sha3/sha3_dma/m_axi_s2mm_aclk sha3/sha3_ip/axis_aclk} {same_pin_net processing_system7_0/FCLK_CLK0 $pin}
same_pin_net rst_ps7_0_25M/peripheral_aresetn entropy_ip/s_axi_aresetn
foreach pin {axi_control/ARESETN axi_control/S00_ARESETN axi_control/M00_ARESETN axi_control/M01_ARESETN axi_memory/ARESETN axi_memory/S00_ARESETN axi_memory/S01_ARESETN axi_memory/M00_ARESETN} {same_pin_net rst_ps7_0_25M/interconnect_aresetn $pin}
same_bus_net processing_system7_0/M_AXI_GP0 axi_control/S00_AXI
same_bus_net axi_control/M01_AXI entropy_ip/s_axi
set seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces processing_system7_0/Data] -filter {NAME =~ *entropy*}]
if {[llength $seg]!=1 || [get_property OFFSET $seg]!=0x43c00000} {error "Entropy control must map to 0x43C00000"}
set ent [get_bd_cells entropy_ip]
foreach {param value} {DEPTH 1024 WARMUP 1024 STARTUP_SAMPLES 1024 RCT_C 41 APT_WINDOW 1024 APT_C 793 WATCHDOG 20000000} {
    if {[get_property CONFIG.$param $ent]!=$value} {error "Restore default entropy parameter $param=$value"}
}
same_pin_net rst_ps7_0_25M/peripheral_aresetn sha3/sha3_dma/axi_resetn
same_pin_net rst_ps7_0_25M/peripheral_aresetn sha3/sha3_ip/axis_aresetn
same_bus_net axi_control/M00_AXI sha3/sha3_dma/S_AXI_LITE
same_bus_net sha3/sha3_dma/M_AXIS_MM2S sha3/sha3_ip/S_AXIS
same_bus_net sha3/sha3_ip/M_AXIS sha3/sha3_dma/S_AXIS_S2MM
same_bus_net sha3/sha3_dma/M_AXI_MM2S axi_memory/S00_AXI
same_bus_net sha3/sha3_dma/M_AXI_S2MM axi_memory/S01_AXI
same_bus_net axi_memory/M00_AXI processing_system7_0/S_AXI_HP0
set dma [get_bd_cells sha3/sha3_dma]
foreach {param value} {c_include_sg 0 c_addr_width 32 c_m_axis_mm2s_tdata_width 32 c_s_axis_s2mm_tdata_width 32 c_include_mm2s 1 c_include_s2mm 1} {
 if {[get_property CONFIG.$param $dma]!=$value} {error "DMA configuration mismatch $param"}
}
if {[get_property CONFIG.NUM_MI [get_bd_cells axi_control]]!=2} {error "Need two GP0 slaves"}
set dma_seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces processing_system7_0/Data] -filter {NAME =~ *sha3_dma*}]
if {[llength $dma_seg]!=1 || [get_property OFFSET $dma_seg]!=0x40400000} {error "DMA control address"}
puts "PASS COMBINED BD clock reset source DMA stream HP0 and address guard"
