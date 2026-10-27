project_open pocket
create_timing_netlist -model slow
read_sdc
update_timing_netlist
# Diagnostic constraints only: expose the previously unconstrained output paths.
create_clock -name review_receiver -period 126.872 -waveform {47.577 111.013}
set_output_delay -clock review_receiver -max 2.0 [get_ports {scal_vid[*] scal_de scal_hs scal_vs scal_skip}]
set_output_delay -clock review_receiver -min -2.0 [get_ports {scal_vid[*] scal_de scal_hs scal_vs scal_skip}]
update_timing_netlist
report_timing -setup -to [get_ports {scal_vid[*] scal_de scal_hs scal_vs}] -npaths 32 -detail full_path -file video-pins-setup.rpt
report_timing -hold -to [get_ports {scal_vid[*] scal_de scal_hs scal_vs}] -npaths 32 -detail full_path -file video-pins-hold.rpt
report_clock_transfers -file video-clock-transfers.rpt
delete_timing_netlist
project_close
