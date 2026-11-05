
`timescale 1ns/1ps
module tb;
 reg clk=0;always #5 clk=~clk;reg reset=0;reg[3:0]ce=0;always @(posedge clk)ce<=ce+1'b1;
 wire[23:0]a;wire[7:0]q;wire rw,sync;reg[7:0]di=0;
 reg[7:0]memory[0:65535],bank[0:272295];wire[7:0]ioq;wire claim,start;wire[23:0]ra;
 reg done=0;reg[7:0]rd=0;wire underrun;wire signed[17:0]l,r;
 t65_Brtl cpu(.mode(2'b00),.bcd_en(1'b1),.res_n(reset),.enable(ce==0),.clk(clk),.rdy(1'b1),
 .abort_n(1'b1),.irq_n(1'b1),.nmi_n(1'b1),.so_n(1'b1),.r_w_n(rw),.sync(sync),.a(a),.di(di),.\do (q));
 pocket_pcm pcm(.clk(clk),.reset(!reset),.enabled(1'b1),.paused(1'b0),.bank_valid(1'b1),.bank_size(21'd272296),
 .io_select(a[15:8]==8'hdf && ce==0),.io_write(!rw),.io_addr(a[7:0]),.io_data(q),.io_claim(claim),.io_q(ioq),
 .ram_start(start),.ram_addr(ra),.ram_ready(!done),.ram_done(done),.ram_data(rd),
 .sid_left(18'sd0),.sid_right(18'sd0),.left(l),.right(r),.underrun(underrun));
 integer count0=0,count1=0,cycles=0,idx;reg signed[15:0]expected;reg called=0;
 always @(posedge clk)begin
  di<=a[15:8]==8'hdf ? ioq:memory[a[15:0]];
  done<=start;if(start)begin if(ra>=272296)$fatal(1,"sample outside bank");rd<=bank[ra];end
  if(reset && ce==0)begin
   if(!rw)memory[a[15:0]]<=q;
   if(sync && a[15:0]==525)begin
    called<=1;
    if(memory[47772]!=1 || pcm.base[0]!=0 || pcm.length[0]!=54684 || pcm.rate[0]!=142 ||
       pcm.base[1]!=265262 || pcm.length[1]!=7034 || pcm.rate[1]!=781)$fatal(1,"compiled game descriptors incorrect");
   end
  end
  if(reset && pcm.sample_tick)begin
   if(pcm.active[0] && pcm.timer[0]==0 && pcm.next_valid[0])begin
    idx=count0*2;expected={bank[idx+1],bank[idx]};if(pcm.next_sample[0]!==expected)$fatal(1,"shot sample mismatch");count0=count0+1;
   end
   if(pcm.active[1] && pcm.timer[1]==0 && pcm.next_valid[1])begin
    idx=265262+count1*2;expected={bank[idx+1],bank[idx]};if(pcm.next_sample[1]!==expected)$fatal(1,"scream sample mismatch");count1=count1+1;
   end
  end
  cycles=cycles+1;
  if(called && count0>=64 && count1>=64)begin
   if(underrun)$fatal(1,"sample underrun");$display("PASS compiled TobyPink on MiSTer T65 -> Pocket PCM: shot/scream register descriptors and %0d/%0d actual V029 samples, no underrun",count0,count1);$finish;
  end
  if(cycles>1000000)$fatal(1,"compiled playback timeout");
 end
 initial begin $readmemh("playback-game.hex",memory);$readmemh("C:/Users/toby0/Documents/Codex/2026-10-24/playstation-core-f-r-analogue-pocket/work/c64-pocket-port/tests/private-audio/bank.hex",bank);repeat(5)@(negedge clk);reset=1;end
endmodule
