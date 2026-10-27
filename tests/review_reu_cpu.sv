`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #6.734 a=~a;always #15.873 b=~b;
reg [25:0] command=0;
wire [21:16] pa;tri [15:0] pd;wire padv,pcre,pclk,pce0,pce1,poe,pwe,pub,plb;
psram_model memory(.a(pa),.dq(pd),.adv(padv),.cre(pcre),.ramclk(pclk),.ce0(pce0),.ce1(pce1),.oe(poe),.we(pwe),.ub(pub),.lb(plb));
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),
 .cram0_a(pa),.cram0_dq(pd),.cram0_wait(1'b1),.cram0_adv_n(padv),.cram0_cre(pcre),.cram0_clk(pclk),
 .cram0_ce0_n(pce0),.cram0_ce1_n(pce1),.cram0_oe_n(poe),.cram0_we_n(pwe),.cram0_ub_n(pub),.cram0_lb_n(plb),
 .bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0));
task rom(input [13:0] addr,input [7:0] value);
begin
 @(negedge b);command={2'd1,2'b0,addr,value};force dut.command_fire=1;
 @(negedge b);force dut.command_fire=0;
end
endtask
reg prevcs=0,prevdma=0;
always @(posedge b)begin
 prevcs<=dut.c64_iof;prevdma<=dut.reu_dma_req;
 if(dut.c64_iof && !prevcs)$display("IOF addr=%h we=%b data=%h",dut.c64_addr,dut.ram_we,dut.c64_data_out);
 if(dut.reu_ram_start || prevdma!=dut.reu_dma_req)$display("DMA req=%b ramstart=%b ack=%b ready=%b addr=%h we=%b",dut.reu_dma_req,dut.reu_ram_start,dut.reu_ram_done,dut.reu_ram_ready,dut.reu_ram_addr,dut.reu_ram_write);
end
integer i;reg [7:0] kernel[0:8191],prg[0:1402];
initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;force dut.disk_pause=0;
 force dut.command_fire=0;force dut.command_data=command;
 force dut.reu_config=1;
 $readmemh("review_reu_kernel.hex",kernel);$readmemh("review_reu_program.hex",prg);
 // Program initializes the CPU ports and every RAM byte used by the REU test.
 for(i=2;i<1403;i=i+1)dut.main_ram[16'h0801+i-2]=prg[i];
 repeat(100)@(negedge b);
 for(i=0;i<8192;i=i+1)rom(14'h2000+i,kernel[i]);
 repeat(100)@(negedge b);force dut.core_run=1;
 repeat(40000)@(negedge b);
 $display("CPU pc=%h reset=%b paused=%b ram0801=%h",dut.c64.cpu.cpu.pc,dut.core_reset,dut.c64_paused,dut.main_ram[16'h801]);
 $display("REU DIAG cpu=%h ext=%b dma=%b writes=%0d reads=%0d marker=%h",dut.c64_addr,dut.reu_ext_cycle,dut.reu_dma_req,memory.writes,memory.reads,dut.main_ram[16'hc110]);
 if(dut.main_ram[16'hc110]!==8'ha5)$fatal(1,"CPU REU roundtrip stuck");
 for(i=0;i<16;i=i+1)if(dut.main_ram[16'hc200+i]!==((i*17+5)&255))$fatal(1,"roundtrip byte %d",i);
 if(memory.writes!=16 || memory.reads!=16)$fatal(1,"physical access counts");
 $display("PASS isolated actual CPU IOF DMA PSRAM roundtrip");$finish;
end
endmodule
