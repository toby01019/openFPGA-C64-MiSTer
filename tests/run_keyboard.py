from pathlib import Path
import os,subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
cmd=[str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-s','tb','-o',str(T/'keyboard.vvp'),str(T/'tb_keyboard.sv'),str(P/'core/pocket_keyboard.sv')]
r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'keyboard.vvp')],capture_output=True,text=True)
(T/'keyboard.log').write_text(r.stdout+r.stderr)
print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS virtual keyboard' in r.stdout
