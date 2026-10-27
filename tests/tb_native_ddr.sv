`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg [1:0] phase=0;
integer x=0,y=0;
always @(posedge clk) begin
 phase<=phase+1'b1;
 if(phase==3) begin
  if(x==503) begin x<=0;if(y==311)y<=0;else y<=y+1;end
  else x<=x+1;
 end
end
wire hs,vs,hb,vb;
wire raw_hs=x>=396 && x<496;
wire raw_vs=y==300;
video_sync blanker(.clk32(clk),.pause(1'b0),.hsync(raw_hs),.vsync(raw_vs),
 .ntsc(1'b0),.wide(1'b0),.hsync_out(hs),.vsync_out(vs),.hblank(hb),.vblank(vb));
reg dotclk=0; always #20 dotclk=~dotclk;
wire ohs,ovs,de,skip;
wire [23:0] rgb;
// Vary source color every VIC dot, including the wrapped horizontal edge.
wire [23:0] source_rgb={7'b0,y[8:0],x[7:0]};
pocket_video #(.NATIVE_PIXEL_CLOCK(1)) dut(.clk(dotclk),.enable(1'b1),.hsync(hs),.vsync(vs),.hblank(hb),.vblank(vb),
 .rgb(source_rgb),.video_hs(ohs),.video_vs(ovs),.video_de(de),.video_skip(skip),.video_rgb(rgb));
integer tick=0,last_hs=0,last_vs=-100,last_de_end=-100;
integer row_pixels=0,row_clocks=0,frame_pixels=0,active_lines=0,frame_lines=0,checked=0;
integer previous_x=0,current_x=0,accept_gap=0;
reg old_hs=0,old_vs=0,old_de=0,started=0;
reg [23:0] expected_rgb;
always @(posedge dotclk) expected_rgb<=source_rgb;
always @(negedge dotclk) begin
 tick=tick+1;accept_gap=accept_gap+1;
 if(skip) $fatal(1,"SKIP outside DE");
 if(!de && rgb!==0) $fatal(1,"nonzero RGB outside DE");
 if(de && rgb!==expected_rgb) $fatal(1,"RGB pipeline mismatch");
 if(ohs && old_hs) $fatal(1,"HS wider than one clock");
 if(ovs && old_vs) $fatal(1,"VS wider than one clock");
 if(ovs) begin
  last_vs=tick;
  if(started) begin
   if(frame_pixels!=103140 || active_lines!=270 || frame_lines!=312)
    $fatal(1,"frame mismatch pixels=%0d active=%0d total=%0d",frame_pixels,active_lines,frame_lines);
   checked=checked+1;
   if(checked==2) begin
    $display("PASS Pocket VIDEO: two complete PAL frames; 382x270 accepted pixels; 312 lines; one-cycle HS/VS; VS-to-HS gap; continuous DE; native pixel clock, SKIP disabled; RGB sample order");
    $finish;
   end
  end
  started=1;frame_pixels=0;active_lines=0;frame_lines=0;
 end
 if(ohs) begin
  if(tick-last_vs<3) $fatal(1,"HS too close to VS");
  if(de || tick-last_de_end<2) $fatal(1,"HS too close to DE end");
  if(started) begin
   if(last_hs!=0 && tick-last_hs!=504) $fatal(1,"PAL line period wrong");
   frame_lines=frame_lines+1;
  end
  last_hs=tick;
 end
 if(de && !old_de) begin
  if(tick-last_hs<2) $fatal(1,"DE too close to HS");
  row_pixels=0;row_clocks=0;
 end
 if(de) begin
  row_clocks=row_clocks+1;
  if(!skip) begin
   current_x=rgb[7:0];
   if(row_pixels>0 && (current_x!=((previous_x+1)&255)) && !(previous_x==247 && current_x==0))
     $fatal(1,"lost/duplicated VIC pixel: %0d -> %0d",previous_x,current_x);
   if(row_pixels>0 && accept_gap!=1) $fatal(1,"incorrect skip cadence");
   previous_x=current_x;accept_gap=0;
   row_pixels=row_pixels+1;
   if(started)frame_pixels=frame_pixels+1;
  end
 end
 if(!de && old_de) begin
  last_de_end=tick;
  if(started) begin
   if(row_pixels!=382 || row_clocks!=382) $fatal(1,"line width mismatch pixels=%0d clocks=%0d",row_pixels,row_clocks);
   active_lines=active_lines+1;
  end
 end
 old_hs=ohs;old_vs=ovs;old_de=de;
end
initial begin #50000000;$fatal(1,"video timeout");end

wire [11:0] pins; wire [11:0] control; wire [11:0] forwarded;
reg dot90=0; always begin #10; dot90=~dot90; #30; dot90=~dot90; end
// dotclk rises at 20,60,...; use a delayed copy, with quarter-period shift.
wire delayed_dot; assign #10 delayed_dot=dotclk;
mf_ddio_bidir_12 color_ddr(.oe(1'b1),.datain_h(rgb[23:12]),.datain_l(rgb[11:0]),.outclock(dotclk),.padio(pins));
mf_ddio_bidir_12 control_ddr(.oe(1'b1),.datain_h({8'b0,ovs,ohs,de,skip}),.datain_l({8'b0,ovs,ohs,de,skip}),.outclock(dotclk),.padio(control));
mf_ddio_bidir_12 clock_ddr(.oe(1'b1),.datain_h(12'b1),.datain_l(12'b0),.outclock(delayed_dot),.padio(forwarded));
reg [23:0] expected_wire;reg [3:0] expected_control;
always @(posedge dotclk) begin expected_wire<=rgb;expected_control<={ovs,ohs,de,skip};end
always @(posedge forwarded[0]) if(tick>10) begin
 if(pins!==expected_wire[23:12] || control[3:0]!==expected_control) $fatal(1,"DDR upper/control mismatch");
end
always @(negedge forwarded[0]) if(tick>10) begin
 if(pins!==expected_wire[11:0] || control[3:0]!==expected_control) $fatal(1,"DDR lower/control mismatch");
end

endmodule
