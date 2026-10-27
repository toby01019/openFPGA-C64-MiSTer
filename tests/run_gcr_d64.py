"""Independent raw GCR fixtures for validated D64 writeback."""
from pathlib import Path
import os,random,subprocess,json
T=Path(__file__).resolve().parent;P=T.parent
B=Path(os.environ.get('IVERILOG_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
lut=[10,11,18,19,14,15,22,23,9,25,26,27,13,29,30,21]
def encode(data):
    bits=''.join(f'{lut[b>>4]:05b}{lut[b&15]:05b}' for b in data)
    assert len(bits)%8==0
    return bytes(int(bits[i:i+8],2)for i in range(0,len(bits),8))
def nsectors(t):return 21 if t<=17 else 19 if t<=24 else 18 if t<=30 else 17
def make_track(track,payload):
    result=bytearray();gap=8 if track<=17 else 17 if track<=24 else 12 if track<=30 else 9
    for sector in range(nsectors(track)):
        data=payload[sector*256:(sector+1)*256];checksum=0
        for b in data:checksum^=b
        result+=b'\xff'*5+encode(bytes([8,sector^track^0x41^0xb7,sector,track,0xb7,0x41,15,15]))
        result+=b'\x55'*9+b'\xff'*5+encode(bytes([7])+data+bytes([checksum,0,0]))+b'\x55'*gap
    return bytes(result)
def rotate(data,bit_offset):
    bits=''.join(f'{b:08b}'for b in data);bit_offset%=len(bits)
    bits=bits[bit_offset:]+bits[:bit_offset]
    return bytes(int(bits[i:i+8],2)for i in range(0,len(bits),8))
rng=random.Random(0x1541d64)
payloads={t:bytes(rng.randrange(256)for _ in range(nsectors(t)*256))for t in [1,18,25,31,42]}
tracks={t:make_track(t,payloads[t])for t in payloads}
cases=[]
def add(name,t,raw,expected=None,error=0):cases.append(dict(name=name,track=t,raw=raw,expected=expected or b'',error=error))
for shift in range(8):
    rotated=rotate(tracks[1],(31+shift*113)*8+shift)
    add(f'rotation_bit_phase_{shift}',1,rotated*2,payloads[1])
for track in [18,25,31,42]:
    rotated=rotate(tracks[track],len(tracks[track])*8-1013)
    add(f'density_track_{track}',track,rotated*2,payloads[track])
raw=tracks[1];payload=payloads[1]
# Corrupt one sector in BOTH revolutions: no partial output may escape.
bad=bytearray(raw);bad[:362]=b'\x55'*362
add('missing_sector',1,bytes(bad)*2,error=2)
bad=bytearray(raw);bad[5:15]=encode(bytes([8,0,0,1,0xb7,0x41,15,15]))
add('header_xor',1,bytes(bad)*2,error=2)
bad=bytearray(raw);bad[5:15]=encode(bytes([8,1^0x40^0xb7,0,1,0xb7,0x40,15,15]))
add('wrong_disk_id',1,bytes(bad)*2,error=2)
bad=bytearray(raw);bad[29:34]=b'\x00'*5
add('illegal_gcr',1,bytes(bad)*2,error=2)
checksum=0
for b in payload[:256]:checksum^=b
bad=bytearray(raw);bad[29:354]=encode(bytes([7])+payload[:256]+bytes([checksum^1,0,0]))
add('data_xor',1,bytes(bad)*2,error=2)
# A corrupt duplicate must not overwrite the previously validated sector RAM.
add('bad_duplicate_preserves_good_sector',1,raw+bytes(bad),payload)
bad=bytearray(raw);bad[29:354]=encode(bytes([7])+payload[:256]+bytes([checksum,0,1]))
add('bad_trailer',1,bytes(bad)*2,error=2)
add('truncated_track',1,raw[:len(raw)//2],error=2)
add('no_sync',1,b'\x55'*512,error=2)
modified=bytearray(payload);modified[:256]=bytes(b^0x5a for b in payload[:256])
add('valid_duplicate_replaces_sector',1,raw+make_track(1,modified),bytes(modified))
add('invalid_track_zero',0,b'\x00',error=1)
add('invalid_track_43',43,b'\x00',error=1)
source=bytearray();expected=bytearray();vh=''
for i,c in enumerate(cases):
    vh+=f'case_offset[{i}]={len(source)};case_length[{i}]={len(c["raw"])};case_track[{i}]={c["track"]};'
    vh+=f'case_expected_offset[{i}]={len(expected)};case_expected_length[{i}]={len(c["expected"])};case_error[{i}]={c["error"]};\n'
    source+=c['raw'];expected+=c['expected']
(T/'gcr_d64_cases.vh').write_text(vh)
(T/'gcr_d64_fixture.hex').write_text(''.join(f'{b:02x}\n'for b in source))
(T/'gcr_d64_expected.hex').write_text(''.join(f'{b:02x}\n'for b in expected))
(T/'gcr_d64_cases.json').write_text(json.dumps([{k:v for k,v in c.items()if k not in ['raw','expected']}for c in cases],indent=2))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I'+str(T),'-s','tb',
                  f'-Ptb.CASES={len(cases)}',f'-Ptb.SOURCE_BYTES={len(source)}',f'-Ptb.EXPECTED_BYTES={len(expected)}',
                  '-o',str(T/'gcr-d64.vvp'),str(T/'tb_gcr_d64.sv'),str(P/'core/pocket_gcr_d64.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'gcr-d64.vvp')],cwd=T,capture_output=True,text=True)
(T/'gcr_d64.log').write_text(r.stdout+r.stderr)
assert r.returncode==0 and 'PASS GCR D64 decoder' in r.stdout,r.stdout+r.stderr
print(r.stdout.strip())
