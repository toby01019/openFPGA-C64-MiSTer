`timescale 1ns/1ps
module tb;
 reg clk=0;always #15.859 clk=~clk;reg reset=1,c64reset=1;
 reg[25:0]cmd=0;reg valid=0;wire cmdready;
 reg reustart=0,reuwrite=0;reg[23:0]reuaddr=0;reg[7:0]reuout=0;wire reuready,reudone;wire[7:0]reuin;
 reg iosel=0,iowrite=0;reg[7:0]ioaddr=0,iodata=0;wire claim;wire[7:0]ioq;
 wire bankvalid;wire[20:0]banksize;wire underrun;wire signed[17:0]l,r;
 wire[21:16]a;tri[15:0]dq;wire ramclk,adv,cre,ce0,ce1,oe,we,ub,lb;
 pocket_sample_memory dut(.clk(clk),.reset(reset),.c64_reset(c64reset),.enabled(1'b1),.paused(1'b0),
  .command(cmd),.command_valid(valid),.command_ready(cmdready),
  .reu_start(reustart),.reu_write(reuwrite),.reu_addr(reuaddr),.reu_out(reuout),.reu_ready(reuready),.reu_done(reudone),.reu_in(reuin),
  .io_select(iosel),.io_write(iowrite),.io_addr(ioaddr),.io_data(iodata),.io_claim(claim),.io_q(ioq),
  .sid_left(18'sd0),.sid_right(18'sd0),.left(l),.right(r),.bank_valid(bankvalid),.bank_size(banksize),.underrun(underrun),
  .cram_a(a),.cram_dq(dq),.cram_wait(1'b1),.cram_clk(ramclk),.cram_adv_n(adv),.cram_cre(cre),.cram_ce0_n(ce0),.cram_ce1_n(ce1),
  .cram_oe_n(oe),.cram_we_n(we),.cram_ub_n(ub),.cram_lb_n(lb));
 cart_psram_model physical(.a(a),.dq(dq),.clk(ramclk),.adv(adv),.cre(cre),.ce0(ce0),.ce1(ce1),.oe(oe),.we(we),.ub(ub),.lb(lb));
 task tick;begin @(negedge clk);end endtask
 task command(input[1:0]op,input[20:0]v);
 begin cmd={2'b11,op,1'b1,v};tick;while(!cmdready)tick;valid=1;tick;valid=0;tick;end endtask
 task regwrite(input[7:0]ad,input[7:0]v);
 begin ioaddr=ad;iodata=v;iosel=1;iowrite=1;repeat(2)tick;iosel=0;iowrite=0;repeat(2)tick;end endtask
 task reu_read(input[23:0]ad,input[7:0]v);
 begin reuaddr=ad;reuwrite=0;while(!reuready)tick;reustart=1;tick;reustart=0;
 while(!reudone)tick;if(reuin!==v)$fatal(1,"REU/PCM arbitration at %h expected %h got %h",ad,v,reuin);tick;end endtask
 task voice(input bit ch);
 reg[7:0]b;begin b=ch ? 8'h40:8'h20;
 regwrite(b+1,48);regwrite(b+2,8);regwrite(b+4,1);regwrite(b+5,0);regwrite(b+6,0);regwrite(b+7,0);
 regwrite(b+9,0);regwrite(b+10,0);regwrite(b+11,64);regwrite(b+14,0);regwrite(b+15,142);regwrite(b,8'h11);end endtask
 reg[7:0]bank[0:272295];reg[4095:0]path;integer i;
 initial begin
 if(!$value$plusargs("BANK=%s",path))$fatal;$readmemh(path,bank);
 repeat(5)tick;reset=0;repeat(8)tick;
 command(1,64);if(bankvalid)$fatal(1,"premature ready");
 for(i=0;i<64;i=i+1)command(0,{13'b0,bank[i]});
 command(2,0);
 if(!bankvalid || banksize!=64)$fatal(1,"complete bank not accepted");
 for(i=0;i<32;i=i+1)if(physical.memory[i]!=={bank[2*i+1],bank[2*i]})$fatal(1,"preload physical byte lane %d",i);
 c64reset=0;voice(0);voice(1);
 for(i=0;i<256;i=i+1)reu_read(i%64,bank[i%64]);
 wait(dut.pcm.active==0);if(underrun)$fatal(1,"audio starved by REU traffic");
 c64reset=1;repeat(6)tick;c64reset=0;if(!bankvalid)$fatal(1,"soft reset lost bank");
 // A new, interrupted preload must invalidate the previous bank.
 command(1,64);command(0,8'h55);command(2,0);if(bankvalid)$fatal(1,"truncated bank accepted");
 command(1,64);command(0,8'h55);command(3,0);if(bankvalid)$fatal(1,"abort retained ready flag");
 $display("PASS shared sample memory: APF preload/physical byte lanes, both voices with 256 concurrent REU reads, fairness, soft-reset retention, partial/abort rejection");$finish;
 end
 initial begin #100000000;$fatal(1,"shared sample RAM timeout");end
endmodule

