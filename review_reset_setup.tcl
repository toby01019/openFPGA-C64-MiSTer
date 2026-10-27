project_open pocket
create_timing_netlist -model slow
read_sdc
update_timing_netlist
report_timing -setup -npaths 3 -detail full_path -file reset-setup-review.rpt
delete_timing_netlist
project_close
