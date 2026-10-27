`timescale 1ns/1ps
module tb;
 reg clk=0;always #5 clk=~clk;reg reset=1;
 wire start,valid,run,pause;wire[15:0]slot;wire[31:0]off;wire[10:0]len;
 wire[7:0]ba,err;wire[5:0]ta,state;wire[25:0]command;
 reg[31:0]table_q=0,buffer_q=0;reg done=0,error=0,ack=0;
 integer mode,delay=0,reads=0,bytes=0,starts=0,finishes=0,aborts=0,i,expected;
 integer cartstarts=0,cartbytes=0,cartfinishes=0;
 pocket_loader #(.BOOT_CYCLES(4),.ENABLE_PCM(1),.ENABLE_CRT(1)) dut(.clk(clk),.reset(reset),.events(8'b0),.storage_hold(1'b0),
 .restart(1'b0),.restart_safe(1'b1),.cart_busy(1'b0),.cart_error(1'b0),
 .read_start(start),.read_ready(1'b1),.read_done(done),.read_error(error),.read_slot(slot),.read_offset(off),.read_length(len),
 .buffer_addr(ba),.buffer_data(buffer_q),.table_addr(ta),.table_data(table_q),
 .write_valid(valid),.write_data(command),.write_done(ack),.core_run(run),.pause_request(pause),.paused(pause),.auto_keys(),.error_code(err),.debug_state(state));
 reg[7:0]buffer[0:1023];
 function[7:0]sample_byte(input integer n);sample_byte=(n*37+11)&255;endfunction
 always @(posedge clk)begin
  done<=0;ack<=valid && !ack;
  case(ta)
   0:table_q<=200;1:table_q<=8192;2:table_q<=201;3:table_q<=4096;4:table_q<=202;5:table_q<=8192;
   6:table_q<=mode==1 ? 0:205;
   7:table_q<=mode==2 ? 1048578:mode==3 ? 1025:2050;
   8:table_q<=mode==5 ? 3:0;9:table_q<=80;
   default:table_q<=0;
  endcase
  buffer_q<={buffer[{ba,2'b00}+3],buffer[{ba,2'b00}+2],buffer[{ba,2'b00}+1],buffer[{ba,2'b00}]};
  if(start)begin
   reads=reads+1;delay<=3;error<=slot==205 && mode==4 && off==1024;
   for(i=0;i<1024;i=i+1)buffer[i]<=sample_byte(off+i);
  end else if(delay>0)begin delay<=delay-1;if(delay==1)done<=1;end
  if(valid && ack && command[25:24]==3 && command[21])case(command[23:22])
   1:begin starts=starts+1;if(command[20:0]!=2050)$fatal(1,"sample size");end
   0:begin if(command[7:0]!==sample_byte(bytes))$fatal(1,"sample copy index %d",bytes);bytes=bytes+1;end
   2:begin finishes=finishes+1;if(bytes!=2050)$fatal(1,"truncated bank accepted");end
   3:aborts=aborts+1;
  endcase
  if(valid && ack && command[25:24]==3 && !command[21])case(command[23:22])
   1:begin if(finishes!=1)$fatal(1,"CRT before sample bank completed");cartstarts=cartstarts+1;end
   0:cartbytes=cartbytes+1;
   2:cartfinishes=cartfinishes+1;
  endcase
 end
 initial begin
  if(!$value$plusargs("MODE=%d",mode))$fatal;
  repeat(4)@(negedge clk);reset=0;wait(state==12);repeat(4)@(negedge clk);
  if(!run || pause || err)$fatal(1,"optional bank stopped normal boot");
  if(mode==0 && (starts!=1 || finishes!=1 || bytes!=2050 || aborts))$fatal(1,"sample bank load");
  if(mode==4 && (starts!=1 || finishes || bytes!=1024 || aborts!=1))$fatal(1,"read error bank abort");
  if(mode>0 && mode<4 && (starts || bytes || finishes || aborts))$fatal(1,"invalid bank not skipped");
  if(mode==5 && (starts!=1 || finishes!=1 || cartstarts!=1 || cartbytes!=80 || cartfinishes!=1))$fatal(1,"sample/CRT boot order or command collision");
  $display("PASS optional PCM loader mode %0d: %0d bytes, %0d starts, %0d finish, %0d abort; BASIC boot permitted",mode,bytes,starts,finishes,aborts);$finish;
 end
 initial begin #50000000;$fatal(1,"sample loader timeout");end
endmodule
