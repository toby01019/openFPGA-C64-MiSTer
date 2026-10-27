`timescale 1ns/1ps
// Isolates simultaneous APF slot-update and software read-to-clear.
module tb;
reg clk=0;
always #5 clk=~clk;
wire [31:0] data;
core_bridge_cmd dut(.clk(clk),.bridge_endian_little(1'b0),
 .bridge_addr(32'b0),.bridge_rd(1'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),
 .status_boot_done(1'b0),.status_setup_done(1'b0),.status_running(1'b0),
 .i_cpu_clk(clk),.i_cpu_req(1'b0),.i_cpu_addr(32'h40000080),
 .i_cpu_wdata(32'b0),.i_cpu_wstrb(4'b0),.o_cpu_rdata(data));
initial begin
 repeat(10) @(negedge clk);
 dut.updated_slots=8'h04;
 dut.hstate=1;dut.host_cmd=16'h008a;dut.host_20=1;
 force dut.cpu_req_pulse=1;
 @(posedge clk);#1;
 release dut.cpu_req_pulse;
 if(data!==32'h04 || dut.updated_slots!==8'h02)
   $fatal(1,"lost simultaneous update: read=%h pending=%h",data,dut.updated_slots);
 @(negedge clk);dut.hstate=0;force dut.cpu_req_pulse=1;
 @(posedge clk);#1;release dut.cpu_req_pulse;
 if(data!==32'h02 || dut.updated_slots!==0) $fatal(1,"pending event not returned once");
 @(negedge clk);dut.hstate=1;dut.host_cmd=16'h008a;dut.host_20=1;
 @(posedge clk);#1;
 if(dut.updated_slots!==8'h02) $fatal(1,"ordinary slot update missing");
 @(negedge clk);dut.hstate=0;force dut.cpu_req_pulse=1;
 @(posedge clk);#1;release dut.cpu_req_pulse;
 if(data!==32'h02 || dut.updated_slots!==0) $fatal(1,"ordinary event not cleared");
 @(negedge clk);dut.hstate=0;force dut.cpu_req_pulse=1;
 @(posedge clk);#1;release dut.cpu_req_pulse;
 if(data!==0) $fatal(1,"event duplicated");
 $display("PASS bridge slot events: simultaneous update/read, pending delivery, ordinary update, no duplicate");
 $finish;
end
endmodule
