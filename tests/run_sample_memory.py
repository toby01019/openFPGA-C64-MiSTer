from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'private-audio'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
sources=[T/'tb_sample_memory.sv',T/'cart_psram_model.sv',*[P/'core'/n for n in ['pocket_sample_memory.sv','pocket_ram_arbiter.sv','pocket_pcm.sv','pocket_psram.sv','psram.sv']]]
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'memory.vvp'),*map(str,sources)],capture_output=True,text=True)
(T/'sample-memory-compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(O/'memory.vvp'),f'+BANK={O/"bank.hex"}'],capture_output=True,text=True,timeout=120)
(T/'sample-memory.log').write_text(r.stdout+r.stderr);print((r.stdout+r.stderr)[-1800:]);assert r.returncode==0 and 'PASS shared'in r.stdout
