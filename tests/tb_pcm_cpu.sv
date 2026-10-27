
`timescale 1ns/1ps
module tb;
 reg a=0,b=0;always #6.734 a=~a;always #15.873 b=~b;
 reg valid=0;reg[25:0]cmd=0;reg[7:0]rom[0:103-1];integer i,consumed=0,expected;
 wire[21:16]pa;tri[15:0]pd;wire pc,padv,pcre,pce0,pce1,poe,pwe,pub,plb;
 core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),.bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0),
 .cram0_a(pa),.cram0_dq(pd),.cram0_wait(1'b1),.cram0_clk(pc),.cram0_adv_n(padv),.cram0_cre(pcre),.cram0_ce0_n(pce0),.cram0_ce1_n(pce1),
 .cram0_oe_n(poe),.cram0_we_n(pwe),.cram0_ub_n(pub),.cram0_lb_n(plb));
 psram_model physical(.a(pa),.dq(pd),.ramclk(pc),.adv(padv),.cre(pcre),.ce0(pce0),.ce1(pce1),.oe(poe),.we(pwe),.ub(pub),.lb(plb));
 function[7:0]data_byte(input integer n);data_byte=(n*37+11)&255;endfunction
 task send(input[25:0]v);begin
 @(negedge a);cmd=v;valid=1;wait(dut.host_done);@(negedge a);valid=0;
 wait(!dut.host_done);repeat(3)@(negedge a);
 end endtask
 always @(posedge dut.clk_core)if(!dut.core_reset && dut.reu_memory.pcm.sample_tick && dut.reu_memory.pcm.active[0] &&
  dut.reu_memory.pcm.timer[0]==0 && dut.reu_memory.pcm.next_valid[0])begin
  expected={data_byte(consumed*2+1),data_byte(consumed*2)};
  if(dut.reu_memory.pcm.next_sample[0]!==expected[15:0])$fatal(1,"full-core PCM sample %d",consumed);
  consumed=consumed+1;
 end
 initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;
 force dut.host_write=valid;force dut.host_data=cmd;force dut.pcm_enabled=1;force dut.reu_config=1;
 $readmemh("pcm-cpu-rom.hex",rom);repeat(100)@(negedge b);
 for(i=0;i<103;i=i+1)send({2'b01,16'(16'h2000+i),rom[i]});
 send({2'b01,16'h3ffc,8'h00});send({2'b01,16'h3ffd,8'he0});
 send({4'b1101,1'b1,21'd64});
 for(i=0;i<64;i=i+1)send({4'b1100,1'b1,13'b0,data_byte(i)});
 send({4'b1110,1'b1,21'b0});repeat(10)@(negedge b);
 if(!dut.reu_memory.bank_valid || physical.writes!=64)$fatal(1,"sample bank not completely preloaded");
 force dut.core_run=1;wait(dut.main_ram[16'hc120]===8'ha5);
 wait(consumed==32);wait(!dut.reu_memory.pcm.active[0]);
 if(dut.reu_memory.underrun || physical.reads!=64)$fatal(1,"PCM underflow/read count");
 $display("PASS full-core PCM: real APF mailbox preload/physical byte lanes, actual 6510 IOF signature + channel programming alongside REU, all32 LE16 words exact, no underrun");$finish;
 end
 initial begin #10000000;$fatal(1,"full-core PCM timeout marker=%h consumed=%d",dut.main_ram[16'hc120],consumed);end
endmodule
