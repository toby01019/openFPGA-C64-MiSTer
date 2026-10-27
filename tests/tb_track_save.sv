`timescale 1ns/1ps
module tb;
parameter CASES=1,EXPECTED_BYTES=1;
reg clk=0;always #5 clk=~clk;
reg reset=1,start=0;
reg [1:0] format=0;reg [6:0] half=0;reg [15:0] raw_length=0,slot=6;
reg [31:0] file_offset=0,write_limit=0;
wire busy,done,error;wire [7:0] error_code;
wire [9:0] track_addr;reg [63:0] track_q=0,q1=0,q2=0;
wire buffer_we;wire [7:0] buffer_addr;wire [31:0] buffer_data;
wire io_start;reg io_ready=0,io_done=0,io_error=0;
wire [2:0] io_operation;wire [15:0] io_slot;wire [31:0] io_offset;wire [10:0] io_length;
pocket_track_save dut(.clk(clk),.reset(reset),.start(start),.format(format),.half_track(half),.raw_length(raw_length),
 .file_offset(file_offset),.write_limit(write_limit),.disk_id1(8'h41),.disk_id2(8'hb7),.slot(slot),
 .busy(busy),.done(done),.error(error),.error_code(error_code),.track_addr(track_addr),.track_q(track_q),
 .buffer_we(buffer_we),.buffer_addr(buffer_addr),.buffer_data(buffer_data),
 .io_start(io_start),.io_ready(io_ready),.io_done(io_done),.io_error(io_error),
 .io_operation(io_operation),.io_slot(io_slot),.io_offset(io_offset),.io_length(io_length));
integer c_format[0:CASES-1],c_half[0:CASES-1],c_error[0:CASES-1],c_fail_write[0:CASES-1],c_fail_flush[0:CASES-1],c_param[0:CASES-1];
reg [31:0] c_offset[0:CASES-1],c_limit[0:CASES-1];
integer c_expected_offset[0:CASES-1],c_expected_length[0:CASES-1];
reg [7:0] fixture[0:CASES*8192-1],expected[0:EXPECTED_BYTES-1];
reg [63:0] track_mem[0:1023];reg [31:0] buffer_mem[0:255];
integer case_id=0,writes=0,flushes=0,bytes_written=0,buffer_writes=0,countdown=0;
integer n,i,j,cycles=0,last_address_change=0,last_buffer_write=-100;
reg response_error=0,done_seen=0;
reg [9:0] old_addr=0;
reg [31:0] random_state=32'hbac14019;
always @(negedge clk)begin
 random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
 io_ready=countdown==0 && (random_state[0] || random_state[4]);
end
always @(posedge clk)begin
 cycles=cycles+1;q1<=track_mem[track_addr];q2<=q1;track_q<=q2;
 if(track_addr!=old_addr)begin old_addr=track_addr;last_address_change=cycles;end
 if(dut.state==6 && cycles-last_address_change<3)$fatal(1,"readback sampled before3ticks");
 if(dut.state==6 && dut.source_index>8191)$fatal(1,"readback byte outside8K");
 io_done<=0;io_error<=0;
 if(reset)begin countdown=0;done_seen=0;end
 else begin
  if(done)done_seen=1;
  if(buffer_we)begin
   if(!busy)$fatal(1,"buffer write outside ownership");
   buffer_mem[buffer_addr]=buffer_data;buffer_writes=buffer_writes+1;last_buffer_write=cycles;
  end
  if(io_start && io_ready)begin
   if(!busy || io_slot!=6)$fatal(1,"save ownership/slot mismatch");
   if(countdown)$fatal(1,"overlapping IO request");
   countdown=17;response_error=0;
   if(io_operation==1)begin
    writes=writes+1;
    if(flushes || io_length==0 || io_length>1024 || io_offset!=c_offset[case_id]+bytes_written || cycles-last_buffer_write<1)
      $fatal(1,"write request shape/chunk offset/buffer timing");
    if({1'b0,io_offset}+io_length>{1'b0,c_limit[case_id]})$fatal(1,"write grows destination region");
    for(j=0;j<io_length;j=j+1)
     if((8'(buffer_mem[j/4]>>((j%4)*8)))!==expected[c_expected_offset[case_id]+bytes_written+j])
      $fatal(1,"write data mismatch case%0d byte%0d",case_id,bytes_written+j);
    for(j=io_length;j<((io_length+3)/4)*4;j=j+1)
     if((8'(buffer_mem[j/4]>>((j%4)*8)))!==0)$fatal(1,"partial buffer word not zero padded");
    bytes_written=bytes_written+io_length;
    response_error=writes==c_fail_write[case_id];
   end else if(io_operation==2)begin
    flushes=flushes+1;
    if(bytes_written!=c_expected_length[case_id] || io_length!=0)$fatal(1,"premature/invalid flush");
    response_error=c_fail_flush[case_id]!=0;
   end else $fatal(1,"unexpected IO operation");
  end else if(countdown>0)begin
   countdown=countdown-1;if(countdown==0)begin io_done<=1;io_error<=response_error;end
  end
 end
end
task launch(input integer c);
begin
 @(negedge clk);case_id=c;writes=0;flushes=0;bytes_written=0;buffer_writes=0;done_seen=0;
 for(i=0;i<1024;i=i+1)begin
  track_mem[i]=0;
  for(j=0;j<8;j=j+1)track_mem[i][j*8 +:8]=fixture[c*8192+i*8+j];
 end
 format=c_format[c];half=c_half[c];raw_length=c_param[c];slot=6;
 file_offset=c_offset[c];write_limit=c_limit[c];start=1;
 @(negedge clk);start=0;
 // Every operation parameter must be latched at start.
 format=0;half=127;raw_length=65535;slot=99;file_offset=32'hffffffff;write_limit=0;
end
endtask
initial begin
 `include "track_save_cases.vh"
 $readmemh("track_save_fixture.hex",fixture);$readmemh("track_save_expected.hex",expected);
 repeat(4)@(negedge clk);reset=0;
 launch(0);repeat(2000)@(negedge clk);
 if(writes || flushes)$fatal(1,"D64 writes before validation");
 reset=1;repeat(3)@(negedge clk);reset=0;
 for(n=0;n<CASES;n=n+1)begin
  launch(n);wait(!busy);repeat(4)@(negedge clk);
  if(error_code!=c_error[n] || error!=(c_error[n]!=0))$fatal(1,"case%0d error%0d expected%0d",n,error_code,c_error[n]);
  if(c_error[n]==0)begin
   if(!done_seen || writes!=(c_expected_length[n]+1023)/1024 || flushes!=1 || bytes_written!=c_expected_length[n])
    $fatal(1,"successful completion count case%0d",n);
  end else begin
   if(done_seen)$fatal(1,"failure reported successful done");
   if(c_fail_write[n])begin
    if(writes!=c_fail_write[n] || flushes)$fatal(1,"continued after write error");
   end else if(c_fail_flush[n])begin if(flushes!=1)$fatal(1,"flush error not tested");end
   else if(writes || flushes)$fatal(1,"validation failure emitted file writes");
  end
  $display("case%0d PASS writes=%0d flushes=%0d error=%0d",n,writes,flushes,error_code);
 end
 $display("PASS track save: actual bit-aligned decoder; three-cycle readback; bounded LE1024-byte writes; G64 header/raw exact8K and empty; D64 zone chunk counts; invalid tracks no writes; write errors stop/no flush; final flush; reset; latched parameters");
 $finish;
end
initial begin #1000000000;$fatal(1,"timeout case%0d state%0d decoder%0d",case_id,dut.state,dut.decoder.state);end
endmodule
