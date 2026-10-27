`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg pause=0,vsync=0,hsync=0,active=0,visible=0;
reg [23:0] background=24'h3636a8;
reg [3:0] selected_row=2,selected_col=2;
reg [63:0] sticky=64'h8000,held=0;
reg macro_busy=0;
reg dotclk=0; initial begin #35; forever #20 dotclk=~dotclk; end
wire [23:0] mixed,rgb;
wire de,skip,hs,vs;
pocket_keyboard_video #(.PIPELINED(1)) ui(.clk(clk),.pause(pause),.vsync(vsync),.active(active),
 .visible(visible),.rgb(background),.selected_row(selected_row),.selected_col(selected_col),
 .sticky(sticky),.held(held),.macro_busy(macro_busy),.transparency(2'b0),.mixed_rgb(mixed));
reg [23:0] staged_rgb=0;reg staged_hs=0,staged_vs=0,staged_active=0;
reg [2:0] ui_control[0:3];integer k;
initial for(k=0;k<4;k=k+1)ui_control[k]=0;
always @(posedge clk)begin
 ui_control[0]<={hsync,vsync,active};
 for(k=1;k<4;k=k+1)ui_control[k]<=ui_control[k-1];
 staged_rgb<=mixed;{staged_hs,staged_vs,staged_active}<=ui_control[3];
end
pocket_video #(.NATIVE_PIXEL_CLOCK(1),.RIGHT_PAD(2)) transport(.clk(dotclk),.enable(1'b1),.hsync(staged_hs),.vsync(staged_vs),
 .hblank(!staged_active),.vblank(1'b0),.rgb(staged_rgb),.video_rgb(rgb),.video_de(de),
 .video_skip(skip),.video_hs(hs),.video_vs(vs));
integer i,j,x,y,f,accepted=0,line_accepted=0;
integer saved_x,saved_y;
integer monitor_ticks=0;reg capture=0,old_de=0;
always @(posedge dotclk) begin
 #1;
 monitor_ticks=monitor_ticks+1;
 if(monitor_ticks>8 && !visible && mixed!==background) $fatal(1,"disabled overlay changes RGB");
 if(skip && !de) $fatal(1,"SKIP outside DE");
 if(capture) begin
  if(de && !skip) begin
   $fdisplay(f,"%06x",rgb);accepted=accepted+1;line_accepted=line_accepted+1;
  end
  if(!de && old_de) begin
   if(line_accepted!=384) $fatal(1,"accepted width=%0d",line_accepted);
   line_accepted=0;
  end
 end
 old_de=de;
end
task tick;begin @(negedge clk);end endtask
task line(input integer number);
begin
 hsync=1;repeat(4)tick();hsync=0;repeat(20)tick();
 active=1;
 for(j=0;j<1528;j=j+1)tick();
 active=0;repeat(32)tick();
end
endtask
initial begin
 tick();
 // Invisible overlay must remain a byte-exact passthrough.
 active=1;repeat(40)tick();active=0;repeat(4)tick();
 visible=1;active=1;repeat(20)tick();
 pause=1;saved_x=ui.x_transport;saved_y=ui.y_active;
 repeat(12)tick();
 if(ui.x_transport!=saved_x || ui.y_active!=saved_y) $fatal(1,"pause advances overlay coordinates");
 pause=0;repeat(8)tick();active=0;repeat(8)tick();
 vsync=1;repeat(4)tick();vsync=0;repeat(8)tick();
 if(ui.y_active!=0 || ui.x_transport!=0) $fatal(1,"frame reset failed");
 f=$fopen("native_keyboard_pixels.hex","w");capture=1;
 for(i=0;i<270;i=i+1)line(i);
 capture=0;$fclose(f);
 if(accepted!=384*270) $fatal(1,"frame pixel count=%0d",accepted);
 if(ui.y_active!=270) $fatal(1,"active line count=%0d",ui.y_active);
 // A held pause must preserve rendered selection as well as coordinates.
 visible=0;repeat(4)tick();
 $display("PASS keyboard video: disabled RGB passthrough, paused coordinates, VS reset, 270 active lines, 382 accepted pixels per line, native pixel sampling, RTL frame dump");
 $finish;
end
initial begin #10000000;$fatal(1,"review video timeout");end
endmodule
