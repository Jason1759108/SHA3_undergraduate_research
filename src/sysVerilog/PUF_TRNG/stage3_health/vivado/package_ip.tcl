source [file join [file dirname [info script]] common.tcl]
if {[current_project -quiet] ne ""} {error "Close the current project before packaging"}
create_project entropy_pack [file join $entropy_root build package_project] -part xc7z020clg400-1 -force
add_files -norecurse $rtl_files
set_property top entropy_axi [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir [file join $entropy_root build ip_repo entropy_axi] -vendor research.local -library user -taxonomy /UserIP -import_files -set_current true
set core [ipx::current_core]
set_property name entropy_health_axi $core
set_property display_name {Health-monitored RO capture - startup RCT APT} $core
set_property version 1.0 $core
ipx::associate_bus_interfaces -busif s_axi -clock s_axi_aclk $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
close_project
puts "PASS entropy IP packaged"
