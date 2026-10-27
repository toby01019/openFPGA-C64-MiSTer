"""Original synthetic drive ROM exercises real T65, VIA6522 and direct GCR."""
from pathlib import Path
import os,re,subprocess,time
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'drive1581_converted';O.mkdir(exist_ok=True)
G=Path(os.environ.get('GHDL',str(P.parent/'ghdl/runtime/bin/ghdl.exe')))
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
log=''
def ghdl(args,name=None):
 global log
 r=subprocess.run([str(G),*args],cwd=O,capture_output=True,text=True)
 log+=r.stderr;assert r.returncode==0,r.stderr
 if name:(O/name).write_text(re.sub(r'\bbreak\b','break_flag',r.stdout))
ghdl(['-a','--std=08','-fsynopsys',*[str(P/'rtl'/f)for f in ['t65/T65_Pack.vhd','t65/T65_MCode.vhd','t65/T65_ALU.vhd','t65/T65.vhd','iec_drive/iecdrv_via6522.vhd']]])
ghdl(['--synth','--std=08','-fsynopsys','--out=verilog','T65'],'t65.v')
ghdl(['--synth','--std=08','-fsynopsys','--out=verilog','iecdrv_via6522'],'via.v')
# GHDL preserves declared VHDL top-level spelling; Quartus resolves it case-insensitively.
logic=(P/'rtl/iec_drive/c1581_drv.sv').read_text()
t65=(O/'t65.v').read_text()
top=re.findall(r'module\s+(\w+)\s*\((.*?)\);',t65,re.S)[-1]
ports={name.lower():name for name in re.findall(r'(?:input|output)\s+(?:\[[^\]]+\]\s*)?(\w+)',top[1])}
match=re.search(r'T65 cpu\s*\(.*?\n\);',logic,re.S)
instance=match[0].replace('T65 cpu',top[0]+' cpu')
instance=re.sub(r'\.(\w+)\(',lambda m:'.'+ports[m[1].lower()]+'(',instance)
logic=logic[:match.start()]+instance+logic[match.end():]
def forward(text,names):
 decl=[]
 for name in names:
  m=re.search(r'^(?:wire|reg)\s+(?:\[[^\]]+\]\s*)?'+name+r';[^\n]*',text,re.M)
  decl.append(m[0]);text=text[:m.start()]+text[m.end():]
 return text.replace(');',');\n'+'\n'.join(decl),1)
logic=forward(logic,['cia_irq_n','via_irq'])
(O/'logic.sv').write_text(logic)
fdc=forward((P/'rtl/iec_drive/fdc1772.v').read_text(),['data_in_strobe','data_in'])
(O/'fdc1772.v').write_text(fdc)
misc=(P/'rtl/iec_drive/iecdrv_misc.sv').read_text().replace('parameter DATAWIDTH, ADDRWIDTH,','parameter DATAWIDTH=8, ADDRWIDTH=11,').replace('parameter ADDRWIDTH)','parameter ADDRWIDTH=10)')
(O/'misc.sv').write_text(misc)
code=bytearray([0x78,0xd8,0xa2,0xff,0x9a])
def poke(a,v):code.extend([0xa9,v,0x8d,a&255,a>>8])
def readstore(a,b):code.extend([0xad,a&255,a>>8,0x8d,b&255,b>>8])
poke(0x2003,255);poke(0x2001,0xa5);readstore(0x2001,0x205)
poke(0x4000,0x60);poke(0x4002,0x65);poke(0x4001,0x10);poke(0x4003,0x3a)
poke(0x6001,0);poke(0x6002,1);poke(0x6000,0x88);poke(0x201,0x42)
poke(0x206,0)
loop=0x8000+len(code)
readstore(0x4001,0x200);readstore(0x6000,0x202)
# ATN low starts one protected-write command, then continues polling status.
code.extend([0xad,0,2,0x10,0]);skip1=len(code)-1
code.extend([0xad,6,2,0xd0,0]);skip2=len(code)-1
poke(0x206,1);poke(0x6000,0xd8);poke(0x6000,0xa8)
target=len(code);code[skip1]=target-skip1-1;code[skip2]=target-skip2-1
code.extend([0x4c,loop&255,loop>>8])
rom=bytearray([0xea]*32768);rom[:len(code)]=code
for offset in [0x7ffa,0x7ffc,0x7ffe]:rom[offset:offset+2]=bytes([0,0x80])
(O/'diagnostic_rom.hex').write_text('\n'.join(f'{v:02x}'for v in rom))
sources=[T/'tb_1581.sv',P/'core/pocket_1581.sv',O/'logic.sv',O/'t65.v',O/'via.v',O/'misc.sv',O/'fdc1772.v',*[P/'rtl/iec_drive'/f for f in ['floppy.v','iecdrv_mos8520.v']]]
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'drive.vvp'),*[str(s)for s in sources]],capture_output=True,text=True)
log+=r.stdout+r.stderr;(T/'drive1581_compile.log').write_text(log);assert r.returncode==0,log[-6000:]
start=time.monotonic()
r=subprocess.run([str(B/'vvp.exe'),str(O/'drive.vvp')],cwd=O,capture_output=True,text=True,timeout=120)
log=r.stdout+r.stderr;(T/'drive1581.log').write_text(log);print(log);print('Seconds',round(time.monotonic()-start,2))
assert r.returncode==0 and 'PASS 1581' in log,log
