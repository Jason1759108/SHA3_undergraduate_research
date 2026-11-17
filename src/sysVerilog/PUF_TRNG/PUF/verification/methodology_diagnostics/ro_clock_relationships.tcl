# The 640 physical oscillators have no phase relationship with one another.
# Keep each raw clock WITH its own /8 generated clock. SYSTEM CLOCKS ARE NOT
# MEMBERS OF ANY GROUP: all RO<->system CDC max-delay paths remain timed.
# This must run after every raw/generated clock has been created.
set domain_clocks [get_clocks]
set ro_group_args [list -name ro_independent_oscillators -asynchronous]
set grouped_ro_clocks {}
for {set ro_index 0} {$ro_index<640} {incr ro_index} {
    set members [list ro_raw_$ro_index ro_div_$ro_index]
    foreach member $members {
        if {[lsearch -exact $domain_clocks $member]<0} {error "Missing $member"}
        lappend grouped_ro_clocks $member
    }
    lappend ro_group_args -group $members
}
set system_clocks {}
foreach c $domain_clocks {
    if {[lsearch -exact $grouped_ro_clocks $c]<0} {lappend system_clocks $c}
}
if {[llength $domain_clocks]!=1281 || [llength $system_clocks]!=1} {
    error "Expected 1280 RO clocks plus one ungrouped system clock"
}
set_clock_groups {*}$ro_group_args
puts "RO_CLOCK_RELATIONSHIPS: 640 independent RO families; system clock $system_clocks deliberately ungrouped"
