# Read-only analysis candidate. Accept only after full conservative validation.
foreach name {sta.enableClockUncertainty sta.Sta4UncertaintyDerate sta.sta5UncertaintyDerate} {puts "UNCERTAINTY_PREOPEN $name [get_param $name]"}
set_param sta.enableClockUncertainty false
