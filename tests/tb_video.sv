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
video_sync dut(.clk32(clk),.pause(1'b0),.hsync(raw_hs),.vsync(raw_vs),
 .ntsc(1'b0),.wide(1'b0),.hsync_out(hs),.vsync_out(vs),.hblank(hb),.vblank(vb));
reg old_hs=0,old_vs=0;
integer row_samples=0,frame_samples=0,active_lines=0,frame_lines=0;
integer tick=0,last_hs=0,checked=0;
reg started=0;
always @(negedge clk) begin
 tick=tick+1;
 if(!hb && !vb && started) begin row_samples=row_samples+1;frame_samples=frame_samples+1;end
 if(hs && !old_hs) begin
  if(started) begin
   if(tick-last_hs!=2016) $fatal(1,"PAL line period wrong");
   frame_lines=frame_lines+1;
   if(row_samples>0) begin
    if(row_samples!=1528) $fatal(1,"active width wrong: %0d",row_samples);
    active_lines=active_lines+1;
   end
  end
  row_samples=0;last_hs=tick;
 end
 if(vs && !old_vs) begin
  if(started) begin
   if(frame_samples!=412560 || active_lines!=270 || frame_lines!=312)
     $fatal(1,"PAL frame wrong pixels=%0d active=%0d total=%0d",frame_samples,active_lines,frame_lines);
   checked=checked+1;
   if(checked==2) begin
    $display("PASS PAL adapter: two complete frames, 312 lines, 270 active lines, 1528 samples per line (382 VIC pixels x4)");$finish;
   end
  end
  started=1;frame_samples=0;active_lines=0;frame_lines=0;
 end
 old_hs=hs;old_vs=vs;
end
initial begin #50000000;$fatal(1,"video timeout");end
endmodule
