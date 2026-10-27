from pathlib import Path
import subprocess,sys,time,json,re
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'converted'
TOOLS=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
(O/'core_top_sim.sv').write_text((P/'core/core_top.sv').read_text())
# Entirely original diagnostic ROM and PRG: no Commodore ROMs required for this test.
kernal=bytearray([0xea]*8192)
boot=bytes.fromhex('78 d8 a2 ff 9a a9 2f 85 00 a9 37 85 01 4c 01 08')
kernal[:len(boot)]=boot
for a in [0x1ffa,0x1ffc,0x1ffe]:kernal[a:a+2]=b'\x00\xe0'
code=bytearray([0x78])
def poke(a,v):code.extend([0xa9,v,0x8d,a&255,a>>8])
for a,v in [(0xdd02,255),(0xdd00,3),(0xd011,0x1b),(0xd016,8),(0xd018,0x14),
 (0xd020,2),(0xd021,6),(0xdc02,255),(0xdc03,0),(0xdc00,255),
 (0xd400,0),(0xd401,0x20),(0xd405,0),(0xd406,0xf0),(0xd418,15),(0xd404,0x21)]:poke(a,v)
# A real KERNAL initializes screen and Color RAM. This synthetic ROM does
# very little, so initialize both with actual 6510 stores before evaluating video.
# LDX #0; LDA #1; fill all eight pages; INX/BNE loop.
code.extend(bytes.fromhex('a2 00 a9 01 9d 00 d8 9d 00 d9 9d 00 da 9d 00 db 9d 00 04 9d 00 05 9d 00 06 9d 00 07 e8 d0 e5'))
if '--reu' in sys.argv:
 for n in range(16):poke(0xc200+n,(n*17+5)&255)
 def reu_transfer(command):
  for a,v in [(0xdf02,0),(0xdf03,0xc2),(0xdf04,0x56),(0xdf05,0x34),(0xdf06,1),
              (0xdf07,16),(0xdf08,0),(0xdf0a,0),(0xdf01,command)]:poke(a,v)
  # Poll command bit 7 using the actual 6510 and IOF register read path.
  code.extend(bytes.fromhex('ad 01 df 30 fb'))
 reu_transfer(0x90)
 for n in range(16):poke(0xc200+n,0)
 reu_transfer(0x91)
 poke(0xc110,0xa5)
if '--drive' in sys.argv:
 poke(0xdd02,0x3f);poke(0xdd00,0x0b)
 code.extend(bytes.fromhex('ad 00 dd 30 fb')) # DATA low: drive acknowledged ATN.
 poke(0xc111,0xa5)
 # ATN acknowledgement is combinational in the VIA. Hold ATN long enough
 # for the diagnostic drive CPU's polling loop to perform its head step.
 code.extend(bytes.fromhex('a2 30 ca d0 fd'))
 poke(0xdd00,3)
 code.extend(bytes.fromhex('ad 00 dd 10 fb')) # DATA released after ATN.
 poke(0xc112,0x5a)
loop=0x801+len(code)
code.extend(bytes.fromhex('ad 00 dc 8d 00 c1'))
poke(0xdc00,0xfe)
code.extend(bytes.fromhex('ad 01 dc 8d 01 c1'))
poke(0xdc00,0xfd) # Matrix row 1: A at bit 2, left Shift at bit 7.
code.extend(bytes.fromhex('ad 01 dc 8d 02 c1'))
poke(0xdc00,0xff)
code.extend([0x4c,loop&255,loop>>8])
prg=bytearray(b'\x01\x08')+code+bytearray((i*37+11)&255 for i in range(1401-len(code)))
assert len(prg)==1403
for name,data in [('kernal.hex',kernal),('basic.hex',bytes(8192)),('char.hex',bytes((i*3)&255 for i in range(4096))),('diagnostic.hex',prg)]:
 (T/name).write_text('\n'.join(f'{b:02x}'for b in data))
tb=r'''
`timescale 1ns/1ps
module tb;
reg c74=0,c32=0;
always #6.734 c74=~c74;
always #15.873 c32=~c32;
reg [31:0] ba=0,bwdata=0;
reg bw=0;
wire [31:0] brdata;
reg [31:0] buttons=0;
wire de,hs,vs,skip;
wire [23:0] rgb;
wire mclk,lrck,dac;
core_top dut(.clk_74a(c74),.clk_74b(c74),.clk_32mhz(c32),
 .bridge_addr(ba),.bridge_wr(bw),.bridge_wr_data(bwdata),.bridge_rd(1'b0),.bridge_rd_data(brdata),
 .cont1_key(buttons),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0),
 .cont1_joy(32'b0),.cont2_joy(32'b0),.cont3_joy(32'b0),.cont4_joy(32'b0),
 .cont1_trig(16'b0),.cont2_trig(16'b0),.cont3_trig(16'b0),.cont4_trig(16'b0),
 .video_de(de),.video_hs(hs),.video_vs(vs),.video_skip(skip),.video_rgb(rgb),
 .audio_mclk(mclk),.audio_lrck(lrck),.audio_dac(dac));
defparam dut.loader.BOOT_CYCLES=10000;
defparam dut.loader.KEY_CYCLES=6000;
reg [7:0] kernal[0:8191],basic[0:8191],chars[0:4095],prg[0:1402];
integer file_requests=0,prg_requests=0,words=0;
integer slot,off,len,i,j,q;
reg sent_event=0;
reg [31:0] worddata;
function [7:0] asset_byte(input integer s,input integer a);
begin
 case(s)
 200:asset_byte=basic[a];201:asset_byte=chars[a];202:asset_byte=kernal[a];
 1:asset_byte=a<1403 ? prg[a]:0;
 default:asset_byte=0;
 endcase
end
endfunction
task wr(input [31:0] a,input [31:0] d);
begin
 @(negedge c74);ba=a;bwdata=d;bw=1;
 @(negedge c74);bw=0;
end
endtask
initial begin
 $readmemh("kernal.hex",kernal);$readmemh("basic.hex",basic);
 $readmemh("char.hex",chars);$readmemh("diagnostic.hex",prg);
 // APF table uses the native command-register byte order.
 wr(32'hf8002000,200);wr(32'hf8002004,8192);
 wr(32'hf8002008,201);wr(32'hf800200c,4096);
 wr(32'hf8002010,202);wr(32'hf8002014,8192);
 wr(32'hf8002018,1);wr(32'hf800201c,1403);
 wr(32'hf8000000,32'h434d008f); // Framework completed deferred-slot metadata.
 wait(dut.icb.target_0===32'h636d0140);
 wr(32'hf8001000,32'h6f6b0000);
 repeat(12) @(posedge c74);
 wr(32'hf8000000,32'h434d0011);
 forever begin
  @(posedge c74);
  if(dut.icb.target_0===32'h636d0180) begin
    slot=dut.icb.target_20;off=dut.icb.target_24;len=dut.icb.target_2C;
    if(len<1 || len>1024 || dut.icb.target_28!==32'h70000000) $fatal(1,"bad APF request");
    file_requests=file_requests+1;if(slot==1) prg_requests=prg_requests+1;
    for(i=0;i<len;i=i+4) begin
      worddata={asset_byte(slot,off+i),asset_byte(slot,off+i+1),asset_byte(slot,off+i+2),asset_byte(slot,off+i+3)};
      wr(32'h70000000+i,worddata);words=words+1;
    end
    wr(32'hf8001000,32'h6f6b0000);
  end else if(!sent_event && dut.load_state==12) begin
    sent_event=1;
    wr(32'hf8000020,1);
    wr(32'hf8000000,32'h434d008a);
  end
 end
end
integer ram_writes=0,rom_writes=0,char_writes=0;
always @(posedge c32) if(dut.command_fire) begin
 case(dut.command_data[25:24])
 0:ram_writes=ram_writes+1;1:rom_writes=rom_writes+1;2:char_writes=char_writes+1;
 endcase
end
integer lines=0,frames=0,pixels=0,nonblack=0,audio_edges=0;
reg check_frame=0;
integer frame_pixels=0,frame_nonblack=0,frame_red=0,frame_blue=0,frame_lines_start=0;
always @(negedge dut.clk_video) if(check_frame && de && !skip)begin
 if((^{rgb,dut.c64.viccolorindex,dut.c64.vic.mainborder,dut.c64.vic.tbborder})===1'bx)
  $fatal(1,"unstable complete-frame pixel RGB=%h borders=%b/%b raster=%h/%h",rgb,dut.c64.vic.mainborder,dut.c64.vic.tbborder,dut.c64.vic.rasterx,dut.c64.vic.rastery);
 frame_pixels=frame_pixels+1;
 if(rgb!=0)frame_nonblack=frame_nonblack+1;
 if(rgb==24'h813338)frame_red=frame_red+1;
 if(rgb==24'h2e2c9b)frame_blue=frame_blue+1;
end
always @(posedge hs) lines=lines+1;
always @(posedge vs) frames=frames+1;
always @(negedge dut.clk_video) if(de) begin pixels=pixels+1;if(rgb!==24'b0 && (^rgb)!==1'bx) nonblack=nonblack+1;end
always @(posedge dac) audio_edges=audio_edges+1;
initial begin
 wait(sent_event);
 wait(prg_requests==2);
 wait(dut.load_state==12);
 // Check exact PRG bytes beyond the running code, plus BASIC end pointers.
 for(j=200;j<1401;j=j+1)
   if(dut.main_ram[16'h0801+j]!==prg[j+2]) $fatal(1,"PRG mismatch at byte %0d",j);
 if({dut.main_ram[16'h002e],dut.main_ram[16'h002d]}!==16'h0d7a) $fatal(1,"end pointer mismatch");
 if(rom_writes!=16384 || char_writes!=4096) $fatal(1,"ROM upload count");
 // Readiness crosses into the C64 domain through two flops. Allow the
 // keyboard's post-load release guard to observe the neutral controller.
 repeat(16) @(negedge c32);
 if(dut.keyboard_capture) $fatal(1,"input guard did not release after loading");
 buttons=32'h00008011; // Start/Return + up + fire on joystick port 2.
 // Initialization now includes Color RAM. Wait for the real CPU loop instead
 // of a short arbitrary delay that stopped before even one complete PAL frame.
 wait(dut.main_ram[16'hc100][4:0]===5'b01110 && dut.main_ram[16'hc101][1]===1'b0);
 repeat(16) @(negedge c32);
 $display("VIDEO de=%b hb=%b vb=%b RGB=%h index=%h EC=%h main=%b topbottom=%b hblack=%b pixels=%d",de,dut.hb,dut.vb,{dut.red,dut.green,dut.blue},dut.c64.viccolorindex,dut.c64.vic.ec,dut.c64.vic.mainborder,dut.c64.vic.tbborder,dut.c64.vic.hblack,pixels);
 $display("DIAG pcaddr=%h ramc100=%h ramc101=%h audio=%h lines=%0d frames=%0d nonblack=%0d cycle=%h VIC=%h/%h",dut.c64_addr,dut.main_ram[16'hc100],dut.main_ram[16'hc101],dut.audio_left,lines,frames,nonblack,dut.c64.syscycle,dut.c64.vic.rasterx,dut.c64.vic.rastery);
 if(dut.main_ram[16'hc100][4:0]!==5'b01110) $fatal(1,"joystick matrix/CPU program not working");
 if(dut.main_ram[16'hc101][1]!==1'b0) $fatal(1,"Return key did not reach CIA");
 if(lines<20 || nonblack<1000) $fatal(1,"VIC/video missing");
 // Observe one complete upstream PAL period after CPU initialization.
 // Native transport preserves 382 source pixels plus two right-border pads.
 // This also avoids depending on the startup phase of the output blanker.
 @(posedge dut.raw_vs);@(negedge c32);frame_lines_start=lines;check_frame=1;
 @(posedge dut.raw_vs);@(negedge c32);check_frame=0;
 if(frame_pixels!=384*270 || lines-frame_lines_start<300 || frame_nonblack<10000)
  $fatal(1,"incomplete video frame pixels=%d lines=%d nonblack=%d",frame_pixels,lines-frame_lines_start,frame_nonblack);
 $display("PASS stable complete PAL frame: pixels=%d lines=%d known RGB/borders, nonblack=%d",frame_pixels,lines-frame_lines_start,frame_nonblack);
 if(audio_edges<20) $fatal(1,"SID/I2S audio missing");
 if(dut.error_code!=0) $fatal(1,"loader reported error");
 buttons=0;repeat(16) @(negedge c32);
 buttons=16'h80;repeat(16) @(negedge c32);buttons=0;
 repeat(16) @(negedge c32);
 if(!dut.keyboard_visible) $fatal(1,"keyboard did not open");
 buttons=16'h2;repeat(16) @(negedge c32);buttons=0;
 repeat(16) @(negedge c32);
 buttons=16'h8;repeat(16) @(negedge c32);buttons=0;
 repeat(16) @(negedge c32);
 if(dut.keyboard_row!=2 || dut.keyboard_col!=2) $fatal(1,"keyboard A navigation");
 buttons=16'h110; // Selected A + temporary L/Shift.
 repeat(16000) @(negedge c32);
 if(dut.main_ram[16'hc102][2]!==0 || dut.main_ram[16'hc102][7]!==0)
   $fatal(1,"virtual Shift+A did not reach the real CPU/CIA program: %h",dut.main_ram[16'hc102]);
 if(dut.main_ram[16'hc100][4:0]!==5'b11111) $fatal(1,"keyboard buttons leaked to joystick");
 buttons=0;repeat(16) @(negedge c32);
 buttons=16'h40;repeat(16) @(negedge c32);buttons=0;
 repeat(16000) @(negedge c32);
 if(dut.main_ram[16'hc102][2]!==0 || dut.main_ram[16'hc102][7]!==1)
   $fatal(1,"sticky A/Shift release failed");
 buttons=16'h20;repeat(16) @(negedge c32);buttons=0;
 repeat(16000) @(negedge c32);
 if(dut.keyboard_visible || dut.virtual_keys!=0 || dut.main_ram[16'hc102]!==8'hff)
   $fatal(1,"keyboard close left stuck contacts");
 $display("PASS integrated virtual keyboard: Y open, D-pad A selection, held Shift+A in real CIA/CPU, no joystick leakage, sticky A, modifier release, B close with no stuck keys");
 $display("PASS integrated APF byte order, ROM upload, 2-chunk PRG, pointers, 6510 execution, joystick, keyboard, VIC video, SID/I2S. lines=%0d frames=%0d pixels=%0d audioedges=%0d",lines,frames,pixels,audio_edges);
 $finish;
end
initial begin #100000000; $fatal(1,"timeout state=%0d error=%0d addr=%h",dut.load_state,dut.error_code,dut.c64_addr);end
integer ticks=0;
always @(posedge c74) begin
 ticks=ticks+1;
 if(ticks%100000==0) begin
  $display("PROGRESS t=%0t state=%0d RAM=%0d ROM=%0d reads=%0d cpuaddr=%h pause=%b frames=%0d check=%b framepixels=%0d rawvs=%b outvs=%b rasterY=%h",$time,dut.load_state,ram_writes,rom_writes,file_requests,dut.c64_addr,dut.c64_paused,frames,check_frame,frame_pixels,dut.raw_vs,dut.blanker_vs,dut.c64.vic.rastery);
  $fflush();
 end
end
endmodule
'''
if '--drive' in sys.argv:
 raw=bytearray([0x55]*7000);raw[:16]=b'\xff'*16
 image=bytearray(b'GCR-1541\0\x54')+(7000).to_bytes(2,'little')+bytearray(84*8)
 image[12+34*4:16+34*4]=(684).to_bytes(4,'little')
 image+=(7000).to_bytes(2,'little')+raw
 (T/'integration_g64.hex').write_text('\n'.join(f'{b:02x}'for b in image))
 tb=tb.replace('reg [7:0] kernal[', 'reg [7:0] drive_rom[0:16383],disk_image[0:7685];\nreg [7:0] kernal[')
 tb=tb.replace(' 200:asset_byte=', ' 203:asset_byte=drive_rom[a];6:asset_byte=a<7686 ? disk_image[a]:0;\n 200:asset_byte=')
 tb=tb.replace(' $readmemh("kernal.hex"', ' $readmemh("drive_converted/diagnostic_rom.hex",drive_rom);\n $readmemh("integration_g64.hex",disk_image);\n $readmemh("kernal.hex"')
 tb=tb.replace(" wr(32'hf8002018,1)", " wr(32'hf8002020,203);wr(32'hf8002024,16384);\n wr(32'hf8002028,2);wr(32'hf800202c,7686);\n wr(32'hf8002030,6);wr(32'hf8002034,7686);\n wr(32'hf8002018,1)")
 tb=tb.replace('  end else if(!sent_event', '''  end else if(dut.icb.target_0===32'h636d0190)begin
    for(i=0;i<256;i=i+4)wr(32'h70000000+i,i==0 ? 32'h6469736b:0);
    wr(32'hf8001000,32'h6f6b0000);
  end else if(dut.icb.target_0===32'h636d0192)begin
    if(dut.icb.target_20!=6)$fatal(1,"alias slot");
    wr(32'hf8001000,32'h6f6b0000);
  end else if(!sent_event''')
 tb=tb.replace(' if(dut.error_code!=0)', ''' if(!dut.disk_mounted || !dut.disk_rom_loaded || dut.disk_error!=0)$fatal(1,"drive mount error %0d",dut.disk_error);
 if(dut.main_ram[16'hc111]!==8'ha5 || dut.main_ram[16'hc112]!==8'h5a)$fatal(1,"C64 CIA2/drive IEC handshake did not finish");
 if(!dut.drive_motor || !dut.drive_led || dut.drive_track!=34)$fatal(1,"real drive ROM execution/head");
 if(track_commits<3 || !half_track_seen)$fatal(1,"missing physical head refill commits=%0d seen=%b",track_commits,half_track_seen);
 $display("PASS integrated drive: APF ROM203/G64 slot6 alias, real C64 CIA2-to-1541 IEC ATN/ACK/release, drive CPU/VIA motor/LED, half-track miss/pause/refill/resume");
 if(dut.error_code!=0)''')
 tb=tb.replace('integer lines=0', '''integer track_commits=0;reg prior_commit=0,half_track_seen=0;
always @(posedge c74)begin
 if(dut.disk_commit!=prior_commit)begin track_commits=track_commits+1;prior_commit=dut.disk_commit;end
 if(dut.head_sync==35)half_track_seen=1;
end
integer lines=0''')
if '--reu' in sys.argv:
 tb=tb.replace('core_top dut(','''wire [21:16] pa;tri [15:0] pd;wire padv,pcre,pclk,pce0,pce1,poe,pwe,pub,plb;
psram_model memory(.a(pa),.dq(pd),.adv(padv),.cre(pcre),.ramclk(pclk),.ce0(pce0),.ce1(pce1),.oe(poe),.we(pwe),.ub(pub),.lb(plb));
core_top dut(''')
 tb=tb.replace('.bridge_addr(ba)', '''.cram0_a(pa),.cram0_dq(pd),.cram0_wait(1'b1),.cram0_adv_n(padv),.cram0_cre(pcre),.cram0_clk(pclk),
 .cram0_ce0_n(pce0),.cram0_ce1_n(pce1),.cram0_oe_n(poe),.cram0_we_n(pwe),.cram0_ub_n(pub),.cram0_lb_n(plb),
 .bridge_addr(ba)''')
 tb=tb.replace(' // APF table uses', " wr(32'ha000000c,1);\n // APF table uses")
 tb=tb.replace(' if(dut.error_code!=0)', ''' if(dut.main_ram[16'hc110]!==8'ha5)$fatal(1,"CPU REU transfer did not finish");
 for(j=0;j<16;j=j+1)if(dut.main_ram[16'hc200+j]!==((j*17+5)&255))$fatal(1,"REU roundtrip byte %0d",j);
 if(memory.writes!=16 || memory.reads!=16)$fatal(1,"REU PSRAM access count %0d/%0d",memory.writes,memory.reads);
 $display("PASS integrated REU: actual 6510 writes IOF registers, DMA copies 16 bytes C64-to-PSRAM-to-C64 through delayed physical pin model");
 if(dut.error_code!=0)''')
if '--full-clear' not in sys.argv:
 # CPU initializes screen/color RAM; only the pre-load BRK byte is seeded.
 tb=tb.replace(' // APF table uses', " dut.main_ram[16'h0801]=0;\n // APF table uses")
 tb=tb.replace("wr(32'hf8000000,32'h434d0011);", "wr(32'hf8000000,32'h434d0011);\n wait(dut.reset_n===1);@(negedge c74);dut.loader.state=2;")
if '--early-trace' in sys.argv:tb=tb.replace('ticks%100000==0','ticks%100000==0 || ticks<1000')
if '--dock' in sys.argv:
 tb=tb.replace("reg [31:0] buttons=0;", "reg [31:0] buttons=0,dock_key=0,dock_joy=0;reg[15:0]dock_trig=0;reg dock_update=0;")
 tb=tb.replace(".cont1_key(buttons)",".cont_update(dock_update),.cont1_key(buttons)").replace(".cont3_key(32'b0)",".cont3_key(dock_key)").replace(".cont3_joy(32'b0)",".cont3_joy(dock_joy)").replace(".cont3_trig(16'b0)",".cont3_trig(dock_trig)")
 tb=tb.replace('task wr(',r'''task dock_report(input [31:0] key_word,input [47:0] usages);begin
 @(negedge c74);dock_key=key_word;dock_joy=usages[47:16];dock_trig=usages[15:0];dock_update=1;
 @(negedge c74);dock_update=0;repeat(16000)@(negedge c32);
 end endtask
 task wr(''')
 dock_check=r''' dock_report(32'h40000000,0);
 dock_report(32'h40000200,48'h040000000000);
 if(dut.main_ram[16'hc102][2]!==0 || dut.main_ram[16'hc102][7]!==0)
  $fatal(1,"Dock Shift+A did not reach real C64 CPU/CIA: %h",dut.main_ram[16'hc102]);
 buttons=16'h80;repeat(16)@(negedge c32);buttons=0;repeat(16000)@(negedge c32);
 if(!dut.keyboard_visible || dut.combined_keys[10]!==1 || dut.combined_keys[15]!==1)
  $fatal(1,"Dock keys lost while virtual keyboard open");
 dock_report(32'h40000000,0);
 if(dut.main_ram[16'hc102]!==8'hff)$fatal(1,"Dock release left stuck keys");
 buttons=16'h20;repeat(16)@(negedge c32);buttons=0;
 dock_report(32'h30000200,48'h040000000000);
 if(dut.main_ram[16'hc102]!==8'hff)$fatal(1,"Player3 gamepad parsed as keyboard");
 wr(32'ha0000024,2);repeat(10)@(negedge c32);
 if(dut.dock_mode_sync!==2 || brdata!==32'd2)$fatal(1,"Dock menu CDC");
 dock_report(32'h40000000,0);dock_report(32'h40000000,48'h1c0000000000);
 if(dut.dock_keys!==(64'h1<<12))$fatal(1,"Dock QWERTZ menu mapping");
 wr(32'ha0000024,0);repeat(16)@(negedge c32);
 if(dut.combined_keys!==0)$fatal(1,"Dock Off left keys held");
 $display("PASS integrated Dock USB keyboard: actual APF report -> CDC -> C64 CIA/6510 Shift+A, release, coexistence with virtual keyboard, device-type rejection and QWERTZ/Off menu");
'''
 tb=tb.replace(' $display("PASS integrated APF byte order',dock_check+' $display("PASS integrated APF byte order')
(T/'tb_integration.sv').write_text(tb)
sources=[T/'tb_integration.sv',O/'core_top_sim.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources += [P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_pcm.sv','pocket_ram_arbiter.sv','pocket_sample_memory.sv','pocket_keyboard.sv','pocket_autostart.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv']]
for source in (P/'rtl/sid').glob('*.sv'):
 text=source.read_text()
 text=re.sub(r'\b(\w+)\+\+',r'\1=\1+1',text)
 text=text.replace('always_comb','always @*')
 text=text.replace("signed'(",'$signed(')
 if source.name=='sid_top.sv':
  text=re.sub(r'wire(\s+\[7:0\]\s+(?:_st_out|p_t_out|ps__out|pst_out)\[)',r'reg\1',text)
  declarations=re.search(r'wire  \[7:0\] f__st_out;.*?reg   \[3:0\] state;',text,re.S).group(0)
  text=text.replace(declarations,'').replace('wire [15:0] F0;',declarations+'\nwire [15:0] F0;')
 text=text.replace('(wire signed','(input signed')
 text=re.sub(r'(function[^\n]*\([^\n]*\);)',lambda m:re.sub(r'\bwire\b','input',m[0]),text)
 def array_init(m):
  kind,sign,packed,name,dimension,values=m.groups()
  values=re.sub(r'//[^\n]*|/\*.*?\*/','',values,flags=re.S)
  items=[v.strip() for v in values.split(',') if v.strip()]
  assert re.fullmatch(r'[0-9* +:]+',dimension),dimension
  dims=[eval(d,{'__builtins__':{}})for d in dimension.split(':')]
  indices=list(range(dims[0],dims[1]+(1 if dims[1]>=dims[0] else -1),1 if dims[1]>=dims[0] else -1)) if len(dims)==2 else list(range(dims[0]))
  assert len(items)==len(indices),(name,len(items),dimension)
  declaration=f'{kind} {sign or ""} {packed} {name}[{dimension}];\n'
  assignments='\n'.join(f'{name}[{i}] = {v};'for i,v in zip(indices,items))
  return declaration+('initial begin\n'+assignments+'\nend' if kind=='reg' else
    '\n'.join('assign '+line for line in assignments.splitlines()))
 text=re.sub(r'\b(wire|reg)\s+(signed\s+)?(\[[^\]]+\])\s+(\w+)\[([^\]]+)\]\s*=\s*\'\{(.*?)\};',array_init,text,flags=re.S)
 target=O/source.name;target.write_text(text);sources.append(target)
from drive_sim import drive_sources
sources += drive_sources()
from cartridge_sim import cartridge_sources
sources += cartridge_sources()
sources += [P/'core'/n for n in ['pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
if '--reu' in sys.argv:sources.append(T/'psram_model.sv')
cmd=[str(TOOLS/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'integration.vvp'),*[str(s)for s in sources]]
r=subprocess.run(cmd,capture_output=True,text=True);(T/'compile.log').write_text(r.stdout+r.stderr)
assert r.returncode==0,r.stderr[-6000:]
print('Integration simulation compiled',flush=True)
start=time.monotonic()
logfile=T/('integration-dock.log' if '--dock' in sys.argv else 'integration-drive-frame.log' if '--drive' in sys.argv else ('integration-reu.log' if '--reu' in sys.argv else 'integration.log'))
with logfile.open('w') as out:
 r=subprocess.run([str(TOOLS/'vvp.exe'),'-i',str(T/'integration.vvp')],cwd=T,stdout=out,stderr=subprocess.STDOUT)
log=logfile.read_text()
print(log[-5000:]);print('Elapsed',round(time.monotonic()-start,2),'seconds')
assert r.returncode==0 and 'PASS integrated' in log,log[-5000:]

if '--drive' in sys.argv:(T/'integration-drive.log').write_text(log)


