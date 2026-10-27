"""Actual Pocket bridge registers -> CDC -> C64 palette/SID ports."""
from pathlib import Path
import json,re,subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'converted'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
names=['Colodore','Ultimate','Pepto-PAL','Vice','Vice6569R1','Vice6569R5','Vice8565R2','Lemon64']
menu=json.loads((P/'dist/Cores/Experimental.C64MiSTer/interact.json').read_text())['interact']['variables']
assert len({v['id'] for v in menu})==len(menu)==10
assert [v['name'] for v in next(x for x in menu if x['id']==6)['options']]==names
assert next(x for x in menu if x['id']==6)['defaultval']==0 and next(x for x in menu if x['id']==7)['defaultval']==1
assert next(x for x in menu if x['id']==7)['options']==[{'value':0,'name':'6581'},{'value':1,'name':'8580'}]
dock=next(x for x in menu if x['id']==9)
assert dock['address']=='0xA0000024' and dock['defaultval']==1
assert [x['value'] for x in dock['options']]==[0,1,2]
reference_path=P.parent/'C64_MiSTer/rtl/fpga64_rgbcolor.vhd'
expected=[]
if reference_path.exists():
    reference=reference_path.read_text()
    for pal,body in re.findall(r'when "([01]{3})" =>(.*?end case;)',reference,re.S):
        colors=re.findall(r'when X"([0-9a-f])" => r <= X"([0-9a-f]{2})"; g <= X"([0-9a-f]{2})"; b <= X"([0-9a-f]{2})";',body,re.I)
        assert len(colors)==16
        for i,r,g,b in colors:expected.append(f'{r}{g}{b}')
else:
    # The source release carries the independently extracted upstream fixture.
    expected=(T/'menu_palette_expected.hex').read_text().splitlines()
assert len(expected)==128
(T/'menu_palette_expected.hex').write_text('\n'.join(expected))
tb=r'''`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #6.734 a=~a;always #15.859 b=~b;
reg [31:0] ba=0,bd=0;reg bw=0;wire [31:0] br;
reg [3:0] color=0;reg [23:0] expected[0:127];integer pal,idx,m;
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),
 .bridge_addr(ba),.bridge_wr(bw),.bridge_wr_data(bd),.bridge_rd(1'b1),.bridge_rd_data(br),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0));
task wr(input [31:0] addr,input [31:0] data);begin
 @(negedge a);ba=addr;bd=data;bw=1;
 @(negedge a);bw=0;repeat(8)@(negedge b);
end endtask
initial begin
 force dut.reset_n=1;force dut.core_run=0;
 force dut.c64.viccolorindex=color;
 $readmemh("menu_palette_expected.hex",expected);
 repeat(20)@(negedge b);
 if(dut.palette_sync!=0 || dut.sid_model_sync!=1)$fatal(1,"default palette/SID changed");
 for(pal=0;pal<8;pal=pal+1)begin
  wr(32'ha0000018,pal);
  if(br!==pal || dut.c64.palette!==pal[2:0])$fatal(1,"palette register/CDC %0d",pal);
  for(idx=0;idx<16;idx=idx+1)begin
   color=idx;repeat(2)@(negedge b);
   if({dut.red,dut.green,dut.blue}!==expected[pal*16+idx])$fatal(1,"palette %0d color %0d",pal,idx);
  end
 end
 for(m=0;m<2;m=m+1)begin
  wr(32'ha000001c,m);
  if(br!==m || dut.c64.sid.mode!=={2{m[0]}})$fatal(1,"SID register/CDC/model port %0d",m);
 end
 for(m=0;m<2;m=m+1)begin
  wr(32'ha0000020,m);
  if(br!==m || dut.pcm_sync!==m[0])$fatal(1,"PCM menu register/CDC");
 end
 wr(32'ha0000010,2);
 if(br!==0 || dut.drive9_mode!==0)$fatal(1,"old persisted D81 mode not rejected");
 wr(32'ha0000010,1);
 if(br!==1)$fatal(1,"1541 drive9 mode lost");
 wr(32'ha0000010,0);
 wr(32'ha0000014,0);
 if(br!==0 || dut.loader.restart_pending)$fatal(1,"zero action triggered reset");
 wr(32'ha0000014,1);
 if(br!==0 || !dut.loader.restart_pending)$fatal(1,"menu Reset Core did not queue");
 $display("PASS menu bridge: all 128 MiSTer palette colors exact, defaults Colodore/8580, both SID models through CDC, Reset Core action, PCM enable/disable CDC, D81 rejection/1541 retention, readback");$finish;
end
initial begin #1000000;$fatal(1,"menu settings timeout");end
endmodule
'''
(T/'tb_menu_settings.sv').write_text(tb)
(O/'core_top_sim.sv').write_text((P/'core/core_top.sv').read_text())
sources=[T/'tb_menu_settings.sv',O/'core_top_sim.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources += [P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_pcm.sv','pocket_ram_arbiter.sv','pocket_sample_memory.sv','pocket_keyboard.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
sources += list(O.glob('sid_*.sv'))
from drive_sim import drive_sources
from cartridge_sim import cartridge_sources
sources+=drive_sources()+cartridge_sources()
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'menu_settings.vvp'),*map(str,sources)],capture_output=True,text=True)
assert r.returncode==0,r.stderr[-4000:]
r=subprocess.run([str(B/'vvp.exe'),str(T/'menu_settings.vvp')],cwd=T,capture_output=True,text=True,timeout=60)
log=r.stdout+r.stderr;(T/'menu_settings.log').write_text(log);print(log)
assert r.returncode==0 and 'PASS menu bridge' in log,log
