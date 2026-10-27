from pathlib import Path
import os,subprocess,struct,re
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'cartridge_sim';O.mkdir(exist_ok=True)
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
# Icarus requires explicit sensitivity for the legacy combinational block.
mapper=(P/'rtl/cartridge.v').read_text().replace('always begin','always @* begin')
(O/'cartridge.v').write_text(mapper)
flash=(P/'core/am29f040.sv').read_text().replace('always_comb','always @*').replace('always_ff','always')
# Older Icarus treats a pre-declaration port reference as a separate implicit net.
flash=flash.replace('logic mem_rom_sel;','').replace('logic  [7:0] dq0_out;','logic mem_rom_sel;\nlogic [7:0] dq0_out;')
(O/'flash.sv').write_text(flash)
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'test.vvp'),str(T/'tb_cartridge.sv'),str(P/'core/pocket_cartridge.sv'),str(P/'core/pocket_crt.sv'),str(O/'cartridge.v'),str(O/'flash.sv')],capture_output=True,text=True)
(T/'cartridge_compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr

def make(kind,chips,exrom=0,game=1):
 h=bytearray(b'C64 CARTRIDGE   '+struct.pack('>IHHBB',64,0x100,kind,exrom,game)+bytes(38))
 for seed,(bank,address,length) in enumerate(chips):
  payload=bytes((i*3+(i>>8)*7+seed*29)&255 for i in range(length))
  h+=b'CHIP'+struct.pack('>IHHHH',length+16,0,bank,address,length)+payload
 return h
cases=[(0,make(0,[(0,0x8000,8192)])),(1,make(0,[(0,0x8000,16384)],0,0)),(2,make(0,[(0,0xe000,8192)],1,0)),(3,make(19,[(i,0x8000,8192)for i in range(3)])),(4,make(5,[(i,0x8000,8192)for i in range(3)])),(5,make(1,[(i,0x8000,8192)for i in range(4)])),(6,make(3,[(i,0x8000,16384)for i in range(4)],0,0)),(7,make(18,[(0,0x8000,4096),(0,0xa000,8192),(1,0xa000,8192)],0,0)),(10,make(20,[(0,0x8000,8192)])),(11,make(19,[(i,0x8000,8192)for i in range(9)])),(12,make(32,[(0,0x8000,8192)])),(8,make(19,[(i,0x8000,8192)for i in range(16)]))]
logs=[]
for mode,raw in cases:
 if mode==8:
  r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-Ptb.ROM_BYTES=131072','-o',str(O/'test.vvp'),str(T/'tb_cartridge.sv'),str(P/'core/pocket_cartridge.sv'),str(P/'core/pocket_crt.sv'),str(O/'cartridge.v'),str(O/'flash.sv')],capture_output=True,text=True)
  assert r.returncode==0,r.stderr
 path=O/f'{mode}.hex';path.write_text('\n'.join(f'{v:02x}'for v in raw))
 r=subprocess.run([str(B/'vvp.exe'),str(O/'test.vvp'),f'+FILE={path}',f'+SIZE={len(raw)}',f'+MODE={mode}'],cwd=O,capture_output=True,text=True,timeout=60)
 logs.append(r.stdout+r.stderr);assert r.returncode==0 and 'PASS compact' in r.stdout,logs[-1]
(T/'cartridge.log').write_text(''.join(logs));print(''.join(logs))
