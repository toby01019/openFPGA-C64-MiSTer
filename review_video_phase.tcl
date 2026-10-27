project_open pocket
create_timing_netlist -model fast
read_sdc
update_timing_netlist
report_timing -hold -from [get_registers {*video_stage*}] -to [get_registers {*video_adapter*}] -npaths 5 -detail full_path -file video-phase-hold.rpt
delete_timing_netlist
create_timing_netlist -model slow
read_sdc
update_timing_netlist
report_timing -setup -from [get_registers {*video_stage*}] -to [get_registers {*video_adapter*}] -npaths 5 -detail full_path -file video-phase-setup.rpt
delete_timing_netlist
project_close
