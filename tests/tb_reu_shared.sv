`timescale 1ns/1ps
module tb;
reg clk=0;always #15.859 clk=~clk;
reg reset=1,enable=1;reg[1:0]cfg=3;reg wrap=0;
wire req;wire[15:0]da;wire[7:0]dd;wire dwe;reg[7:0]c64[0:65535];wire[7:0]di=c64[da];
reg[4:0]phase=0;always @(posedge clk)if(enable)phase<=phase+1'b1;
wire dc=phase[4];wire[23:0]ra;wire[7:0]rdout;wire[7:0]rdin;wire rwe,rstart;wire rready,rack;
reg[15:0]ca=0;reg[7:0]cd=0;wire[7:0]cq;reg cwe=0,cs=0;wire irq;
wire pcm_claim;
pocket_reu dut(.clk(clk),.reset(reset),.enable(enable),.cfg(cfg),.wrap(wrap),.dma_req(req),.dma_cycle(dc),.dma_addr(da),.dma_dout(dd),.dma_din(di),.dma_we(dwe),
.ram_cycle(1'b0),.ram_ready(rready),.ram_ack(rack),.ram_start(rstart),.ram_addr(ra),.ram_dout(rdout),.ram_din(rdin),.ram_we(rwe),
.cpu_addr(ca),.cpu_dout(cd),.cpu_din(cq),.cpu_we(cwe),.cpu_cs(cs && !pcm_claim),.irq(irq));
wire[21:16]a;tri[15:0]dq;wire ramclk,adv,cre,ce0,ce1,oe,we,ub,lb;
pocket_sample_memory memory(.clk(clk),.reset(reset),.c64_reset(reset),.enabled(1'b1),.paused(1'b0),
 .command(26'b0),.command_valid(1'b0),.command_ready(),
 .reu_start(rstart),.reu_write(rwe),.reu_addr(ra),.reu_out(rdout),.reu_ready(rready),.reu_done(rack),.reu_in(rdin),
 .io_select(cs),.io_write(cwe),.io_addr(ca[7:0]),.io_data(cd),.io_claim(pcm_claim),.io_q(),
 .sid_left(18'sd0),.sid_right(18'sd0),.left(),.right(),.bank_valid(),.bank_size(),.underrun(),
.cram_a(a),.cram_dq(dq),.cram_wait(1'b1),.cram_clk(ramclk),.cram_adv_n(adv),.cram_cre(cre),.cram_ce0_n(ce0),.cram_ce1_n(ce1),.cram_oe_n(oe),.cram_we_n(we),.cram_ub_n(ub),.cram_lb_n(lb));
always @(posedge clk)if(enable && dwe)c64[da]<=dd;
// Pin-level asynchronous CellularRAM: address latched on ADV rising edge,
// 70-ns array delay plus 20-ns OE delay; writes commit when WE rises.
reg[15:0]mem[0:8388607];reg[22:0]latched;reg[15:0]value=16'hxxxx,captured;
reg saved_ub,saved_lb,writing=0;integer cycles=0;realtime adv_time,write_time,data_time;
assign #20 dq=(!oe && (!ce0 || !ce1) && adv && we) ? value:16'hzzzz;
always @(negedge adv) begin adv_time=$realtime;cycles=cycles+1;end
always @(posedge adv) if(!ce0 || !ce1) begin
 latched={!ce1,a,dq};
 if(latched[21:0]===22'h3fffff)$fatal(1,"forbidden physical last word");
 if((ce0===0 && ce1===0) || cre!==0 || ramclk!==0)$fatal(1,"chip selection");
 if(!we)begin writing=1;saved_ub=ub;saved_lb=lb;end
 value=16'hxxxx;
 #70 value=mem[latched];
end
always @(negedge we)write_time=$realtime;
always @(dq)if(writing && !we && adv && (^dq!==1'bx))begin captured=dq;data_time=$realtime;end
always @(posedge we)if(writing)begin
 if($realtime-write_time<45 || $realtime-adv_time<70 || $realtime-data_time<20)$fatal(1,"write timing");
 if(!saved_ub)mem[latched][15:8]=captured[15:8];
 if(!saved_lb)mem[latched][7:0]=captured[7:0];
 writing=0;
end
always @(negedge clk)if(ce0===0 && ce1===0)$fatal(1,"both chips active");
task poke(input[4:0]regno,input[7:0]v);begin
 @(negedge clk);ca=16'hdf00+regno;cd=v;cwe=1;cs=1;
 @(negedge clk);cs=0;cwe=0;@(negedge clk);
end endtask
task peek(input[4:0]regno,output[7:0]v);begin
 @(negedge clk);ca=16'hdf00+regno;cwe=0;cs=1;
 @(negedge clk);v=cq;cs=0;@(negedge clk);
end endtask
task setup(input[15:0]caddr,input[23:0]raddr,input[15:0]len,input[7:0]ctl);begin
 poke(2,caddr[7:0]);poke(3,caddr[15:8]);poke(4,raddr[7:0]);poke(5,raddr[15:8]);poke(6,raddr[23:16]);poke(7,len[7:0]);poke(8,len[15:8]);poke(10,ctl);
end endtask
task finish_dma;integer timeout;begin
 timeout=0;while(req!==1 && timeout<10)begin @(negedge clk);timeout=timeout+1;end
 if(req!==1)$fatal(1,"no DMA");
 while(req)@(negedge clk);
 repeat(3)@(negedge clk);
end endtask
task run(input[1:0]kind);begin poke(1,8'h90|kind);finish_dma;end endtask
task audio_poke(input[15:0]ad,input[7:0]v);begin
 @(negedge clk);ca=ad;cd=v;cwe=1;cs=1;
 @(negedge clk);cs=0;cwe=0;@(negedge clk);
end endtask
integer i,ch;reg[15:0]voice_base;reg[7:0]status;
initial begin #10000000;$fatal(1,"timeout");end
initial begin
 for(i=0;i<65536;i=i+1)c64[i]=(i*7+13)&255;
 repeat(5)@(negedge clk);reset=0;
 for(i=0;i<32;i=i+1)mem[i]=16'h1234+i;
 force memory.bank_valid=1;force memory.bank_size=64;
 for(ch=0;ch<2;ch=ch+1)begin
  voice_base=ch ? 16'hdf40:16'hdf20;
  audio_poke(voice_base+1,48);audio_poke(voice_base+2,8);audio_poke(voice_base+4,1);
  audio_poke(voice_base+5,0);audio_poke(voice_base+6,0);audio_poke(voice_base+7,0);
  audio_poke(voice_base+9,0);audio_poke(voice_base+10,0);audio_poke(voice_base+11,64);
  audio_poke(voice_base+14,0);audio_poke(voice_base+15,142);audio_poke(voice_base,8'h11);
 end
 setup(16'h2000,24'h800010,16,0);run(0);
 setup(16'h3000,24'h800010,16,0);run(1);
 for(i=0;i<16;i=i+1)if(c64[16'h3000+i]!==c64[16'h2000+i])$fatal(1,"physical roundtrip");
 for(i=0;i<16;i=i+1)c64[16'h4000+i]=8'h90+i;
 setup(16'h4000,24'h800010,16,0);run(2);
 for(i=0;i<16;i=i+1)if(c64[16'h4000+i]!==c64[16'h2000+i])$fatal(1,"physical swap C64");
 setup(16'h5000,24'h800010,16,0);run(1);
 for(i=0;i<16;i=i+1)if(c64[16'h5000+i]!==8'h90+i)$fatal(1,"physical swap RAM");
 setup(16'h5000,24'h800010,16,0);run(3);peek(0,status);if(status[5])$fatal(1,"physical verify");
 setup(16'h2000,24'hfffffe,4,0);run(0);setup(16'h6000,24'hfffffe,4,0);run(1);
 for(i=0;i<4;i=i+1)if(c64[16'h6000+i]!==c64[16'h2000+i])$fatal(1,"physical lastword/wrap");
 wait(memory.pcm.active==0);if(memory.underrun)$fatal(1,"registered REU starved PCM");
 $display("PASS registered-start REU through shared PCM arbiter with actual Pocket PSRAM controller and 70ns pin memory: roundtrip, swap, verify, shadow lastword and 16M wrap with both PCM voices active, no underrun");$finish;
end
endmodule
