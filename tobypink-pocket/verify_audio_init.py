"""Execute the rebuilt game's audio initialisation on the actual MiSTer T65 CPU."""
from pathlib import Path
import re,subprocess,json
P=Path(__file__).resolve().parent;C=P.parent if(P.parent/'core').is_dir()else P.parent/'c64-pocket-port'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
labels={name:int(addr,16) for addr,name in re.findall(r'al ([0-9A-Fa-f]+) \.([^\s]+)',(P/'toby-saves-the-pink-v0.3.27.lbl').read_text())}
prg=(P/'toby-saves-the-pink-v0.3.27.prg').read_bytes();load=int.from_bytes(prg[:2],'little')
ram=bytearray(65536);ram[load:load+len(prg)-2]=prg[2:]
entry=labels['_ua_init'];ram[0x200:0x20b]=bytes([0x78,0xa2,0xff,0x9a,0x20,entry&255,entry>>8,0x4c,7,2,0xea]);ram[0xfffc:0xfffe]=b'\x00\x02'
out=P/'tests';out.mkdir(exist_ok=True);(out/'game.hex').write_text('\n'.join(f'{v:02x}'for v in ram))
tb=r'''
`timescale 1ns/1ps
module tb;
 reg clk=0;always #5 clk=~clk;reg reset=0;reg[3:0]ce=0;always @(posedge clk)ce<=ce+1'b1;
 wire[23:0]a;wire[7:0]q;wire rw,sync;reg[7:0]di;
 reg[7:0]memory[0:65535];integer mode,cycles=0,writes=0;
 t65_Brtl cpu(.mode(2'b00),.bcd_en(1'b1),.res_n(reset),.enable(ce==0),.clk(clk),.rdy(1'b1),
 .abort_n(1'b1),.irq_n(1'b1),.nmi_n(1'b1),.so_n(1'b1),.r_w_n(rw),.sync(sync),.a(a),.di(di),.\do (q));
 always @(posedge clk)begin
  di<=memory[a[15:0]];
  if(a[15:8]==8'hdf)case(a[7:0])
   8'h18:di<=mode<2 ? 8'h50:0;8'h19:di<=mode<2 ? 8'h4b:0;
   8'h1a:di<=mode<2 ? 1:0;8'h1b:di<=mode==0 ? 1:0;
   default:di<=0;
  endcase
 end
 always @(posedge clk)if(reset && ce==0)begin
  cycles=cycles+1;
  if(!rw)begin memory[a[15:0]]<=q;if(a[15:8]==8'hdf)begin
   writes=writes+1;if(a[7:0]!=8'h20 && a[7:0]!=8'h40)$fatal(1,"Pocket issued Ultimate host-file command");
  end end
  if(sync && a[15:0]==16'h0207)begin
   if(memory[READY]!== (mode==0 ? 8'd1:8'd0))$fatal(1,"wrong audio detection mode %0d",mode);
   if(writes!=(mode==0 ? 2:0))$fatal(1,"unexpected audio writes");
   $display("PASS compiled TobyPink audio init: mode %0d, ready %0d, no Ultimate filesystem access, %0d CPU cycles",mode,memory[READY],cycles);$finish;
  end
  if(cycles>5000)$fatal(1,"game init timeout");
 end
 initial begin if(!$value$plusargs("MODE=%d",mode))$fatal;$readmemh("game.hex",memory);repeat(5)@(negedge clk);reset=1;end
endmodule
'''.replace('READY',str(labels['_ua_ready']))
(out/'init.sv').write_text(tb)
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(out/'init.vvp'),str(out/'init.sv'),str(C/'tests/converted/c64.v')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
logs=[]
for mode in range(3):
 r=subprocess.run([str(B/'vvp.exe'),str(out/'init.vvp'),f'+MODE={mode}'],cwd=out,capture_output=True,text=True,timeout=30)
 logs.append(r.stdout+r.stderr);assert r.returncode==0,logs[-1]
(out/'audio-init.log').write_text(''.join(logs));print(''.join(logs))

