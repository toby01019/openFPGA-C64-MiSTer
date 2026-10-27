`timescale 1ns/1ps
module tb;
reg clk_74a=0,clk_core=0;
always #6.734 clk_74a=~clk_74a;
always #15.859 clk_core=~clk_core;
reg bridge_wr=0;
reg keyboard_transparency_toggle=0,reset_n=1;
reg [31:0] bridge_addr=0,bridge_wr_data=0;
reg [31:0] bridge_rd_data;
wire [31:0] table_bridge_data=32'h1357,cmd_rdata=32'h2468;
wire [5:0] load_state=0;wire [7:0] error_code=0;
reg [1:0] keyboard_transparency=0;
(* async_reg="true" *) reg transparency_toggle_meta=0,transparency_toggle_sync=0;
reg transparency_toggle_seen=0;
always @(posedge clk_74a)begin
  transparency_toggle_meta<=keyboard_transparency_toggle;
  transparency_toggle_sync<=transparency_toggle_meta;
  if(!reset_n)transparency_toggle_seen<=transparency_toggle_sync;
  else if(transparency_toggle_seen!=transparency_toggle_sync)
   transparency_toggle_seen<=transparency_toggle_sync;
 end
always @(posedge clk_74a)begin
  if(bridge_wr && bridge_addr==32'ha0000004)
   keyboard_transparency<=bridge_wr_data[1:0]==3 ? 2'b0:bridge_wr_data[1:0];
  else if(reset_n && transparency_toggle_seen!=transparency_toggle_sync)
   keyboard_transparency<=keyboard_transparency==2 ? 2'b0:keyboard_transparency+1'b1;
 end
always @* begin if(bridge_addr==32'ha0000004) bridge_rd_data={30'b0,keyboard_transparency}; else bridge_rd_data=32'b0; end
(* async_reg="true" *) reg [1:0] transparency_meta=0,transparency_sync=0;
always @(posedge clk_core) begin transparency_meta<=keyboard_transparency;transparency_sync<=transparency_meta; end

task write_value(input [31:0] address,input [31:0] value);
begin
 @(negedge clk_74a);bridge_addr=address;bridge_wr_data=value;bridge_wr=1;
 @(negedge clk_74a);bridge_wr=0;
end
endtask
task check_value(input [1:0] expected);
begin
 repeat(4) @(negedge clk_core);
 bridge_addr=32'ha0000004;#1;
 if(bridge_rd_data!=={30'b0,expected} || transparency_sync!==expected)
  $fatal(1,"register/CDC mismatch expected=%0d read=%h CDC=%h",expected,bridge_rd_data,transparency_sync);
end
endtask
initial begin
 check_value(0);
 write_value(32'ha0000004,1);check_value(1);
 write_value(32'ha0000004,2);check_value(2);
 write_value(32'ha0000000,0);check_value(2);
 write_value(32'ha0000008,0);check_value(2);
 write_value(32'ha0000004,3);check_value(0);
 write_value(32'ha0000004,0);check_value(0);
 // UI toggles cross to host and mode crosses back independently.
 @(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;check_value(1);
 @(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;check_value(2);
 @(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;check_value(0);
 // Simultaneous menu write takes priority and consumes the UI event once.
 @(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;
 wait(transparency_toggle_sync!=transparency_toggle_seen);
 write_value(32'ha0000004,2);check_value(2);
 reset_n=0;@(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;
 repeat(5)@(negedge clk_core);reset_n=1;check_value(2);
 $display("PASS transparency: UI toggle roundtrip, menu priority, reset event suppression, APF menu values, exact register decode/readback, invalid mode clamp, asynchronous two-stage CDC");
 $finish;
end
endmodule
