"""Check actual RTL output by decoding GCR, not by reusing the RTL encoder."""
from pathlib import Path
import random,subprocess,os
T=Path(__file__).resolve().parent;P=T.parent
B=Path(os.environ.get('IVERILOG_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
def sectors(t):return 21 if t<=17 else 19 if t<=24 else 18 if t<=30 else 17
rng=random.Random(0xc641541)
fixture=bytes(rng.randrange(256) for t in range(1,43) for _ in range(sectors(t)*256))
assert len(fixture)==205312
(T/'d64_fixture.hex').write_text(''.join(f'{b:02x}\n'for b in fixture))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'d64-gcr.vvp'),
                  str(T/'tb_d64_gcr.sv'),str(P/'core/pocket_d64_gcr.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'d64-gcr.vvp')],cwd=T,capture_output=True,text=True)
(T/'d64_gcr.log').write_text(r.stdout+r.stderr)
assert r.returncode==0 and 'PASS D64 GCR' in r.stdout,r.stdout+r.stderr
raw=bytes(int(s,16)for s in (T/'d64_gcr_tracks.hex').read_text().splitlines())
# Standard 1541 five-bit symbol -> four-bit nibble table, rejecting illegal GCR.
decode={10:0,11:1,18:2,19:3,14:4,15:5,22:6,23:7,9:8,25:9,26:10,27:11,13:12,29:13,30:14,21:15}
def unpack(data):
    bits=''.join(f'{b:08b}'for b in data)
    assert len(bits)%10==0
    out=[]
    for n in range(0,len(bits),10):
        out.append(decode[int(bits[n:n+5],2)]*16+decode[int(bits[n+5:n+10],2)])
    return bytes(out)
pos=src=0;checked=nonzero_checksums=0
for track in range(1,43):
    size=int.from_bytes(raw[pos:pos+2],'little');pos+=2
    expected_size=7602 if track<=17 else 7049 if track<=24 else 6588 if track<=30 else 6171
    gap=8 if track<=17 else 17 if track<=24 else 12 if track<=30 else 9
    assert size==expected_size and 6000<size<8048
    end=pos+size
    for sector in range(sectors(track)):
        assert raw[pos:pos+5]==bytes([255])*5;pos+=5
        header=unpack(raw[pos:pos+10]);pos+=10
        assert header==bytes([8,sector^track^0x41^0xb7,sector,track,0xb7,0x41,15,15]),(track,sector,'header')
        assert raw[pos:pos+9]==bytes([0x55])*9;pos+=9
        assert raw[pos:pos+5]==bytes([255])*5;pos+=5
        block=unpack(raw[pos:pos+325]);pos+=325
        assert block[0]==7 and block[1:257]==fixture[src:src+256],(track,sector,'payload')
        checksum=0
        for b in fixture[src:src+256]:checksum^=b
        assert block[257:]==bytes([checksum,0,0]),(track,sector,'checksum/trailer')
        nonzero_checksums+=checksum!=0
        src+=256;checked+=1
        assert raw[pos:pos+gap]==bytes([0x55])*gap;pos+=gap
    assert pos==end,(track,'track length')
assert src==len(fixture) and pos==len(raw)
assert nonzero_checksums>790
message=f'PASS independent GCR decode: {checked} sectors, all42tracks, disk IDs/header XOR/data XOR/trailers/sync/gaps, all payload bytes identical; {nonzero_checksums} nonzero checksums'
with(T/'d64_gcr.log').open('a')as f:f.write(message+'\n')
print(r.stdout.strip());print(message)
