from pathlib import Path
import hashlib,struct,subprocess,sys,os
from cartridge_sim import cartridge_sources
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'private-caren';O.mkdir(exist_ok=True)
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
quick='--quick' in sys.argv
if quick:
 game=bytearray(64);game[:16]=b'C64 CARTRIDGE   ';game[16:20]=(64).to_bytes(4,'big');game[20:22]=(256).to_bytes(2,'big');game[22:24]=(32).to_bytes(2,'big');game[24:26]=b'\x01\x00'
 game+=b'CHIP'+struct.pack('>IHHHH',8208,2,0,0x8000,8192)+bytes((i*17+13)&255 for i in range(8192))
 O=T/'easyflash-quick';O.mkdir(exist_ok=True)
else:
 game=Path(os.environ.get('CAREN_CRT','C:/Users/toby0/Downloads/caren2018tye/caren2018tye.crt')).read_bytes()
assert int.from_bytes(game[22:24],'big')==32
expected=bytearray(b'\xff'*1048576);pos=int.from_bytes(game[16:20],'big');count=0
while pos<len(game):
 assert game[pos:pos+4]==b'CHIP'
 packet,typ,bank,address,n=struct.unpack('>IHHHH',game[pos+4:pos+16]);assert packet==n+16 and bank<64
 for j,v in enumerate(game[pos+16:pos+packet]):
  high=address!=0x8000 or (n==16384 and j>=8192)
  expected[(524288 if high else 0)+bank*8192+(j%8192)]=v
 pos+=packet;count+=1
for name,data in [('caren.hex',game),('expected.hex',expected)]:
 (O/name).write_text('\n'.join(f'{v:02x}'for v in data))
tb=T/'tb_easyflash.sv'
if quick:
 text=tb.read_text().replace('pocket_cartridge #','defparam dut.easyflash_port.ef.INIT_WORDS=1024;\ndefparam dut.easyflash_port.ef.FLASH_SECTOR_CYCLES=100;\npocket_cartridge #').replace('cart_psram_model physical','cart_psram_model #(.INITIAL_WORD(16\'hffff)) physical')
 tb=O/'tb.sv';tb.write_text(text)
sources=[tb,T/'cart_psram_model.sv',P/'core/psram.sv',*cartridge_sources()]
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'test.vvp'),*map(str,sources)],capture_output=True,text=True)
(T/('easyflash-quick-compile.log'if quick else 'easyflash-compile.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
with (T/('easyflash-quick.log'if quick else 'easyflash.log')).open('w')as f:
 f.write(f'Local test image SHA256 {hashlib.sha256(game).hexdigest()}, {count} CHIP packets; excluded from release\n');f.flush()
 r=subprocess.run([str(B/'vvp.exe'),str(O/'test.vvp'),f'+FILE={O/"caren.hex"}',f'+SIZE={len(game)}',f'+EXPECTED={O/"expected.hex"}'],stdout=f,stderr=subprocess.STDOUT,text=True,timeout=3600)
log=(T/('easyflash-quick.log'if quick else 'easyflash.log')).read_text();print(log);assert r.returncode==0 and 'PASS EasyFlash:' in log

