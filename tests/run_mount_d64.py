from pathlib import Path
import os,subprocess,sys,hashlib,json,argparse
T=Path(__file__).resolve().parent;P=T.parent
B=Path(os.environ.get('IVERILOG_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
parser=argparse.ArgumentParser()
parser.add_argument('--image',type=Path)
parser.add_argument('--rom',type=Path)
parser.add_argument('--synthetic',action='store_true')
args,modes=parser.parse_known_args()
assert all(a in ['+swap','+failopen','+failget','+readonly','+runtime'] for a in modes)
image=args.image.read_bytes() if args.image else bytes((i*37+17)&255 for i in range(174848))
rom=args.rom.read_bytes() if args.rom else bytes(i&255 for i in range(16384))
assert len(image)==174848 and len(rom)==16384
label='mount_d64'+''.join(modes)+('-real' if args.image else '-synthetic')
(T/'mount_d64.hex').write_text(''.join(f'{b:02x}\n' for b in image))
(T/'mount_rom.hex').write_text(''.join(f'{b:02x}\n' for b in rom))
sources=['tests/tb_mount_d64.sv','core/pocket_storage.sv','core/pocket_disk.sv','core/pocket_d64_gcr.sv','core/pocket_track_save.sv','core/pocket_gcr_d64.sv','apf/common.v']
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'mount_d64.vvp')]+[str(P/s) for s in sources],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'mount_d64.vvp')]+modes,capture_output=True,text=True,cwd=T)
(T/(label+'.log')).write_text(r.stdout+r.stderr)
assert 'PASS D64 mount' in r.stdout and 'FATAL' not in r.stdout,r.stdout+r.stderr
print(r.stdout,end='')

decode={10:0,11:1,18:2,19:3,14:4,15:5,22:6,23:7,9:8,25:9,26:10,27:11,13:12,29:13,30:14,21:15}
def unpack(data):
 bits=''.join(f'{b:08b}' for b in data)
 return bytes((decode[int(bits[n:n+5],2)]<<4)|decode[int(bits[n+5:n+10],2)] for n in range(0,len(bits),10))
def sectors(t):return 21 if t<=17 else 19 if t<=24 else 18 if t<=30 else 17
lines=iter((T/'mount_tracks.hex').read_text().splitlines());checked=0;id1,id2=image[91554:91556]
for line in lines:
 _,head,size=line.split();track=int(head)//2+1;size=int(size)
 data=bytes(int(next(lines),16) for _ in range(size+2))
 assert int.from_bytes(data[:2],'little')==size
 pos=2;src=sum(sectors(t)*256 for t in range(1,track));gap=8 if track<=17 else 17 if track<=24 else 12 if track<=30 else 9
 for sector in range(sectors(track)):
  assert data[pos:pos+5]==b'\xff'*5;pos+=5
  h=unpack(data[pos:pos+10]);pos+=10
  assert h==bytes([8,sector^track^id1^id2,sector,track,id2,id1,15,15])
  assert data[pos:pos+9]==b'\x55'*9;pos+=9
  assert data[pos:pos+5]==b'\xff'*5;pos+=5
  d=unpack(data[pos:pos+325]);pos+=325
  assert d[0]==7 and d[1:257]==image[src:src+256],(track,sector)
  checksum=0
  for b in image[src:src+256]:checksum^=b
  assert d[257:]==bytes([checksum,0,0]);src+=256
  assert data[pos:pos+gap]==b'\x55'*gap;pos+=gap
 assert pos==len(data);checked+=1
assert checked==35
message='PASS independent decode: all 683 D64 sectors, BAM IDs, checksums; supplied ROM upload exact'
print(message)
with (T/(label+'.log')).open('a') as log:log.write(message+'\n')
(T/(label+'.json')).write_text(json.dumps({'image_sha256':hashlib.sha256(image).hexdigest(),'rom_sha256':hashlib.sha256(rom).hexdigest(),'storage_sha256':hashlib.sha256((P/'core/pocket_storage.sv').read_bytes()).hexdigest(),'modes':modes,'tracks':checked,'sectors':683},indent=2))
