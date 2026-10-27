"""Build a separate Pocket disk; preserve the original Ultimate distribution."""
from pathlib import Path
import subprocess,hashlib,json,shutil,os
P=Path(__file__).resolve().parent
original=P/'resources'
local_tool=Path('C:/Users/toby0/Downloads/GTK3VICE-3.10-win64/GTK3VICE-3.10-win64/bin/c1541.exe')
tool=os.environ.get('C1541',str(local_tool)if local_tool.exists()else 'c1541')
out=P/'TobyPink-Pocket-V027.d64'
files=[(P/'toby-try-to-save-the-pink-title-v0.3.27.prg','TOBY TITLE'),
       (P/'toby-try-to-save-the-pink-v0.3.27.prg','TOBY PINK'),
       (original/'toby-reward-music-v0.3.27.prg','TOBY MUSIC'),
       (original/'toby-reward-scene-v0.3.27.prg','TOBY REWARD')]
args=[tool,'-format','toby pink,38','d64',str(out)]
for f,name in files:args+=['-write',str(f),name]
r=subprocess.run(args,capture_output=True,text=True);assert r.returncode==0,r.stdout+r.stderr
data=bytearray(out.read_bytes())
def sectors(t):return 21 if t<=17 else 19 if t<=24 else 18 if t<=30 else 17
def at(t,s):return (sum(sectors(i)for i in range(1,t))+s)*256
t,s=18,1;extracted={}
while t:
 a=at(t,s)
 for i in range(8):
  b=a+i*32
  if not data[b+2]&7:continue
  name=bytes(c&127 for c in bytes(data[b+5:b+21]).rstrip(b'\xa0')).decode('ascii')
  track,sector=data[b+3:b+5];payload=bytearray();seen=set()
  while track:
   assert (track,sector)not in seen;seen.add((track,sector));pos=at(track,sector)
   nt,ns=data[pos:pos+2];payload+=data[pos+2:pos+(ns+1 if nt==0 else 256)]
   track,sector=nt,ns
  extracted[name]=bytes(payload)
  for j in range(16):
   off=b+5+j
   if 65<=data[off]<=90:data[off]|=128
 t,s=data[a:a+2]
for f,name in files:assert extracted[name]==f.read_bytes(),name
out.write_bytes(data)
bank=P/'resources/V027-AUDIO.REU'
shutil.copy2(bank,P/'V027-AUDIO.REU')
manifest={p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in [out,P/'V027-AUDIO.REU']}
(P/'checksums.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PASS Pocket D64: all four PRGs extracted byte-identically; original Ultimate release untouched.')
print(json.dumps(manifest,indent=2))

