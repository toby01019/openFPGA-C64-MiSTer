project_open pocket
create_timing_netlist -model fast
read_sdc
update_timing_netlist
report_timing -hold -npaths 5 -detail full_path -file video-hold-before.rpt
delete_timing_netlist
project_close
