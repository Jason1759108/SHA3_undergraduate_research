# Validate the actual constant and polarity after BD parameter propagation.
set aux_reset_cell [get_bd_cells -quiet rst_ps7_0_25M]
if {[llength $aux_reset_cell] != 1} {error "Expected rst_ps7_0_25M in design_1."}
set aux_reset_pin [get_bd_pins $aux_reset_cell/aux_reset_in]
set aux_reset_net [get_bd_nets -of_objects $aux_reset_pin]
set aux_reset_driver [get_bd_pins -of_objects $aux_reset_net -filter {DIR == O}]
if {[llength $aux_reset_driver] != 1} {error "Expected a single constant driver for aux_reset_in."}
set aux_reset_constant [get_bd_cells [file dirname [lindex $aux_reset_driver 0]]]
if {![string match "xilinx.com:ip:xlconstant:*" [get_property VLNV $aux_reset_constant]]} {
    error "Verify the inactive level of aux_reset_in. This project expects an xlconstant driver."
}
set aux_reset_active [get_property CONFIG.C_AUX_RESET_HIGH $aux_reset_cell]
set aux_reset_value [get_property CONFIG.CONST_VAL $aux_reset_constant]
if {[get_property CONFIG.CONST_WIDTH $aux_reset_constant] != 1 || $aux_reset_value ni {0 1}} {
    error "Expected a one-bit constant for aux_reset_in."
}
if {$aux_reset_value == $aux_reset_active} {
    error "aux_reset_in is permanently ASSERTED. Active polarity=$aux_reset_active, constant=$aux_reset_value. Fix the connection before building or exporting."
}
puts "PASS aux_reset_in is inactive: active polarity=$aux_reset_active, constant=$aux_reset_value"
