`timescale 1ns/1ps
module tb;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,enabled=1,paused=0,menu=0,available=1,mounted=0,cancel=0;
 reg valid=0;reg [15:0] addr=0;reg [7:0] data=0;
 wire [63:0] keys;wire typing,waiting,prompt;
 pocket_autostart #(.CLK_HZ(1000),.SETTLE_MS(3),.KEY_MS(2),.ARM_MS(20),.LOAD_MS(5000)) dut(
 .clk(clk),.reset(reset),.enabled(enabled),.paused(paused),.menu(menu),.available(available),
 .mounted(mounted),.cancel(cancel),.cpu_valid(valid),.cpu_addr(addr),.cpu_data(data),
 .matrix(keys),.typing(typing),.waiting(waiting),.prompt_ready(prompt));
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task op(input [15:0] a,input [7:0] d);begin valid=1;addr=a;data=d;cycles(1);valid=0;end endtask
 task ready;begin op(16'ha483,8'h20);valid=1;addr=16'he5cd;data=8'ha5;cycles(6);end endtask
 task clean;begin reset=1;mounted=0;cancel=0;menu=0;paused=0;enabled=1;valid=0;cycles(3);reset=0;cycles(2);end endtask
 task insert;begin mounted=0;cycles(2);mounted=1;cycles(2);end endtask
 reg [63:0] expect_keys[0:15];integer n;
 task read_command(input integer first,input integer last);begin
  for(n=first;n<=last;n=n+1)begin
   wait(dut.state==2);cycles(21);
   if(keys!==expect_keys[n])$fatal(1,"typed key %d got %h expected %h",n,keys,expect_keys[n]);
   wait(dut.state==3);cycles(1);
   if(keys!==0)$fatal(1,"missing key release");
  end
 end endtask
 initial begin
  expect_keys[0]=64'b1<<42;expect_keys[1]=64'b1<<38;expect_keys[2]=64'b1<<10;expect_keys[3]=64'b1<<18;
  expect_keys[4]=(64'b1<<59)|(64'b1<<15);expect_keys[5]=64'b1<<49;expect_keys[6]=expect_keys[4];
  expect_keys[7]=64'b1<<47;expect_keys[8]=64'b1<<27;expect_keys[9]=expect_keys[7];expect_keys[10]=64'b1<<56;
  expect_keys[11]=64'b1<<1;expect_keys[12]=64'b1<<17;expect_keys[13]=64'b1<<30;expect_keys[14]=64'b1<<39;expect_keys[15]=expect_keys[11];
  clean();ready();if(!prompt)$fatal(1,"prompt not recognized");insert();read_command(0,11);
  op(16'ha486,8'h86);op(16'he175,8'h20);cycles(10);
  if(keys!=0 || !waiting)$fatal(1,"RUN before load completion");
  op(16'he1a7,8'h86);ready();read_command(12,15);cycles(20);
  if(typing || waiting || keys!=0)$fatal(1,"not idle after RUN");
  cycles(50);if(typing)$fatal(1,"same mounted disk restarted");
  // A running game using the KERNAL keyboard routine is not the BASIC prompt.
  clean();ready();op(16'ha486,8'h86);insert();valid=1;addr=16'he5cd;data=8'ha5;cycles(40);
  if(typing || waiting)$fatal(1,"mid-game disk swap typed");
  // Neither data fetches nor coincidental addresses with other opcodes qualify.
  clean();op(16'ha483,8'hea);insert();valid=1;addr=16'he5cd;data=8'ha5;cycles(40);
  if(typing || prompt)$fatal(1,"false ROM detection");
  clean();ready();insert();read_command(0,11);op(16'ha486,8'h86);op(16'he175,8'h20);
  valid=1;addr=16'he5cd;data=8'ha5;cycles(40);
  if(keys!=0 || typing)$fatal(1,"self-starting game received RUN");
  op(16'ha437,8'h6c);ready();cycles(40);if(typing || waiting)$fatal(1,"load error received RUN");
  clean();ready();insert();read_command(0,11);op(16'ha486,8'h86);op(16'he175,8'h20);
  cycles(5010);if(waiting || typing || keys!=0)$fatal(1,"load timeout did not stop");
  clean();ready();insert();wait(typing);cancel=1;cycles(1);if(keys!=0)$fatal(1,"manual cancel stuck key");cancel=0;cycles(40);
  insert();cycles(40);if(typing)$fatal(1,"partial user line overwritten");
  clean();ready();insert();wait(typing);menu=1;cycles(1);menu=0;cycles(40);if(typing || keys!=0)$fatal(1,"menu abort");
  clean();ready();enabled=0;insert();cycles(40);if(typing || keys!=0)$fatal(1,"disabled start");
  enabled=1;cycles(40);if(typing)$fatal(1,"enabling retriggered old mounted disk");
  clean();ready();insert();wait(typing);mounted=0;cycles(2);if(keys!=0 || typing)$fatal(1,"eject stuck key");
  clean();ready();insert();wait(typing);paused=1;cycles(100);if(dut.position!=0)$fatal(1,"timer advanced while paused");paused=0;
  reset=1;cycles(2);if(keys!=0)$fatal(1,"reset stuck key");
  $display("PASS autostart: exact LOAD/RUN contacts, guarded READY, game swaps, self-starting load, error, timeout, manual/menu cancel, off, eject, pause, reset");$finish;
 end
 initial begin #1000000;$fatal(1,"test timeout state=%d pos=%d",dut.state,dut.position);end
endmodule
