`timescale 1ns/1ps
// Independent source/receiver. Count and reconstruct pixels AFTER the actual
// Intel APF DDR primitive, not just the adapter's 24-bit RTL output.
module tb;
parameter PAD=2;
reg clk=0;
always #63.436 clk=~clk;
wire clk90; assign #31.718 clk90=clk;
reg en=1, hs=0,vs=0,hb=1,vb=1;
reg [23:0] src=0;
wire [23:0] rgb;
wire de,skip,ohs,ovs;
pocket_video #(.NATIVE_PIXEL_CLOCK(1),.RIGHT_PAD(PAD)) dut(
 .clk(clk),.enable(en),.hsync(hs),.vsync(vs),.hblank(hb),.vblank(vb),
 .rgb(src),.video_rgb(rgb),.video_de(de),.video_skip(skip),.video_hs(ohs),.video_vs(ovs));
wire [11:0] pins,ctrl,forwarded;
mf_ddio_bidir_12 colors(.oe(1'b1),.datain_h(rgb[23:12]),.datain_l(rgb[11:0]),.outclock(clk),.padio(pins));
mf_ddio_bidir_12 controls(.oe(1'b1),.datain_h({8'b0,ovs,ohs,de,skip}),.datain_l({8'b0,ovs,ohs,de,skip}),.outclock(clk),.padio(ctrl));
mf_ddio_bidir_12 clock_out(.oe(1'b1),.datain_h(12'b1),.datain_l(12'b0),.outclock(clk90),.padio(forwarded));
function [23:0] color(input integer x,y);
 // Different data in all nibbles catches half-word swaps and stale samples.
 color={8'(x^y),8'(x*13+y*7),8'(x*23+y*31)};
endfunction
integer tx_x,tx_y,tx_f,t;
integer rx_x=0,rx_y=0,frames=0,lines=0,cycles=0,last_vs=-100,last_hs=-100,last_end=-100;
reg started=0,old_de=0,old_hs=0,old_vs=0;
reg [11:0] high_half;
reg [3:0] high_ctrl;
reg [23:0] pixel;
always @(posedge forwarded[0]) begin high_half=pins;high_ctrl=ctrl[3:0];end
always @(negedge forwarded[0]) begin
 cycles=cycles+1;
 if(cycles>5) begin
  if(ctrl[3:0]!==high_ctrl) $fatal(1,"control halves differ");
  pixel={high_half,pins};
  if(ctrl[0]) $fatal(1,"unexpected SKIP");
  if(!ctrl[1] && pixel!==0) $fatal(1,"nonzero blanking/EOL word");
  if(ctrl[3]) begin
   if(old_vs) $fatal(1,"wide VS");
   if(started) begin
    if(rx_y!=270 || lines!=312) $fatal(1,"frame rows=%0d lines=%0d",rx_y,lines);
    frames=frames+1;
    if(frames==2) begin
     $display("PASS 384x270 DDR receiver: two PAL frames, all 382 source pixels intact, two exact edge copies, zero blanking, sync spacing, both DDR halves");
     $finish;
    end
   end
   started=1;rx_y=0;lines=0;last_vs=cycles;
  end
  if(ctrl[2]) begin
   if(old_hs || ctrl[1] || cycles-last_vs<3 || cycles-last_end<2) $fatal(1,"HS spacing");
   last_hs=cycles;if(started)lines=lines+1;
  end
  if(started && ctrl[1]) begin
   if(!old_de && cycles-last_hs<2) $fatal(1,"DE spacing");
   if(pixel!==color(rx_x<382?rx_x:381,rx_y)) $fatal(1,"pixel row=%0d x=%0d got=%h",rx_y,rx_x,pixel);
   rx_x=rx_x+1;
  end
  if(started && !ctrl[1] && old_de) begin
   if(rx_x!=384) $fatal(1,"line width %0d, expected 384",rx_x);
   rx_x=0;rx_y=rx_y+1;last_end=cycles;
  end
  old_de=ctrl[1];old_hs=ctrl[2];old_vs=ctrl[3];
 end
end
task tick;begin @(negedge clk);end endtask
initial begin
 repeat(10)tick();
 for(tx_f=0;tx_f<3;tx_f=tx_f+1) begin
  for(tx_y=0;tx_y<312;tx_y=tx_y+1) begin
   for(tx_x=0;tx_x<504;tx_x=tx_x+1) begin
    vs=tx_y==0 && tx_x==0; hs=tx_x==0;
    vb=tx_y<28 || tx_y>=298;
    hb=tx_x<97 || tx_x>=479;
    src=(!hb&&!vb)?color(tx_x-97,tx_y-28):24'hffffff;
    tick();
   end
  end
 end
 $fatal(1,"timeout");
end
endmodule
