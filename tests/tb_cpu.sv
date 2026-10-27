`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #6.734 a=~a;always #15.873 b=~b;
reg [25:0] command=0;
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),
 .bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(16'b0),.cont2_key(16'b0),.cont3_key(16'b0),.cont4_key(16'b0));
task rom(input [13:0] addr,input [7:0] value);
begin
 @(negedge b);command={2'd1,2'b0,addr,value};force dut.command_fire=1;
 @(negedge b);force dut.command_fire=0;
end
endtask
integer i;
initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;
 force dut.command_fire=0;force dut.command_data=command;
 for(i=0;i<65536;i=i+1) dut.main_ram[i]=0;
 repeat(100) @(negedge b);
 rom(14'h2000,8'h78); // SEI; LDA #42; STA C100; JMP E006
 rom(14'h2001,8'ha9);rom(14'h2002,8'h42);rom(14'h2003,8'h8d);
 rom(14'h2004,8'h00);rom(14'h2005,8'hc1);rom(14'h2006,8'h4c);
 rom(14'h2007,8'h06);rom(14'h2008,8'he0);
 rom(14'h3ffc,8'h00);rom(14'h3ffd,8'he0);
 rom(14'h3ffa,8'h00);rom(14'h3ffb,8'he0);
 rom(14'h3ffe,8'h00);rom(14'h3fff,8'he0);
 repeat(100) @(negedge b);
 $display("ROM check E000=%h FFFC=%h FFFD=%h reset=%b cpu=%h",dut.c64.buslogic.kernel_c64.ram[14'h2000],dut.c64.buslogic.kernel_c64.ram[14'h3ffc],dut.c64.buslogic.kernel_c64.ram[14'h3ffd],dut.c64.reset,dut.c64.cpuaddr_pre);
 force dut.core_run=1;
 repeat(300) begin
  @(negedge b);
  if(dut.c64.enablecpu) $display("STEP cpu=%h data=%h rst=%b pc=%h mc=%h IR=%h L=%h Break=%b rdy=%b",dut.c64.cpuaddr_pre,dut.c64.cpudi,dut.c64.reset,dut.c64.cpu.cpu.pc,dut.c64.cpu.cpu.mcycle,dut.c64.cpu.cpu.ir,dut.c64.cpu.cpu.lcycle,dut.c64.cpu.cpu.break_flag,dut.c64.cpu.cpu.really_rdy);
 end
 repeat(2000) @(negedge b);
 $display("CPU addr=%h data=%h RAM=%h ba=%b phase=%h reset=%b",dut.c64.cpuaddr_pre,dut.c64.cpudi,dut.main_ram[16'hc100],dut.c64.baloc,dut.c64.syscycle,dut.c64.reset);
 if(dut.main_ram[16'hc100]!==8'h42) $fatal(1,"CPU reset-vector/ROM/RAM path failed");
 $display("PASS CPU reset-vector, uploaded ROM and RAM writes");$finish;
end
endmodule
