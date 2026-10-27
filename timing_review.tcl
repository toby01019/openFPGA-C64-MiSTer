project_open pocket
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 5 -detail full_path -file timing-details.txt
delete_timing_netlist
project_close
