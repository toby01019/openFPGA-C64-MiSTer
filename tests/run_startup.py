from pathlib import Path
import subprocess,sys
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'converted'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
tb='''`timescale 1ns/1ps
module tb;
reg a=0,b=0; always #6.734 a=~a;always #15.873 b=~b;
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),
 .bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(16'b0),.cont2_key(16'b0),.cont3_key(16'b0),.cont4_key(16'b0));
initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;
 for(integer n=0;n<120;n=n+1) begin
 @(negedge b);
 $display("n=%0d pre=%h sys=%h ph=%b pix=%b vic=%b x=%h state=%h reset=%b",n,dut.c64.precycle,dut.c64.syscycle,dut.c64.phi0_cpu,dut.c64.enablepixel,dut.c64.enablevic,dut.c64.vic.rasterx,dut.c64.vic.viccycle,dut.core_reset);
 end
 repeat(5000) @(posedge b);
 if((^dut.c64.vic.rasterx)===1'bx) $fatal(1,"unknown VIC raster");
 $display("PASS startup raster=%h/%h",dut.c64.vic.rasterx,dut.c64.vic.rastery);$finish;
end
endmodule
'''
# Icarus 10.1 does not support loop-local variables.
tb=tb.replace('initial begin','integer n;\ninitial begin',1).replace('for(integer n=0','for(n=0')
mode='startup'
if '--cpu' in sys.argv:
 mode='cpu';tb=(T/'tb_cpu.sv').read_text()
if '--ui-transparency' in sys.argv:
 mode='ui-transparency';tb=(T/'tb_ui_transparency.sv').read_text()
(T/'tb_startup.sv').write_text(tb)
sources=[T/'tb_startup.sv',O/'core_top_sim.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources += [P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_keyboard.sv','pocket_autostart.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv']]
sources += list(O.glob('sid_*.sv'))
from drive_sim import drive_sources
sources += drive_sources()
from cartridge_sim import cartridge_sources
sources += cartridge_sources()
sources += [P/'core'/n for n in ['pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'startup.vvp'),*[str(s)for s in sources]],capture_output=True,text=True)
assert r.returncode==0,r.stderr[-2000:]
r=subprocess.run([str(B/'vvp.exe'),str(T/'startup.vvp')],capture_output=True,text=True)
(T/f'{mode}.log').write_text(r.stdout+r.stderr)
print(r.stdout[-3000:]+r.stderr);assert r.returncode==0 and 'PASS' in r.stdout
