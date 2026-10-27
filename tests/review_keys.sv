`timescale 1ns/1ps
// Verify that the loader's RUN/Return macro reaches the PS/2 event interface.
module tb;
reg clk=0,reset=1;
always #5 clk=~clk;
wire [7:0] desired;
wire [10:0] key_event;
wire [5:0] state;
pocket_loader #(.KEY_CYCLES(1024)) loader(.clk(clk),.reset(reset),.storage_hold(1'b0),.events(8'b0),
 .read_ready(1'b1),.read_done(1'b0),.read_error(1'b0),.buffer_data(32'b0),
 .table_data(32'b0),.write_done(1'b0),.paused(1'b0),.auto_keys(desired),.debug_state(state));
pocket_keys keyboard(.clk(clk),.reset(reset),.storage_hold(1'b0),.desired(desired),.ps2_key(key_event));
reg last_toggle=0;
integer count=0;
reg [7:0] expected_code;
always @(negedge clk) if(!reset && key_event[10] != last_toggle) begin
 last_toggle=key_event[10];
 case(count/2)
  0:expected_code=8'h2d;
  1:expected_code=8'h3c;
  2:expected_code=8'h31;
  3:expected_code=8'h5a;
  default:$fatal(1,"unexpected extra key");
 endcase
 if(key_event[8:0] !== {1'b0,expected_code} || key_event[9] !== (count%2==0))
  $fatal(1,"wrong RUN event %0d: %h",count,key_event);
 count=count+1;
end
initial begin
 repeat(4) @(negedge clk);
 reset=0;
 // Isolate macro execution after the pointer writes and pause release.
 loader.state=22;loader.wait_count=0;loader.key_phase=0;
 wait(state==12);
 repeat(1024) @(negedge clk);
 if(count!=8 || desired!=0) $fatal(1,"missing key make/break events: %0d",count);
 $display("PASS loader RUN/Return macro: R U N Return, eight ordered PS/2 make/break events");
 $finish;
end
endmodule
