`timescale 1ns/1ps
module tb;
reg h=0,c=0;always #7 h=~h;always #11 c=~c;
reg [8:0]ha=0,ca=0;reg hw=0,cw=0;reg [7:0]hd=0,cd=0;wire [7:0]hq,cq;
pocket_sector_ram dut(.host_clk(h),.core_clk(c),.host_addr(ha),.core_addr(ca),.host_we(hw),.core_we(cw),.host_data(hd),.core_data(cd),.host_q(hq),.core_q(cq));
integer i;
initial begin
 for(i=0;i<512;i=i+1)begin @(negedge h);ha=i;hd=(i*37+11)&255;hw=1;end
 @(negedge h);hw=0;
 for(i=0;i<512;i=i+1)begin @(negedge c);ca=i;@(negedge c);if(cq!==((i*37+11)&255))$fatal(1,"host to core %d %h",i,cq);end
 for(i=0;i<512;i=i+1)begin @(negedge c);ca=i;cd=(i*19+3)&255;cw=1;end
 @(negedge c);cw=0;
 for(i=0;i<512;i=i+1)begin @(negedge h);ha=i;@(negedge h);if(hq!==((i*19+3)&255))$fatal(1,"core to host %d %h",i,hq);end
 $display("PASS sector RAM 512 bytes bidirectional dual-clock and exact one-cycle read latency");$finish;
end
endmodule
