"""Original synthetic drive ROM exercises real T65, VIA6522 and direct GCR."""
from pathlib import Path
import os,re,subprocess,time
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'drive_converted';O.mkdir(exist_ok=True)
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
logic=(P/'rtl/iec_drive/c1541_logic.sv').read_text()
t65=(O/'t65.v').read_text()
top=re.findall(r'module\s+(\w+)\s*\((.*?)\);',t65,re.S)[-1]
ports={name.lower():name for name in re.findall(r'(?:input|output)\s+(?:\[[^\]]+\]\s*)?(\w+)',top[1])}
match=re.search(r'T65 cpu\s*\(.*?\n\);',logic,re.S)
instance=match[0].replace('T65 cpu',top[0]+' cpu')
instance=re.sub(r'\.(\w+)\(',lambda m:'.'+ports[m[1].lower()]+'(',instance)
logic=logic[:match.start()]+instance+logic[match.end():]
(O/'logic.sv').write_text(logic)
gcr=(P/'rtl/iec_drive/c1541_direct_gcr.sv').read_text()
m=re.search(r"wire \[18:0\] base_rot_targets\[8\] = '\{(.*?)\};",gcr,re.S)
values=[x.strip()for x in m[1].split(',')]
gcr=gcr[:m.start()]+'wire [18:0] base_rot_targets[0:7];\n'+'\n'.join(f'assign base_rot_targets[{i}]={v};'for i,v in enumerate(values))+gcr[m.end():]
gcr=gcr.replace("reg  [13:0] rec[0:2191] = '{default:0};","reg [13:0] rec[0:2191];")
declarations=[]
for name in ['sd_buff_do','buff_do','buff_we','ht']:
 m=re.search(r'^(?:wire|reg)\s+(?:\[[^\]]+\]\s*)?'+name+r';[^\n]*',gcr,re.M)
 declarations.append(m[0]);gcr=gcr[:m.start()]+gcr[m.end():]
gcr=gcr.replace(');',');\n'+'\n'.join(declarations),1)
(O/'gcr.sv').write_text(gcr)
misc=(P/'rtl/iec_drive/iecdrv_misc.sv').read_text().replace('parameter DATAWIDTH, ADDRWIDTH,','parameter DATAWIDTH=8, ADDRWIDTH=11,').replace('parameter ADDRWIDTH)','parameter ADDRWIDTH=10)')
(O/'misc.sv').write_text(misc)
# No Commodore code: a tiny diagnostic program configures and polls the two VIAs.
code=bytearray();labels={};fixups=[]
def emit(*values):code.extend(values)
def label(name):labels[name]=len(code)
def poke(addr,value):emit(0xa9,value,0x8d,addr&255,addr>>8)
def load(addr):emit(0xad,addr&255,addr>>8)
def store(addr):emit(0x8d,addr&255,addr>>8)
def branch(op,name):emit(op,0);fixups.append((len(code)-1,name,'rel'))
def jump(name):emit(0x4c,0,0);fixups.append((len(code)-2,name,'abs'))
emit(0x78,0xd8,0xa2,0xff,0x9a)
poke(0x1800,0);poke(0x1802,0x1a)
poke(0x1c00,0);poke(0x1c02,0x6f);poke(0x1c0c,0xee);poke(0x1c03,0)
poke(0x1c00,0x4c);poke(0x0201,0x42)
label('loop');load(0x1800);store(0x0200);emit(0x29,4);branch(0xd0,'write')
poke(0x1c0c,0xee);poke(0x1c03,0);load(0x1c01);store(0x0202);load(0x1c00);store(0x0203)
load(0x1800);emit(0x29,0x80);branch(0xf0,'normal');poke(0x1c00,0x4d);jump('loop')
label('normal');poke(0x1c00,0x4c);jump('loop')
label('write');poke(0x1c03,0xff);poke(0x1c01,0xa5);poke(0x1c0c,0xce);poke(0x0201,0x43);jump('loop')
for pos,name,kind in fixups:
 target=labels[name]
 if kind=='rel':
  offset=target-(pos+1);assert -128<=offset<=127;code[pos]=offset&255
 else:code[pos:pos+2]=(0xc000+target).to_bytes(2,'little')
rom=bytearray([0xea]*16384);rom[:len(code)]=code
for offset in [0x3ffa,0x3ffc,0x3ffe]:rom[offset:offset+2]=b'\x00\xc0'
(O/'diagnostic_rom.hex').write_text('\n'.join(f'{v:02x}'for v in rom))
sources=[T/'tb_1541.sv',P/'core/pocket_1541.sv',O/'logic.sv',O/'gcr.sv',O/'t65.v',O/'via.v',O/'misc.sv',P/'rtl/iec_drive/lfsr.v']
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'drive.vvp'),*[str(s)for s in sources]],capture_output=True,text=True)
log+=r.stdout+r.stderr;(T/'drive_compile.log').write_text(log);assert r.returncode==0,log[-6000:]
start=time.monotonic()
r=subprocess.run([str(B/'vvp.exe'),str(O/'drive.vvp')],cwd=O,capture_output=True,text=True)
log=r.stdout+r.stderr;(T/'drive.log').write_text(log);print(log);print('Seconds',round(time.monotonic()-start,2))
assert r.returncode==0 and 'PASS 1541' in log,log
