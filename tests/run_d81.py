from pathlib import Path
import subprocess,os
T=Path(__file__).resolve().parent;P=T.parent
B=Path(os.environ.get('IVERILOG_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'d81.vvp'),str(T/'tb_d81.sv'),str(P/'core/pocket_d81.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'d81.vvp')],capture_output=True,text=True)
(T/'d81.log').write_text(r.stdout+r.stderr)
assert 'PASS D81 frontend' in r.stdout and 'FATAL' not in r.stdout,r.stdout+r.stderr
print(r.stdout,end='')
