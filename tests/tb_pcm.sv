`timescale 1ns/1ps
module tb;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,enabled=1,paused=0,bank_valid=1,sel=0,wr=0;
 reg [7:0]addr=0,data=0;
 wire claim;wire[7:0]q;wire start;wire[23:0]ram_addr;
 reg ready=1,done=0;reg[7:0]rdata=0;wire signed[17:0]l,r;wire underrun;
 pocket_pcm dut(.clk(clk),.reset(reset),.enabled(enabled),.paused(paused),.bank_valid(bank_valid),.bank_size(21'd272296),
  .io_select(sel),.io_write(wr),.io_addr(addr),.io_data(data),.io_claim(claim),.io_q(q),
  .ram_start(start),.ram_addr(ram_addr),.ram_ready(ready),.ram_done(done),.ram_data(rdata),
  .sid_left(18'sd100),.sid_right(-18'sd100),.left(l),.right(r),.underrun(underrun));
 reg[7:0]memory[0:272295];reg[4095:0]path;integer delay=0,requests=0;reg[23:0]saved;
 always @(posedge clk)begin
  done<=0;
  if(start && ready)begin ready<=0;saved<=ram_addr;delay<=20+(requests%31);requests<=requests+1;end
  else if(!ready)begin
   if(delay!=0)delay<=delay-1;
   else begin if(saved>=272296)$fatal(1,"PCM address out of bounds");rdata<=memory[saved];done<=1;ready<=1;end
  end
 end
 task tick;begin @(negedge clk);end endtask
 task regwrite(input[7:0]ad,input[7:0]v);
 begin addr=ad;data=v;sel=1;wr=1;repeat(2)tick;sel=0;wr=0;repeat(2)tick;end endtask
 task setup(input bit ch,input integer offset,input integer size,input integer rate);
 reg[7:0]b;begin b=ch ? 8'h40:8'h20;
 regwrite(b+1,48);regwrite(b+2,8);regwrite(b+4,1);
 regwrite(b+5,offset>>16);regwrite(b+6,offset>>8);regwrite(b+7,offset);
 regwrite(b+9,size>>16);regwrite(b+10,size>>8);regwrite(b+11,size);
 regwrite(b+14,rate>>8);regwrite(b+15,rate);regwrite(b,8'h11);
 end endtask
 integer consumed[0:1],previous_position[0:1],last_tick[0:1];
 integer cycles=0,j,idx,expect_sample,expected_l,expected_r,checks=0,first;
 reg monitor=1; integer v;
 always @(posedge clk)if(monitor && !reset && enabled && !paused && dut.sample_tick)begin
   for(v=0;v<2;v=v+1)if(dut.active[v] && dut.timer[v]==0 && dut.next_valid[v])begin
    idx=(v==0 ? 0:218624)+consumed[v]*2;
    expect_sample=$signed({memory[idx+1],memory[idx]});
    if(dut.next_sample[v]!==expect_sample[15:0])$fatal(1,"sample voice %0d index %0d got %d expected %d",v,consumed[v],dut.next_sample[v],expect_sample);
    if(consumed[v]>0 && cycles-last_tick[v] < (v==0 ? 710:3100))$fatal(1,"sample rate too fast");
    last_tick[v]=cycles;consumed[v]=consumed[v]+1;
   end
 end
 always @(negedge clk)begin
  cycles=cycles+1;
  if(!reset && enabled)begin
   expected_l=100+($signed(dut.sample[0])*48*8>>>8)+($signed(dut.sample[1])*48*8>>>8);
   expected_r=expected_l-200;
   if(expected_l>131071)expected_l=131071;if(expected_l< -131072)expected_l=-131072;
   if(expected_r>131071)expected_r=131071;if(expected_r< -131072)expected_r=-131072;
   if(l!==expected_l || r!==expected_r)$fatal(1,"PCM/SID mix mismatch %d %d vs %d %d samples %d %d vols %d %d pans %d %d intermediates %d %d",l,r,expected_l,expected_r,dut.sample[0],dut.sample[1],dut.volume[0],dut.volume[1],dut.pan[0],dut.pan[1],dut.l0,dut.l1);
   checks=checks+1;
  end
 end
 initial begin
  if(!$value$plusargs("BANK=%s",path))$fatal;$readmemh(path,memory);
  for(j=0;j<2;j=j+1)begin consumed[j]=0;previous_position[j]=0;last_tick[j]=0;end
  repeat(4)tick;reset=0;addr=8'h18;sel=1;tick;if(!claim || q!=8'h50)$fatal(1,"Pocket signature");sel=0;repeat(2)tick;
  setup(0,0,128,142);setup(1,218624,64,625);
  wait(dut.active==0);repeat(4)tick;
  if(underrun || consumed[0]<50 || consumed[1]<20)$fatal(1,"underflow or missing samples: %d %d",consumed[0],consumed[1]);
  monitor=0;
  // A control write to voice1 must preserve voice0's half-fetched LE16 word.
  memory[0]=8'h34;memory[1]=8'h12;
  setup(0,0,4,142);
  wait(dut.high_byte && !dut.pending && dut.owner==0);
  regwrite(8'h40,0);
  wait(dut.next_valid[0]);
  if(dut.next_sample[0]!==16'h1234)$fatal(1,"other voice control lost partial sample word");
  regwrite(8'h20,0);
  // Reject missing bank, unsupported format and out-of-bank descriptors.
  bank_valid=0;regwrite(8'h20,8'h11);if(dut.active!=0)$fatal(1,"absent bank accepted");bank_valid=1;
  setup(0,272294,4,142);if(dut.active!=0)$fatal(1,"out of bounds accepted");
  setup(0,0,128,142);wait(dut.pending);reset=1;repeat(2)tick;reset=0;
  repeat(100)tick;if(dut.active!=0 || dut.sample[0]!=0)$fatal(1,"stale completion after reset");
  enabled=0;repeat(3)tick;if(l!==18'sd100 || r!==-18'sd100)$fatal(1,"SID bypass changed");
  $display("PASS PCM: real V027 bank, LE16 two voices, rate, signed stereo mix/saturation, invalid bank/bounds, reset drain, unchanged SID bypass; %0d cycles checked",checks);$finish;
 end
 initial begin #100000000;$fatal(1,"PCM timeout");end
endmodule



