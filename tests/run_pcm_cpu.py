"""Full core boundary: APF mailbox preload -> physical RAM -> C64 IOF -> PCM."""
from pathlib import Path
import subprocess
from drive_sim import drive_sources
from cartridge_sim import cartridge_sources
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'converted'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
code=bytearray.fromhex('78 a9 2f 85 00 a9 37 85 01 ad 18 df c9 50 d0 fe ad 19 df c9 4b d0 fe ad 1b df c9 01 d0 fe')
def poke(a,v):code.extend([0xa9,v,0x8d,a&255,a>>8])
for a,v in [(0xdf20,0),(0xdf21,48),(0xdf22,8),(0xdf24,1),(0xdf25,0),(0xdf26,0),(0xdf27,0),
 (0xdf29,0),(0xdf2a,0),(0xdf2b,64),(0xdf2e,0),(0xdf2f,142),(0xdf20,0x11),(0xc120,0xa5)]:poke(a,v)
loop=0xe000+len(code);code+=bytes([0x4c,loop&255,loop>>8])
(T/'pcm-cpu-rom.hex').write_text('\n'.join(f'{v:02x}'for v in code))
tb=r'''
`timescale 1ns/1ps
module tb;
 reg a=0,b=0;always #6.734 a=~a;always #15.873 b=~b;
 reg valid=0;reg[25:0]cmd=0;reg[7:0]rom[0:SIZE-1];integer i,consumed=0,expected;
 wire[21:16]pa;tri[15:0]pd;wire pc,padv,pcre,pce0,pce1,poe,pwe,pub,plb;
 core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),.bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0),
 .cram0_a(pa),.cram0_dq(pd),.cram0_wait(1'b1),.cram0_clk(pc),.cram0_adv_n(padv),.cram0_cre(pcre),.cram0_ce0_n(pce0),.cram0_ce1_n(pce1),
 .cram0_oe_n(poe),.cram0_we_n(pwe),.cram0_ub_n(pub),.cram0_lb_n(plb));
 psram_model physical(.a(pa),.dq(pd),.ramclk(pc),.adv(padv),.cre(pcre),.ce0(pce0),.ce1(pce1),.oe(poe),.we(pwe),.ub(pub),.lb(plb));
 function[7:0]data_byte(input integer n);data_byte=(n*37+11)&255;endfunction
 task send(input[25:0]v);begin
 @(negedge a);cmd=v;valid=1;wait(dut.host_done);@(negedge a);valid=0;
 wait(!dut.host_done);repeat(3)@(negedge a);
 end endtask
 always @(posedge dut.clk_core)if(!dut.core_reset && dut.reu_memory.pcm.sample_tick && dut.reu_memory.pcm.active[0] &&
  dut.reu_memory.pcm.timer[0]==0 && dut.reu_memory.pcm.next_valid[0])begin
  expected={data_byte(consumed*2+1),data_byte(consumed*2)};
  if(dut.reu_memory.pcm.next_sample[0]!==expected[15:0])$fatal(1,"full-core PCM sample %d",consumed);
  consumed=consumed+1;
 end
 initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;
 force dut.host_write=valid;force dut.host_data=cmd;force dut.pcm_enabled=1;force dut.reu_config=1;
 $readmemh("pcm-cpu-rom.hex",rom);repeat(100)@(negedge b);
 for(i=0;i<SIZE;i=i+1)send({2'b01,16'(16'h2000+i),rom[i]});
 send({2'b01,16'h3ffc,8'h00});send({2'b01,16'h3ffd,8'he0});
 send({4'b1101,1'b1,21'd64});
 for(i=0;i<64;i=i+1)send({4'b1100,1'b1,13'b0,data_byte(i)});
 send({4'b1110,1'b1,21'b0});repeat(10)@(negedge b);
 if(!dut.reu_memory.bank_valid || physical.writes!=64)$fatal(1,"sample bank not completely preloaded");
 force dut.core_run=1;wait(dut.main_ram[16'hc120]===8'ha5);
 wait(consumed==32);wait(!dut.reu_memory.pcm.active[0]);
 if(dut.reu_memory.underrun || physical.reads!=64)$fatal(1,"PCM underflow/read count");
 $display("PASS full-core PCM: real APF mailbox preload/physical byte lanes, actual 6510 IOF signature + channel programming alongside REU, all32 LE16 words exact, no underrun");$finish;
 end
 initial begin #10000000;$fatal(1,"full-core PCM timeout marker=%h consumed=%d",dut.main_ram[16'hc120],consumed);end
endmodule
'''.replace('SIZE',str(len(code)))
(T/'tb_pcm_cpu.sv').write_text(tb);(O/'core_top_sim.sv').write_text((P/'core/core_top.sv').read_text())
sources=[T/'tb_pcm_cpu.sv',T/'psram_model.sv',O/'core_top_sim.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources +=[P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_pcm.sv','pocket_ram_arbiter.sv','pocket_sample_memory.sv','pocket_keyboard.sv','pocket_autostart.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
sources+=list(O.glob('sid_*.sv'))+drive_sources()+cartridge_sources()
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'pcm-cpu.vvp'),*map(str,sources)],capture_output=True,text=True)
(T/'pcm-cpu-compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr[-3000:]
with(T/'pcm-cpu.log').open('w')as out:r=subprocess.run([str(B/'vvp.exe'),'-i',str(T/'pcm-cpu.vvp')],cwd=T,stdout=out,stderr=subprocess.STDOUT,timeout=600)
log=(T/'pcm-cpu.log').read_text();print(log[-1800:]);assert r.returncode==0 and 'PASS full-core PCM'in log
