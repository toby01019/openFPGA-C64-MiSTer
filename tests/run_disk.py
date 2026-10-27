from pathlib import Path
import os,random,subprocess
T=Path(__file__).resolve().parent;P=T.parent
B=Path(os.environ.get('IVERILOG_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
rng=random.Random(154164)
fixture=bytearray(rng.randrange(256) for _ in range(205312))
fixture[91554:91556]=bytes([0x41,0xb7])
(T/'disk_d64_fixture.hex').write_text(''.join(f'{b:02x}\n'for b in fixture))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'disk.vvp'),str(T/'tb_disk.sv'),
                  str(P/'core/pocket_disk.sv'),str(P/'core/pocket_d64_gcr.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'disk.vvp')],cwd=T,capture_output=True,text=True)
(T/'disk.log').write_text(r.stdout+r.stderr)
assert r.returncode==0 and 'PASS disk frontend' in r.stdout,r.stdout+r.stderr
decode={10:0,11:1,18:2,19:3,14:4,15:5,22:6,23:7,9:8,25:9,26:10,27:11,13:12,29:13,30:14,21:15}
def unpack(data):
    bits=''.join(f'{b:08b}' for b in data)
    return bytes((decode[int(bits[n:n+5],2)]<<4)|decode[int(bits[n+5:n+10],2)]for n in range(0,len(bits),10))
def sectors(t):return 21 if t<=17 else 19 if t<=24 else 18 if t<=30 else 17
lines=iter((T/'disk_d64_tracks.hex').read_text().splitlines());checked=0
for line in lines:
    _,head,size=line.split();track=int(head)//2+1;size=int(size)
    data=bytes(int(next(lines),16)for _ in range(size+2))
    assert int.from_bytes(data[:2],'little')==size
    pos=2;src=sum(sectors(t)*256 for t in range(1,track));gap=8 if track<=17 else 17 if track<=24 else 12 if track<=30 else 9
    for sector in range(sectors(track)):
        assert data[pos:pos+5]==b'\xff'*5;pos+=5
        h=unpack(data[pos:pos+10]);pos+=10
        assert h==bytes([8,sector^track^0x41^0xb7,sector,track,0xb7,0x41,15,15])
        assert data[pos:pos+9]==b'\x55'*9;pos+=9
        assert data[pos:pos+5]==b'\xff'*5;pos+=5
        d=unpack(data[pos:pos+325]);pos+=325
        assert d[0]==7 and d[1:257]==fixture[src:src+256],(track,sector,'payload/file offset')
        checksum=0
        for b in fixture[src:src+256]:checksum^=b
        assert d[257:]==bytes([checksum,0,0]);src+=256
        assert data[pos:pos+gap]==b'\x55'*gap;pos+=gap
    assert pos==len(data);checked+=1
message=f'PASS independent disk frontend decode: {checked} complete tracks, all density offsets, BAM disk IDs and sector bytes/checksums verified'
with(T/'disk.log').open('a')as f:f.write(message+'\n')
print(r.stdout.strip());print(message)
