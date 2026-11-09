source [file join [file dirname [info script]] common.tcl]
if {[current_project -quiet] eq ""} {
    open_project [file join $stage1_root build sha3_pynq sha3_pynq.xpr]
}
open_bd_design [get_files design_1.bd]
set aux_pin [get_bd_pins rst_ps7_0_25M/aux_reset_in]
set old_net [get_bd_nets -of_objects $aux_pin]
disconnect_bd_net $old_net $aux_pin
connect_bd_net [get_bd_pins constant_one/dout] $aux_pin
validate_bd_design
source [file join $stage1_root vivado check_aux_reset.tcl]
save_bd_design
generate_target all [get_files design_1.bd]
puts "PASS existing BD repaired. Rebuild before exporting hardware."
