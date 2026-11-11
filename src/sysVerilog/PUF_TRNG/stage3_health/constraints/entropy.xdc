# Intentional RO loops only: properties live in ro_cell.sv, never globally waived.
set meta_d [get_pins -hier -quiet -filter {NAME =~ *sync_meta_reg*/D}]
set_false_path -to $meta_d
