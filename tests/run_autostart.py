from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'autostart.vvp'),str(T/'tb_autostart.sv'),str(P/'core/pocket_autostart.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'autostart.vvp')],capture_output=True,text=True,timeout=30)
log=r.stdout+r.stderr;(T/'autostart.log').write_text(log);print(log)
assert r.returncode==0 and 'PASS autostart' in log
