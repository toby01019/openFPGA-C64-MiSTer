`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg reset=1,start=0;
reg [5:0] track=0;
reg [7:0] id1=8'h41,id2=8'hb7;
reg in_valid=0,out_ready=0;
wire in_ready,out_valid,busy,done,error;
wire [7:0] out_data;
wire [15:0] track_length;
reg [7:0] fixture[0:205311];
integer base=0,consumed=0,produced=0,f=0,t,expected_in,expected_len,cycles=0;
wire [7:0] in_data=fixture[base+consumed];
pocket_d64_gcr dut(.clk(clk),.reset(reset),.start(start),.track(track),
 .disk_id1(id1),.disk_id2(id2),.in_valid(in_valid),.in_data(in_data),.in_ready(in_ready),
 .out_valid(out_valid),.out_data(out_data),.out_ready(out_ready),
 .busy(busy),.done(done),.error(error),.track_length(track_length));
reg [31:0] random_state=32'hdeba91c3;
reg stalled=0;
reg [7:0] stalled_data;
reg input_pending=0;
always @(negedge clk)begin
 random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
 out_ready=random_state[0] || random_state[3];
 // Valid cannot be withdrawn until the byte is consumed.
 if(!in_valid || in_ready)in_valid=random_state[7] || random_state[13];
end
always @(posedge clk)begin
 cycles=cycles+1;
 if(reset)stalled=0;
 else begin
  if(stalled && (!out_valid || out_data!==stalled_data))$fatal(1,"output changed during backpressure");
  stalled=out_valid && !out_ready;stalled_data=out_data;
  if(in_valid && in_ready)consumed<=consumed+1;
  if(out_valid && out_ready)begin
   produced=produced+1;if(f)$fdisplay(f,"%02x",out_data);
  end
 end
end
task launch(input integer n);
begin
 @(negedge clk);track=n;start=1;consumed=0;produced=0;
 @(negedge clk);start=0;
end
endtask
task invalid(input integer n);
begin
 launch(n);
 if(!done || !error || busy || produced!=0 || consumed!=0)$fatal(1,"invalid track accepted: %0d",n);
 @(negedge clk);
end
endtask
initial begin
 $readmemh("d64_fixture.hex",fixture);
 repeat(4)@(negedge clk);reset=0;
 invalid(0);invalid(43);invalid(63);
 // Abort an incomplete stream, then restart cleanly.
 launch(1);wait(consumed>=19);@(negedge clk);reset=1;
 repeat(3)@(negedge clk);reset=0;
 f=$fopen("d64_gcr_tracks.hex","w");
 for(t=1;t<=42;t=t+1)begin
  expected_in=(t<=17 ? 21:t<=24 ? 19:t<=30 ? 18:17)*256;
  expected_len=t<=17 ? 7602:t<=24 ? 7049:t<=30 ? 6588:6171;
  launch(t);
  // Metadata is latched at start, not sampled throughout transfer.
  track=0;id1=0;id2=0;
  wait(done);@(negedge clk);
  if(error || busy || consumed!=expected_in || produced!=expected_len+2 || track_length!=expected_len)
   $fatal(1,"track %0d mismatch in=%0d out=%0d len=%0d",t,consumed,produced,track_length);
  base=base+expected_in;id1=8'h41;id2=8'hb7;
 end
 $fclose(f);
 $display("PASS D64 GCR streaming: all42tracks/fourdensityzones; invalid0/43/63; metadata latch; reset/restart; randomized input stalls/output backpressure; exact lengths");
 $finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
