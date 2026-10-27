from pathlib import Path
import os,subprocess,struct
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'loader_crt_sim';O.mkdir(exist_ok=True)
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
raw=b'C64 CARTRIDGE   '+struct.pack('>IHHBB',64,0x100,0,0,1)+bytes(38)+b'CHIP'+struct.pack('>IHHHH',8208,0,0,0x8000,8192)+bytes((i*17+3)&255 for i in range(8192))
path=O/'synthetic.hex';path.write_text('\n'.join(f'{v:02x}'for v in raw))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'test.vvp'),str(T/'tb_loader_crt.sv'),*[str(P/'core'/f)for f in ['loader.sv','mailbox.sv','pocket_crt.sv']]],capture_output=True,text=True)
(T/'loader_crt_compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
logs=[]
for mode in range(3):
 args=[str(B/'vvp.exe'),str(O/'test.vvp'),f'+FILE={path}',f'+INITIAL={mode}']
 if mode:args.append('+STARTUP_ONLY')
 logfile=T/f'loader-crt-case{mode}.log'
 with logfile.open('w')as out:r=subprocess.run(args,stdout=out,stderr=subprocess.STDOUT,text=True,timeout=900)
 log=logfile.read_text();logs.append(log);(T/'loader_crt.log').write_text(''.join(logs));print(log,flush=True)
 assert r.returncode==0 and ('PASS CRT startup' if mode else 'PASS CRT loader') in log,logs[-1]
print(''.join(logs))
