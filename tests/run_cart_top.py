from pathlib import Path
import subprocess,struct
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'converted'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
# The wrapper is already SystemVerilog; never reuse an old generated copy.
(O/'core_top_sim.sv').write_text((P/'core/core_top.sv').read_text())
payload=bytearray([0xea]*8192)
# Execute ROM, write/read ordinary RAM, write RAM below ROM, then read ROM again.
program=bytes.fromhex('a9 3c 8d 20 c1 ad 20 c1 c9 3c d0 fe a9 77 8d 00 80 ad 00 80 c9 a9 d0 fe a9 5a 8d 21 c1 4c 1d 80')
payload[:len(program)]=program
raw=b'C64 CARTRIDGE   '+struct.pack('>IHHBB',64,0x100,0,0,1)+bytes(38)
raw+=b'CHIP'+struct.pack('>IHHHH',8208,0,0,0x8000,8192)+payload
(T/'cart_top.hex').write_text('\n'.join(f'{x:02x}'for x in raw))
tb=r'''`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #6.734 a=~a;always #15.873 b=~b;
reg valid=0;reg[25:0] cmd=0;reg[7:0]crt[0:8271];integer i;
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),.bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0));
task send(input[25:0]v);begin
 @(negedge a);cmd=v;valid=1;wait(dut.host_done);@(negedge a);valid=0;
 wait(!dut.host_done);repeat(3)@(negedge a);
end endtask
task rom(input[13:0]addr,input[7:0]v);begin send({2'd1,2'b0,addr,v});end endtask
initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;
 force dut.host_write=valid;force dut.host_data=cmd;
 // This diagnostic writes every RAM location it subsequently checks.
 // Leave other RAM unknown, as it would be before firmware initialization.
 $readmemh("cart_top.hex",crt);repeat(100)@(negedge b);$display("PROGRESS initial clocks %t",$time);
 // Own KERNAL substitute sets CPU port and jumps into cartridge $8000.
 rom('h2000,'h78);rom('h2001,'ha9);rom('h2002,'h2f);rom('h2003,'h85);rom('h2004,0);
 rom('h2005,'ha9);rom('h2006,'h37);rom('h2007,'h85);rom('h2008,1);
 rom('h2009,'h4c);rom('h200a,0);rom('h200b,'h80);
 rom('h3ffc,0);rom('h3ffd,'he0);rom('h3ffa,0);rom('h3ffb,'he0);rom('h3ffe,0);rom('h3fff,'he0);
 $display("PROGRESS KERNAL uploaded %t",$time);
 send({4'b1101,22'd8272});for(i=0;i<8272;i=i+1)begin send({4'b1100,14'b0,crt[i]});if(i%1024==0)$display("PROGRESS CRT byte %d time %t",i,$time);end send({4'b1110,22'b0});
 repeat(40)@(negedge b);if(!dut.cart_attached || dut.cart_error)$fatal(1,"CRT upload failed");
 force dut.core_run=1;wait(dut.main_ram['hc121]==8'h5a);
 if(dut.main_ram['hc120]!==8'h3c || dut.main_ram['h8000]!==8'h77)$fatal(1,"RAM mapping failed");
 $display("PASS actual C64 CPU executes CRT ROM, ordinary RAM read/write and RAM beneath ROM via APF byte mailbox");
 force dut.core_run=0;repeat(100)@(negedge b);dut.main_ram['hc121]=0;
 force dut.core_run=1;wait(dut.main_ram['hc121]==8'h5a);
 $display("PASS C64 reset preserves attached cartridge and executes it again");
 force dut.core_run=0;repeat(100)@(negedge b);send({4'b1111,22'b0});repeat(20)@(negedge b);
 if(dut.cart_attached || !dut.cart_exrom || !dut.cart_game)$fatal(1,"EJECT failed");
 $display("PASS CRT eject releases GAME/EXROM");$finish;
end
initial begin #100000000;$fatal(1,"CRT top timeout addr=%h RAM=%h",dut.c64_addr,dut.main_ram['hc121]);end
endmodule
'''
(T/'tb_cart_top.sv').write_text(tb)
sources=[T/'tb_cart_top.sv',O/'core_top_sim.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources += [P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_pcm.sv','pocket_ram_arbiter.sv','pocket_sample_memory.sv','pocket_keyboard.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
sources += list(O.glob('sid_*.sv'))
from drive_sim import drive_sources
from cartridge_sim import cartridge_sources
sources+=drive_sources()+cartridge_sources()
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'cart_top.vvp'),*[str(s)for s in sources]],capture_output=True,text=True)
(T/'cart_top_compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr[-3000:]
with (T/'cart_top.log').open('w') as log:
 r=subprocess.run([str(B/'vvp.exe'),'-i',str(T/'cart_top.vvp')],cwd=T,stdout=log,stderr=subprocess.STDOUT,text=True,timeout=300)
result=(T/'cart_top.log').read_text();print(result);assert r.returncode==0 and 'PASS CRT eject' in result
