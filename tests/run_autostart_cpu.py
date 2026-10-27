"""Execute an original ROM fixture on the real 6510, through the top-level tap.
This checks observation wiring, not compatibility with every replacement KERNAL.
"""
from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'converted'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
rom=bytearray([0xea]*16384)
boot=bytes.fromhex('78 d8 a2 ff 9a a9 2f 85 00 a9 37 85 01 ad 83 a4 4c 83 a4')
rom[0x2000:0x2000+len(boot)]=boot
rom[0x483:0x486]=bytes.fromhex('20 cd e5')
rom[0x25cd:0x25d2]=bytes.fromhex('a5 c6 4c cd e5')
rom[0x3ffc:0x3ffe]=bytes.fromhex('00 e0')
(T/'autostart_cpu_rom.hex').write_text('\n'.join(f'{b:02x}' for b in rom))
tb=r'''`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #6.734 a=~a;always #15.859 b=~b;
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),.bridge_addr(32'b0),.bridge_wr(1'b0),
 .bridge_wr_data(32'b0),.bridge_rd(1'b0),.cont_update(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0));
defparam dut.disk_autostart.SETTLE_MS=2;
integer i,entries=0,waits=0;
always @(posedge b)if(dut.monitor_valid)begin
 if(dut.monitor_addr==16'ha483)begin
  if(dut.monitor_data!==8'h20)$fatal(1,"opcode data misaligned");entries=entries+1;
 end
 if(dut.monitor_addr==16'he5cd)begin
  if(dut.monitor_data!==8'ha5)$fatal(1,"wait opcode data misaligned");waits=waits+1;
 end
end
initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.host_write=0;
 force dut.pause_request=0;force dut.disk_pause=0;force dut.disk9_pause=0;
 force dut.load_state=11;force dut.disk_mounted=0;
 for(i=0;i<65536;i=i+1)dut.main_ram[i]=0;
 $readmemh("autostart_cpu_rom.hex",dut.c64.buslogic.kernel_c64.ram);
 repeat(100)@(negedge b);force dut.core_run=1;
 wait(entries==1 && waits>2);repeat(100)@(negedge b);
 force dut.load_state=12;
 repeat(100)@(negedge b);
 if(dut.disk_autostart.line_dirty)$fatal(1,"boot keyboard guard incorrectly treated as user input");
 wait(dut.autostart_prompt);@(negedge b);
 if(entries!=1 || waits<2)$fatal(1,"opcode tap includes data reads or missed CPU fetches %d/%d",entries,waits);
 force dut.os_menu=1;force dut.cont1_key=32'h20;repeat(8)@(negedge b);
 force dut.disk_mounted=1;repeat(8)@(negedge b);
 force dut.os_menu=0;repeat(16)@(negedge b);
 if(dut.autostart_typing || dut.autostart_keys!=0)$fatal(1,"menu-closing button started typing");
 if(dut.disk_autostart.state!=1)$fatal(1,"menu-closing button cancelled request");
 force dut.cont1_key=0;
 wait(dut.autostart_typing);@(negedge b);
 if(dut.combined_keys!==(64'b1<<42))$fatal(1,"top-level L contact missing");
 force dut.cont1_key=32'h20;repeat(8)@(negedge b);
 if(dut.autostart_keys!==0)$fatal(1,"top-level controller cancel failed");
 $display("PASS actual 6510 opcode tap: ROM data fetch excluded, READY observed, mount CDC, menu-close held-button guard, LOAD contact, controller cancels");$finish;
end
initial begin #10000000;$fatal(1,"CPU tap timeout pc=%h entries=%d waits=%d",dut.c64.cpuaddr_pre,entries,waits);end
endmodule
'''
(T/'tb_autostart_cpu.sv').write_text(tb)
sources=[T/'tb_autostart_cpu.sv',P/'core/core_top.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources += [P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_pcm.sv','pocket_ram_arbiter.sv','pocket_sample_memory.sv','pocket_keyboard.sv','pocket_autostart.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
sources+=list(O.glob('sid_*.sv'))
from drive_sim import drive_sources
from cartridge_sim import cartridge_sources
sources+=drive_sources()+cartridge_sources()
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'autostart_cpu.vvp'),*map(str,sources)],capture_output=True,text=True)
assert r.returncode==0,r.stderr[-4000:]
r=subprocess.run([str(B/'vvp.exe'),str(T/'autostart_cpu.vvp')],cwd=T,capture_output=True,text=True,timeout=300)
log=r.stdout+r.stderr;(T/'autostart_cpu.log').write_text(log);print(log[-1000:])
assert r.returncode==0 and 'PASS actual 6510' in log

