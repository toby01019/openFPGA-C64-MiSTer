`timescale 1ns/1ps
module tb;
parameter CASES=1,SOURCE_BYTES=1,EXPECTED_BYTES=1;
reg clk=0;always #5 clk=~clk;
reg reset=1,start=0;
reg [5:0] track=1;
reg in_valid=0,out_ready=0;
wire in_ready,out_valid,busy,done,error;wire [7:0] out_data,error_code;
reg [7:0] source[0:SOURCE_BYTES-1],expected[0:EXPECTED_BYTES-1];
integer case_offset[0:CASES-1],case_length[0:CASES-1],case_track[0:CASES-1];
integer case_expected_offset[0:CASES-1],case_expected_length[0:CASES-1],case_error[0:CASES-1];
integer case_id=0,consumed=0,produced=0,n,cycles=0;
reg running=0,accepted=0,stalled=0;
reg [7:0] stalled_data=0;
reg [31:0] random_state=32'hb834c019;
wire [7:0] in_data=source[case_offset[case_id]+consumed];
wire in_last=consumed==case_length[case_id]-1;
pocket_gcr_d64 dut(.clk(clk),.reset(reset),.start(start),.track(track),.disk_id1(8'h41),.disk_id2(8'hb7),
 .in_valid(in_valid),.in_data(in_data),.in_last(in_last),.in_ready(in_ready),
 .out_valid(out_valid),.out_data(out_data),.out_ready(out_ready),.busy(busy),.done(done),.error(error),.error_code(error_code));
always @(negedge clk)begin
 random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
 out_ready=random_state[0] || random_state[5];
 if(!running || consumed>=case_length[case_id])in_valid=0;
 else if(!in_valid || accepted)in_valid=random_state[7] || random_state[9];
end
always @(posedge clk)begin
 cycles=cycles+1;accepted=in_valid && in_ready;
 if(reset)stalled=0;
 else begin
  if(accepted)consumed<=consumed+1;
  if(out_valid && consumed!=case_length[case_id])$fatal(1,"output before complete raw input, case%0d",case_id);
  if(stalled && (!out_valid || out_data!==stalled_data))$fatal(1,"output changed during backpressure");
  stalled=out_valid && !out_ready;stalled_data=out_data;
  if(out_valid && out_ready)begin
   if(produced>=case_expected_length[case_id])$fatal(1,"unexpected/partial output on invalid case%0d",case_id);
   if(out_data!==expected[case_expected_offset[case_id]+produced])$fatal(1,"payload mismatch case%0d byte%0d got%h",case_id,produced,out_data);
   produced=produced+1;
  end
 end
end
task launch(input integer c);
begin
 @(negedge clk);running=0;in_valid=0;case_id=c;consumed=0;produced=0;track=case_track[c];start=1;
 @(negedge clk);start=0;running=1;
end
endtask
initial begin
 `include "gcr_d64_cases.vh"
 $readmemh("gcr_d64_fixture.hex",source);$readmemh("gcr_d64_expected.hex",expected);
 repeat(4)@(negedge clk);reset=0;
 launch(0);wait(consumed>=100);@(negedge clk);running=0;reset=1;
 repeat(3)@(negedge clk);reset=0;
 for(n=0;n<CASES;n=n+1)begin
  launch(n);
  if(!done)wait(done);
  @(negedge clk);running=0;
  if(busy || produced!=case_expected_length[n] || error_code!=case_error[n] || error!=(case_error[n]!=0))
   $fatal(1,"case%0d failed error%0d/%0d output%0d/%0d seen%h",n,error_code,case_error[n],produced,case_expected_length[n],dut.seen);
  $display("case%0d PASS input=%0d output=%0d error=%0d",n,consumed,produced,error_code);
 end
 $display("PASS GCR D64 decoder: all bit phases and rotated starts; density zones; exact sector output; invalid/missing sectors produce no output; bad duplicate protection; valid duplicate replacement; backpressure; reset/restart");
 $finish;
end
initial begin #1000000000;$fatal(1,"timeout case%0d state%0d",case_id,dut.state);end
endmodule
