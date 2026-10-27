
`timescale 1ns/1ps
module tb;
 reg a=0,b=0;always #6.734 a=~a;always #15.873 b=~b;
 reg valid=0;reg[25:0]cmd=0;reg[7:0]crt[0:24688-1];integer i,reads=0;
 wire[21:16]pa;tri[15:0]pd;wire pc,padv,pcre,pce0,pce1,poe,pwe,pub,plb;
 core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),.bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0),
 .cram1_a(pa),.cram1_dq(pd),.cram1_wait(1'b1),.cram1_clk(pc),.cram1_adv_n(padv),.cram1_cre(pcre),.cram1_ce0_n(pce0),.cram1_ce1_n(pce1),
 .cram1_oe_n(poe),.cram1_we_n(pwe),.cram1_ub_n(pub),.cram1_lb_n(plb));
 defparam dut.cartridge_port.easyflash_port.ef.INIT_WORDS=1024;
 cart_psram_model physical(.a(pa),.dq(pd),.clk(pc),.adv(padv),.cre(pcre),.ce0(pce0),.ce1(pce1),.oe(poe),.we(pwe),.ub(pub),.lb(plb));
 task send(input[25:0]v);begin
 @(negedge a);cmd=v;valid=1;wait(dut.host_done);@(negedge a);valid=0;
 wait(!dut.host_done);repeat(3)@(negedge a);
 end endtask
 always @(posedge dut.clk_core)if(!dut.core_reset && !dut.c64_paused && dut.ram_ce && !dut.ram_we && (dut.c64_roml || dut.c64_romh || dut.c64_umax))begin
  if(!dut.cartridge_port.easyflash_port.ef.cache_hit && !dut.cartridge_port.easyflash_port.ef.status_oe)
   $fatal(1,"EasyFlash missed real CPU/VIC deadline addr=%h syscycle=%h",dut.c64_addr,dut.c64.syscycle);
  reads=reads+1;
 end
 initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;
 force dut.host_write=valid;force dut.host_data=cmd;
 $readmemh("easyflash-cpu.hex",crt);repeat(100)@(negedge b);
 send({4'b1101,22'd24688});for(i=0;i<24688;i=i+1)send({4'b1100,14'b0,crt[i]});send({4'b1110,22'b0});
 repeat(40)@(negedge b);if(!dut.cart_attached || dut.cart_error)$fatal(1,"EasyFlash upload");
 force dut.core_run=1;wait(dut.main_ram[16'hc121]===8'h5a);
 if(reads<60)$fatal(1,"CPU did not execute cartridge bootstrap");
 $display("PASS EasyFlash actual C64 CPU/VIC + physical PSRAM: Ultimax reset vector/bootstrap, 16K mode, ROML bank0/1, IO2 RAM, %0d reads at real bus deadline",reads);$finish;
 end
 initial begin #50000000;$fatal(1,"EasyFlash CPU timeout addr=%h marker=%h",dut.c64_addr,dut.main_ram[16'hc121]);end
endmodule
