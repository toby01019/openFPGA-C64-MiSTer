from pathlib import Path
import os,random,subprocess,json
T=Path(__file__).resolve().parent;P=T.parent
B=Path(os.environ.get('IVERILOG_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
lut=[10,11,18,19,14,15,22,23,9,25,26,27,13,29,30,21]
def encode(data):
    bits=''.join(f'{lut[b>>4]:05b}{lut[b&15]:05b}'for b in data)
    return bytes(int(bits[i:i+8],2)for i in range(0,len(bits),8))
def sectors(t):return 21 if t<=17 else 19 if t<=24 else 18 if t<=30 else 17
def make_track(t,data):
    raw=bytearray();gap=8 if t<=17 else 17 if t<=24 else 12 if t<=30 else 9
    for s in range(sectors(t)):
        block=data[s*256:s*256+256];cs=0
        for b in block:cs^=b
        raw+=b'\xff'*5+encode(bytes([8,s^t^0x41^0xb7,s,t,0xb7,0x41,15,15]))
        raw+=b'\x55'*9+b'\xff'*5+encode(bytes([7])+block+bytes([cs,0,0]))+b'\x55'*gap
    return bytes(raw)
def rotate(raw,n):
    bits=''.join(f'{b:08b}'for b in raw);bits=bits[n:]+bits[:n]
    return bytes(int(bits[i:i+8],2)for i in range(0,len(bits),8))
rng=random.Random(0x6415415);cases=[]
def add(name,fmt,half,raw,expected,err=0,fail_write=0,fail_flush=0,offset=10003,limit=None,param=None):
    cases.append(dict(name=name,format=fmt,half=half,raw=raw,expected=expected,error=err,
                      fail_write=fail_write,fail_flush=fail_flush,offset=offset,
                      limit=offset+len(expected)if limit is None else limit,param=len(raw)if param is None else param))
payload={t:bytes(rng.randrange(256)for _ in range(sectors(t)*256))for t in [1,18,25,31]}
raws={t:make_track(t,payload[t])for t in payload}
for t in payload:add(f'd64_track_{t}',1,(t-1)*2,rotate(raws[t],1341),payload[t])
g=bytes(rng.randrange(256)for _ in range(6201));g_all=len(g).to_bytes(2,'little')+g
add('g64_unaligned_partial_word',2,2,g,g_all,offset=689)
big=bytes(rng.randrange(256)for _ in range(8190));add('g64_full_8k',2,0,big,len(big).to_bytes(2,'little')+big)
add('g64_empty',2,1,b'',b'\0\0')
bad=bytearray(raws[1]);bad[29:34]=b'\x00'*5
add('d64_invalid_no_writes',1,0,bytes(bad),payload[1],err=0x22)
add('raw_65535_rejected',2,0,g,g_all,err=2,param=65535)
add('header_length_mismatch',2,0,g,g_all[:-1],err=4,param=6200)
add('d64_halftrack_rejected',1,1,raws[1],payload[1],err=2)
add('g64_region_too_small',2,0,g,g_all,err=3,limit=10003+len(g_all)-1)
add('offset_overflow',2,0,g,g_all,err=3,offset=0xffffff00,limit=0xffffffff)
add('first_write_error_no_flush',2,0,g,g_all,err=6,fail_write=1)
add('second_write_error_no_flush',1,0,raws[1],payload[1],err=6,fail_write=2)
add('flush_error',2,0,g,g_all,err=7,fail_flush=1)
add('bad_format',0,0,g,g_all,err=1)
source=bytearray();expected=bytearray();vh=''
for i,c in enumerate(cases):
    region=len(c['raw']).to_bytes(2,'little')+c['raw'];assert len(region)<=8192
    source+=region+bytes(8192-len(region))
    for field in ['format','half','error','fail_write','fail_flush','param']:
        vh+=f'c_{field}[{i}]={c[field]};'
    vh+=f'c_offset[{i}]=32\'h{c["offset"]:08x};c_limit[{i}]=32\'h{c["limit"]:08x};'
    vh+=f'c_expected_offset[{i}]={len(expected)};c_expected_length[{i}]={len(c["expected"])};\n'
    expected+=c['expected']
(T/'track_save_cases.vh').write_text(vh)
(T/'track_save_fixture.hex').write_text(''.join(f'{b:02x}\n'for b in source))
(T/'track_save_expected.hex').write_text(''.join(f'{b:02x}\n'for b in expected))
(T/'track_save_cases.json').write_text(json.dumps([{k:v for k,v in c.items()if k not in ['raw','expected']}for c in cases],indent=2))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I'+str(T),'-s','tb',f'-Ptb.CASES={len(cases)}',
                  f'-Ptb.EXPECTED_BYTES={len(expected)}','-o',str(T/'track-save.vvp'),str(T/'tb_track_save.sv'),
                  str(P/'core/pocket_track_save.sv'),str(P/'core/pocket_gcr_d64.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'track-save.vvp')],cwd=T,capture_output=True,text=True)
(T/'track_save.log').write_text(r.stdout+r.stderr)
assert r.returncode==0 and 'PASS track save' in r.stdout,r.stdout+r.stderr
print(r.stdout.strip())
