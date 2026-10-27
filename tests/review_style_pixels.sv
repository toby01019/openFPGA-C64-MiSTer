`timescale 1ns/1ps
module tb;
`include "keyboard_layout.vh"
reg [23:0] bg=0;
wire [23:0] c0,c1,c2;
pocket_keyboard_video a(.clk(1'b0),.pause(1'b1),.vsync(1'b0),.active(1'b1),.visible(1'b1),.rgb(bg),
 .selected_row(4'd2),.selected_col(4'd2),.sticky(64'h8000),.held(64'h10),.macro_busy(1'b0),.transparency(2'd0),.mixed_rgb(c0));
pocket_keyboard_video b(.clk(1'b0),.pause(1'b1),.vsync(1'b0),.active(1'b1),.visible(1'b1),.rgb(bg),
 .selected_row(4'd2),.selected_col(4'd2),.sticky(64'h8000),.held(64'h10),.macro_busy(1'b0),.transparency(2'd1),.mixed_rgb(c1));
pocket_keyboard_video c(.clk(1'b0),.pause(1'b1),.vsync(1'b0),.active(1'b1),.visible(1'b1),.rgb(bg),
 .selected_row(4'd2),.selected_col(4'd2),.sticky(64'h8000),.held(64'h10),.macro_busy(1'b0),.transparency(2'd2),.mixed_rgb(c2));
integer x,y,fg,bk,refval,f,physical_row,origin,column,local_x;
reg [7:0] result;
initial begin
 // Exhaustive independent integer reference for both alpha levels.
 for(fg=0;fg<256;fg=fg+1)for(bk=0;bk<256;bk=bk+1)begin
  result=a.blend_channel(fg,bk,1);refval=(3*fg+bk)/4;
  if(result!==refval[7:0])$fatal(1,"25 percent channel rounding %0d %0d",fg,bk);
  result=a.blend_channel(fg,bk,2);refval=(fg+bk)/2;
  if(result!==refval[7:0])$fatal(1,"50 percent channel rounding %0d %0d",fg,bk);
 end
 f=$fopen("review_style_pixels.hex","w");
 // Style-only scan: coordinate counters frozen, each visible position supplied
 // explicitly. Real frame/pause/transport counting is checked separately.
 for(y=0;y<270;y=y+1)for(x=0;x<382;x=x+1)begin
  a.x_transport=x*4;b.x_transport=x*4;c.x_transport=x*4;
  physical_row=(y>=158 && y<222) ? (y-158)/16:(y>=223 && y<235) ? 5:6;
  origin=physical_row==5 ? 73:physical_row==6 ? 17:16;
  column=0;local_x=x-origin;
  while(local_x>=layout_pitch(physical_row,column) && column<16)begin
   local_x=local_x-layout_pitch(physical_row,column);column=column+1;
  end
  a.grid_col=column;b.grid_col=column;c.grid_col=column;
  a.grid_pixel=local_x;b.grid_pixel=local_x;c.grid_pixel=local_x;
  a.y_active=y;b.y_active=y;c.y_active=y;
  // Independent channel ramps exercise 0/255 and odd rounding combinations.
  bg={x[7:0],y[7:0],8'hff-x[7:0]};
  #1;
  $fdisplay(f,"%06x %06x %06x %06x",bg,c0,c1,c2);
 end
 $fclose(f);
 $display("PASS style RTL: exhaustive 65536 foreground/background pairs at 25 and 50 percent; three complete pixel dumps");
 $finish;
end
endmodule
