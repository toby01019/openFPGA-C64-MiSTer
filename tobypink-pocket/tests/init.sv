
`timescale 1ns/1ps
module tb;
 reg clk=0;always #5 clk=~clk;reg reset=0;reg[3:0]ce=0;always @(posedge clk)ce<=ce+1'b1;
 wire[23:0]a;wire[7:0]q;wire rw,sync;reg[7:0]di;
 reg[7:0]memory[0:65535];integer mode,cycles=0,writes=0;
 t65_Brtl cpu(.mode(2'b00),.bcd_en(1'b1),.res_n(reset),.enable(ce==0),.clk(clk),.rdy(1'b1),
 .abort_n(1'b1),.irq_n(1'b1),.nmi_n(1'b1),.so_n(1'b1),.r_w_n(rw),.sync(sync),.a(a),.di(di),.\do (q));
 always @(posedge clk)begin
  di<=memory[a[15:0]];
  if(a[15:8]==8'hdf)case(a[7:0])
   8'h18:di<=mode<2 ? 8'h50:0;8'h19:di<=mode<2 ? 8'h4b:0;
   8'h1a:di<=mode<2 ? 1:0;8'h1b:di<=mode==0 ? 1:0;
   default:di<=0;
  endcase
 end
 always @(posedge clk)if(reset && ce==0)begin
  cycles=cycles+1;
  if(!rw)begin memory[a[15:0]]<=q;if(a[15:8]==8'hdf)begin
   writes=writes+1;if(a[7:0]!=8'h20 && a[7:0]!=8'h40)$fatal(1,"Pocket issued Ultimate host-file command");
  end end
  if(sync && a[15:0]==16'h0207)begin
   if(memory[47772]!== (mode==0 ? 8'd1:8'd0))$fatal(1,"wrong audio detection mode %0d",mode);
   if(writes!=(mode==0 ? 2:0))$fatal(1,"unexpected audio writes");
   $display("PASS compiled TobyPink audio init: mode %0d, ready %0d, no Ultimate filesystem access, %0d CPU cycles",mode,memory[47772],cycles);$finish;
  end
  if(cycles>5000)$fatal(1,"game init timeout");
 end
 initial begin if(!$value$plusargs("MODE=%d",mode))$fatal;$readmemh("game.hex",memory);repeat(5)@(negedge clk);reset=1;end
endmodule
