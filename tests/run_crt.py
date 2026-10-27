from pathlib import Path
import os,subprocess,struct,sys
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'crt_sim';O.mkdir(exist_ok=True)
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'test.vvp'),str(T/'tb_crt.sv'),str(P/'core/pocket_crt.sv')],capture_output=True,text=True)
(T/'crt_compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr

def make(kind,chips,exrom=0,game=1):
 h=bytearray(b'C64 CARTRIDGE   '+struct.pack('>IHHBB',64,0x100,kind,exrom,game)+bytes(38))
 expected=bytearray();metadata=[]
 for bank,address,length,typ in chips:
  payload=bytes((i*37+bank*11+length//4096)&255 for i in range(length))
  h+=b'CHIP'+struct.pack('>IHHHH',length+16,typ,bank,address,length)+payload
  metadata.append(((address!=0x8000)<<17)|((length==16384)<<16)|(bank<<8)|(len(expected)//8192))
  expected+=payload* (2 if length==4096 else 1)
 return h,expected,metadata
cases=[]
for name,args in [('8k',(0,[(0,0x8000,8192,0)])),('16k',(0,[(0,0x8000,16384,0)],0,0)),('split',(0,[(0,0x8000,8192,0),(0,0xa000,8192,0)],0,0)),('ultimax',(0,[(0,0xe000,8192,0)],1,0)),('zaxxon',(18,[(0,0x8000,4096,0),(0,0xa000,8192,0),(1,0xa000,8192,0)],0,0)),('easyflash',(32,[(2,0x8000,8192,2),(2,0xa000,8192,2)],1,0)),('magicdesk',(19,[(i,0x8000,8192,0)for i in range(3)]))]:
 raw,out,meta=make(*args);cases.append((name,raw,len(raw),out,meta))
base=make(0,[(0,0x8000,8192,0)])[0]
for name,index,value in [('signature',0,0),('version',20,2),('unsupported',23,2),('header_length',19,63),('exrom',24,2),('chip_magic',64,0),('packet_length',71,0),('chip_type',73,1),('bank_high',74,1),('load_addr',76,0x90),('image_size',78,0x10)]:
 raw=bytearray(base);raw[index]=value;cases.append((name,raw,len(raw),None,None))
for cut in [10,63,70,79,80,100,len(base)-1]:cases.append((f'truncated_{cut}',base[:cut],len(base),None,None))
raw=base+base[64:];cases.append(('duplicate',raw,len(raw),None,None))
raw=make(0,[(0,0x8000,8192,0)],0,0)[0];cases.append(('missing_high',raw,len(raw),None,None))
cases.append(('oversize',base,0x210041,None,None))
cases.append(('extra_byte',base+b'X',len(base),None,None))
# Optional slow exhaustive 2-MiB test; compact wrapper bounds are covered separately.
if '--long' in sys.argv:
 raw,out,meta=make(19,[(i,0x8000,16384,0)for i in range(128)])
 cases.append(('two_megabyte_boundary',raw,len(raw),out,meta))
 raw,out,meta=make(19,[(i,0x8000,16384,0)for i in range(129)])
 cases.append(('page_overflow',raw,len(raw),None,None))
logs=[]
def values(path):return [int(x,16)for x in path.read_text().splitlines()if x and not x.startswith('//')]
for name,raw,size,out,meta in cases:
 path=O/(name+'.hex');path.write_text('\n'.join(f'{v:02x}'for v in raw))
 args=[f'+FILE={path}',f'+ACTUAL={len(raw)}',f'+SIZE={size}',f'+SUCCESS={int(out is not None)}',f'+WRITES={len(out)if out is not None else 0}',f'+BANKS={len(meta)if meta else 0}']
 r=subprocess.run([str(B/'vvp.exe'),str(O/'test.vvp'),*args],cwd=O,capture_output=True,text=True,timeout=600 if '--long' in sys.argv else 30)
 logs.append(name+': '+r.stdout+r.stderr)
 assert r.returncode==0 and 'PASS CRT' in r.stdout,logs[-1]
 if out is not None:
  assert values(O/'result.hex')==list(out),name+' payload/mirror mismatch'
  assert values(O/'meta.hex')==meta,name+' metadata mismatch'
(T/'crt.log').write_text(''.join(logs));print(f'PASS CRT {len(cases)} generated valid/invalid files; exact payload, metadata, backpressure, 4K mirror, EOF/truncation, error reset; no bundled ROMs')
