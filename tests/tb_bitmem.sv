`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #7 a=~a;always #11 b=~b;
reg [3:0] aa=0;
reg [6:0] ab=0;
reg [7:0] da=0;
reg db=0,wa=0,wb=0;
wire [7:0] qa;
wire qb;
integer k,j;
iecdrv_bitmem #(4) dut(.clock_a(a),.address_a(aa),.data_a(da),.wren_a(wa),.q_a(qa),
 .clock_b(b),.address_b(ab),.data_b(db),.wren_b(wb),.q_b(qb));
initial begin
 for(k=0;k<16;k=k+1)begin
  @(negedge a);aa=k;da=(k*17)^8'ha6;wa=1;
 end
 @(negedge a);wa=0;repeat(5)@(negedge a);
 for(k=0;k<16;k=k+1)for(j=0;j<8;j=j+1)begin
  @(negedge b);ab=k*8+j;repeat(4)@(negedge b);
  if(qb!==((((k*17)^8'ha6)>>j)&1))$fatal(1,"mixed width bit read %0d %0d",k,j);
 end
 for(k=0;k<128;k=k+1)begin
  @(negedge b);ab=k;db=(k%3)==0;wb=1;
 end
 @(negedge b);wb=0;repeat(5)@(negedge b);
 for(k=0;k<16;k=k+1)begin
  @(negedge a);aa=k;repeat(4)@(negedge a);
  for(j=0;j<8;j=j+1)if(qa[j]!==(((k*8+j)%3)==0))$fatal(1,"mixed width byte read %0d %0d",k,j);
 end
 $display("PASS mixed-width dual-clock track RAM: byte-to-bit reads and bit-to-byte writes");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
