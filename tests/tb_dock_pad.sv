`timescale 1ns/1ps
module tb;
 reg clk=0;always #6.734 clk=~clk;
 reg reset_n=0;tri1 pad;reg device_drive=0,device_low=0;
 assign pad=device_drive ? (device_low ? 1'b0:1'bz):1'bz;
 wire [31:0] k1,k2,k3,k4,j1,j2,j3,j4;
 wire [15:0] t1,t2,t3,t4;wire update,timed_out;
 io_pad_controller dut(.clk(clk),.reset_n(reset_n),.pad_1wire(pad),
 .cont1_key(k1),.cont2_key(k2),.cont3_key(k3),.cont4_key(k4),
 .cont1_joy(j1),.cont2_joy(j2),.cont3_joy(j3),.cont4_joy(j4),
 .cont1_trig(t1),.cont2_trig(t2),.cont3_trig(t3),.cont4_trig(t4),
 .cont_update(update),.rx_timed_out(timed_out));
 integer updates=0,start_updates,i,b;reg timeout_seen=0;
 always @(posedge clk)if(update)updates=updates+1;
 always @(posedge clk)if(timed_out)timeout_seen=1;
 task send_word(input [31:0] word_value);
 begin
  for(b=31;b>=0;b=b-1)begin
   @(negedge clk);device_drive=1;device_low=1;
   repeat(20)@(negedge clk);device_low=!word_value[b];
   repeat(20)@(negedge clk);device_low=0;
   repeat(19)@(negedge clk);
  end
  device_drive=0;repeat(20)@(negedge clk);
 end endtask
 initial begin
  // FPGA power-up register values; accelerate only the initial reset timer.
  dut.rx_timeout=0;dut.auto_poll_cnt=0;dut.heartbeat_cnt=0;
  dut.auto_poll_queue=0;dut.heartbeat_queue=0;
  repeat(12)@(negedge clk);reset_n=1;
  repeat(12)@(negedge clk);dut.rx_timeout=21'h0ffffe;
  wait(dut.state==2);wait(dut.tx_word_done);repeat(25)@(negedge clk);
  start_updates=updates;
  send_word(32'h10000000);send_word(32'h01020304);send_word(32'h00000506);
  send_word(32'h3000ffff);send_word(32'h11223344);send_word(32'h00005566);
  send_word(32'h40000200);send_word(32'h04051e28);send_word(32'h00002c3a);
  send_word(32'h50000000);send_word(32'h00010002);
  if(updates!=start_updates)$fatal(1,"partial report incorrectly published");
  send_word(32'h00000003);repeat(15)@(negedge clk);
  if(updates!=start_updates+1)$fatal(1,"complete frame publication count");
  if(k1!==32'h10000000 || k2!==32'h3000ffff || k3!==32'h40000200 || k4!==32'h50000000)
   $fatal(1,"APF type bits lost: %h %h %h %h",k1,k2,k3,k4);
  if({j3,t3}!==48'h04051e282c3a)$fatal(1,"six HID report bytes altered");
  // Timeout in a later incomplete report must publish a neutral disconnect.
  wait(dut.state==2);wait(dut.tx_word_done);repeat(25)@(negedge clk);
  send_word(32'h10000001);dut.rx_timeout=21'h1fffff;
  repeat(10)@(negedge clk);
  if(!timeout_seen || k1!==0 || k3!==0 || j3!==0 || t3!==0)$fatal(1,"PAD timeout left held input");
  if(updates!=start_updates+2)$fatal(1,"timeout neutral publication missing");
  $display("PASS real PAD serial frames: 32-bit types, exact six keyboard bytes, only complete-frame publication, incomplete-frame timeout releases all slots");$finish;
 end
 initial begin #5000000;$fatal(1,"PAD simulation timeout state=%d tr=%d",dut.state,dut.tr_state);end
endmodule
