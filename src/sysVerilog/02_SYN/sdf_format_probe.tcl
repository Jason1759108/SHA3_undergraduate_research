# Isolated SDF serialization experiment for the already synthesized CE1 V3 10 ns design.
# Does not run compile or write a netlist/DDC. Run only from 02_SYN with its original
# .synopsys_dc.setup and existing SHA3_parity_SYN.ddc.
if {![file exists SHA3_parity_SYN.ddc]} {
    error "Missing SHA3_parity_SYN.ddc; run the original 10 ns synthesis first"
}
read_ddc SHA3_parity_SYN.ddc
current_design sha3_ultra_low_power_top_FT_ENABLE1
link
if {[file exists Netlist/SHA3_parity_SYN_format_probe.sdf]} {
    error "Probe SDF already exists; move it aside before rerunning"
}
write_sdf -version 3.0 -context verilog -load_delay cell -significant_digits 6 -include {SETUPHOLD RECREM} Netlist/SHA3_parity_SYN_format_probe.sdf
if {![file exists Netlist/SHA3_parity_SYN_format_probe.sdf]} {
    error "Alternative SDF was not written"
}
puts "SDF_FORMAT_PROBE_WRITTEN"
quit
