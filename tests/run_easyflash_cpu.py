"""Physical PSRAM -> actual C64 bus: Ultimax reset, RAM bootstrap, bank/IO2 reads."""
from pathlib import Path
import struct,subprocess
from drive_sim import drive_sources
from cartridge_sim import cartridge_sources
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'converted'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
code=bytearray.fromhex('a9 2f 85 00 a9 37 85 01 a9 07 8d 02 de a9 00 8d 00 de ad 00 80 c9 a5 d0 fe a9 01 8d 00 de ad 00 80 c9 3c d0 fe a9 69 8d 80 df ad 80 df c9 69 d0 fe a9 5a 8d 21 c1')
end=0x200+len(code);code+=bytes([0x4c,end&255,end>>8])
high=bytearray(b'\xff'*8192);high[:15]=bytes([0x78,0xa2,len(code)-1,0xbd,0x20,0xe0,0x9d,0,2,0xca,0x10,0xf7,0x4c,0,2]);high[32:32+len(code)]=code
for pos in [0x1ffa,0x1ffc,0x1ffe]:high[pos:pos+2]=b'\x00\xe0'
crt=bytearray(b'C64 CARTRIDGE   '+struct.pack('>IHHBB',64,0x100,32,1,0)+bytes(38))
for bank,address,payload in [(0,0x8000,bytes([0xa5])*8192),(1,0x8000,bytes([0x3c])*8192),(0,0xa000,high)]:
 crt+=b'CHIP'+struct.pack('>IHHHH',8208,2,bank,address,8192)+payload
(T/'easyflash-cpu.hex').write_text('\n'.join(f'{v:02x}'for v in crt))
tb=r'''
`timescale 1ns/1ps
module tb;
 reg a=0,b=0;always #6.734 a=~a;always #15.873 b=~b;
 reg valid=0;reg[25:0]cmd=0;reg[7:0]crt[0:SIZE-1];integer i,reads=0;
 wire[21:16]pa;tri[15:0]pd;wire pc,padv,pcre,pce0,pce1,poe,pwe,pub,plb;
 core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),.bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0),
 .cram1_a(pa),.cram1_dq(pd),.cram1_wait(1'b1),.cram1_clk(pc),.cram1_adv_n(padv),.cram1_cre(pcre),.cram1_ce0_n(pce0),.cram1_ce1_n(pce1),
 .cram1_oe_n(poe),.cram1_we_n(pwe),.cram1_ub_n(pub),.cram1_lb_n(plb));
 defparam dut.cartridge_port.easyflash_port.ef.INIT_WORDS=1024;
 cart_psram_model physical(.a(pa),.dq(pd),.clk(pc),.adv(padv),.cre(pcre),.ce0(pce0),.ce1(pce1),.oe(poe),.we(pwe),.ub(pub),.lb(plb));
 task send(input[25:0]v);begin
 @(negedge a);cmd=v;valid=1;wait(dut.host_done);@(negedge a);valid=0;
 wait(!dut.host_done);repeat(3)@(negedge a);
 end endtask
 always @(posedge dut.clk_core)if(!dut.core_reset && !dut.c64_paused && dut.ram_ce && !dut.ram_we && (dut.c64_roml || dut.c64_romh || dut.c64_umax))begin
  if(!dut.cartridge_port.easyflash_port.ef.cache_hit && !dut.cartridge_port.easyflash_port.ef.status_oe)
   $fatal(1,"EasyFlash missed real CPU/VIC deadline addr=%h syscycle=%h",dut.c64_addr,dut.c64.syscycle);
  reads=reads+1;
 end
 initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;
 force dut.host_write=valid;force dut.host_data=cmd;
 $readmemh("easyflash-cpu.hex",crt);repeat(100)@(negedge b);
 send({4'b1101,22'dSIZE});for(i=0;i<SIZE;i=i+1)send({4'b1100,14'b0,crt[i]});send({4'b1110,22'b0});
 repeat(40)@(negedge b);if(!dut.cart_attached || dut.cart_error)$fatal(1,"EasyFlash upload");
 force dut.core_run=1;wait(dut.main_ram[16'hc121]===8'h5a);
 if(reads<60)$fatal(1,"CPU did not execute cartridge bootstrap");
 $display("PASS EasyFlash actual C64 CPU/VIC + physical PSRAM: Ultimax reset vector/bootstrap, 16K mode, ROML bank0/1, IO2 RAM, %0d reads at real bus deadline",reads);$finish;
 end
 initial begin #50000000;$fatal(1,"EasyFlash CPU timeout addr=%h marker=%h",dut.c64_addr,dut.main_ram[16'hc121]);end
endmodule
'''.replace('SIZE',str(len(crt)))
(T/'tb_easyflash_cpu.sv').write_text(tb);(O/'core_top_sim.sv').write_text((P/'core/core_top.sv').read_text())
sources=[T/'tb_easyflash_cpu.sv',T/'cart_psram_model.sv',O/'core_top_sim.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources +=[P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_pcm.sv','pocket_ram_arbiter.sv','pocket_sample_memory.sv','pocket_keyboard.sv','pocket_autostart.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
sources+=list(O.glob('sid_*.sv'))+drive_sources()+cartridge_sources()
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'easyflash-cpu.vvp'),*map(str,sources)],capture_output=True,text=True)
(T/'easyflash-cpu-compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr[-3000:]
with(T/'easyflash-cpu.log').open('w')as out:r=subprocess.run([str(B/'vvp.exe'),'-i',str(T/'easyflash-cpu.vvp')],cwd=T,stdout=out,stderr=subprocess.STDOUT,timeout=900)
log=(T/'easyflash-cpu.log').read_text();print(log[-1800:]);assert r.returncode==0 and 'PASS EasyFlash actual'in log
