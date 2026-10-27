project_open pocket
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 20 -nworst 1 -detail summary -file review_timing_all.txt
report_timing -setup -to_clock [get_clocks {*divclk}] -npaths 5 -detail full_path -file review_timing_core.txt
delete_timing_netlist
project_close

