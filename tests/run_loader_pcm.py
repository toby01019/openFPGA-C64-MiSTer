from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
out=T/'loader-pcm.vvp'
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(out),str(T/'tb_loader_pcm.sv'),str(P/'core/loader.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
logs=[]
for mode in range(6):
 r=subprocess.run([str(B/'vvp.exe'),str(out),f'+MODE={mode}'],capture_output=True,text=True,timeout=60)
 logs.append(r.stdout+r.stderr);assert r.returncode==0,logs[-1]
(T/'loader-pcm.log').write_text(''.join(logs));print(''.join(logs))
