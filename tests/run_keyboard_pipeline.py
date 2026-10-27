"""Bit-exact pipelined renderer versus the preserved 0.4.5 renderer."""
from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
reference=(T/'keyboard_video_before_pipeline.sv').read_text().replace('module pocket_keyboard_video(', 'module keyboard_video_reference(')
(T/'keyboard_video_reference.sv').write_text(reference)
tb=r'''`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg pause=0,vs=0,active=0,visible=0,macro_busy=0;
reg [23:0] bg=24'h3636a8;
reg [3:0] row=2,col=2;reg [63:0] sticky=64'h8000,held=0;
reg [1:0] tr=0;
wire [23:0] original,legacy,pipelined;
keyboard_video_reference refui(.clk(clk),.pause(pause),.vsync(vs),.active(active),.visible(visible),.rgb(bg),
 .selected_row(row),.selected_col(col),.sticky(sticky),.held(held),.macro_busy(macro_busy),.transparency(tr),.mixed_rgb(original));
pocket_keyboard_video compat(.clk(clk),.pause(pause),.vsync(vs),.active(active),.visible(visible),.rgb(bg),
 .selected_row(row),.selected_col(col),.sticky(sticky),.held(held),.macro_busy(macro_busy),.transparency(tr),.mixed_rgb(legacy));
pocket_keyboard_video #(.PIPELINED(1)) pipeui(.clk(clk),.pause(pause),.vsync(vs),.active(active),.visible(visible),.rgb(bg),
 .selected_row(row),.selected_col(col),.sticky(sticky),.held(held),.macro_busy(macro_busy),.transparency(tr),.mixed_rgb(pipelined));
reg [23:0] history[0:3];integer n,cycles=0,checked=0;
initial for(n=0;n<4;n=n+1)history[n]=0;
always @(posedge clk)begin
 history[0]<=legacy;for(integer k=1;k<4;k=k+1)history[k]<=history[k-1];
 cycles=cycles+1;#1;
 // Only unshifted pixels outside the LOAD* shortcut row match the old UI.
 if(!compat.shift_labels && !(refui.y_active>=239 && refui.y_active<251) && legacy!==original)$fatal(1,"combinational compatibility mismatch x=%d y=%d",refui.pixel_x,refui.y_active);
 if(cycles>5 && pipelined!==history[3])$fatal(1,"pipeline mismatch cycle=%d got=%h expected=%h x=%d y=%d",cycles,pipelined,history[3],refui.pixel_x,refui.y_active);
 checked=checked+1;
end
task tick;begin @(negedge clk);end endtask
integer mode,y,x;
initial begin
 repeat(8)tick();
 for(mode=0;mode<3;mode=mode+1)begin
  tr=mode;vs=1;repeat(4)tick();vs=0;repeat(8)tick();
  for(y=0;y<270;y=y+1)begin
   row=y%7;col=(y/7)%12;visible=(y%11)!=0;macro_busy=mode==2;
   sticky=(y%4==0 ? 64'h8000:y%4==1 ? (64'b1<<52):0) | (64'b1 << (y%64));
   held=(y%4==2 ? 64'h8000:0) | (64'b1 << ((y+5)%64));
   active=1;
   for(x=0;x<1528;x=x+1)begin
    if(x%4==0)bg={8'(x^y),8'(x+y),8'(x*3+y)};tick();
   end
   active=0;repeat(32)tick();
  end
  pause=1;repeat(12)tick();pause=0;visible=0;repeat(8)tick();
  $display("PASS pixel equivalence transparency=%0d checked=%0d",mode,checked);$fflush();
 end
 $display("PASS keyboard pipeline: %0d exact core samples current combinational/pipeline, unshifted pixels outside LOAD* shortcut row unchanged versus 0.4.5, all 3 transparency modes, selected/held/sticky keys, banner, engraving, visibility/pause, exact 4-clock delay",checked);$finish;
end
initial begin #20000000;$fatal(1,"pipeline test timeout");end
endmodule
'''
# Keep compatible with the bundled Icarus 10.1.
tb=tb.replace('integer n,cycles','integer k,n,cycles').replace('for(integer k=1','for(k=1')
(T/'tb_keyboard_pipeline.sv').write_text(tb)
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-s','tb','-o',str(T/'keyboard_pipeline.vvp'),str(T/'tb_keyboard_pipeline.sv'),str(T/'keyboard_video_reference.sv'),str(P/'core/pocket_keyboard_video.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
with (T/'keyboard_pipeline.log').open('w') as out:
 r=subprocess.run([str(B/'vvp.exe'),str(T/'keyboard_pipeline.vvp')],stdout=out,stderr=subprocess.STDOUT,text=True,timeout=600)
log=(T/'keyboard_pipeline.log').read_text();print(log)
assert r.returncode==0 and 'PASS keyboard pipeline' in log,log
