from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
tb=r'''`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg loading=0,active=1;reg [1:0] tr=0;
wire [23:0] plain,pipeui;reg [10:0] x=0;reg [8:0] y=0;
pocket_keyboard_video ui(.clk(clk),.pause(1'b1),.vsync(1'b0),.active(active),.visible(1'b0),
 .loading(loading),.rgb(24'h3636a8),.selected_row(4'b0),.selected_col(4'b0),.sticky(64'b0),.held(64'b0),
 .macro_busy(1'b0),.transparency(tr),.mixed_rgb(plain));
pocket_keyboard_video #(.PIPELINED(1)) piped(.clk(clk),.pause(1'b1),.vsync(1'b0),.active(active),.visible(1'b0),
 .loading(loading),.rgb(24'h3636a8),.selected_row(4'b0),.selected_col(4'b0),.sticky(64'b0),.held(64'b0),
 .macro_busy(1'b0),.transparency(tr),.mixed_rgb(pipeui));
reg [23:0] h[0:3];integer i,t,m,lit=0;
always @(posedge clk)begin
 h[0]<=plain;for(integer k=1;k<4;k=k+1)h[k]<=h[k-1];
 #1;if(t>5 && pipeui!==h[3])$fatal(1,"activity changed pipeline latency");
end
initial begin
 force ui.x_transport=x;force ui.y_active=y;force piped.x_transport=x;force piped.y_active=y;
 for(i=0;i<4;i=i+1)h[i]=0;t=0;
 for(m=0;m<3;m=m+1)begin
 tr=m;loading=1;
 for(y=0;y<270;y=y+1)for(x=0;x<1528;x=x+4)begin
  @(negedge clk);t=t+1;
  if(x/4>=358 && x/4<370 && y>=8 && y<20)begin
   if(plain===24'h3636a8)$fatal(1,"missing activity pixel");lit=lit+1;
  end else if(plain!==24'h3636a8)$fatal(1,"activity corrupts C64 pixel x=%d y=%d",x/4,y);
 end
 end
 loading=0;x=1440;y=12;repeat(6)@(negedge clk);
 if(plain!==24'h3636a8 || pipeui!==24'h3636a8)$fatal(1,"hidden lamp changes picture");
 loading=1;active=0;repeat(6)@(negedge clk);
 if(pipeui!==24'h3636a8)$fatal(1,"activity drawn in blanking");
 if(lit!=432)$fatal(1,"wrong badge footprint %d",lit);
 $display("PASS activity: exact 12x12 footprint, all other pixels preserved, all transparency settings, hide/blanking, exact four-cycle pipeline");$finish;
end
endmodule
'''.replace('integer i,t,m','integer k,i,t,m').replace('for(integer k=1','for(k=1')
(T/'tb_activity.sv').write_text(tb)
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-s','tb','-o',str(T/'activity.vvp'),str(T/'tb_activity.sv'),str(P/'core/pocket_keyboard_video.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'activity.vvp')],capture_output=True,text=True,timeout=120)
log=r.stdout+r.stderr;(T/'activity.log').write_text(log);print(log)
assert r.returncode==0 and 'PASS activity' in log
