from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
args=[str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'dock_keyboard.vvp'),str(T/'tb_dock_keyboard.sv'),str(P/'core/pocket_dock_keyboard.sv'),str(P/'core/mailbox.sv')]
r=subprocess.run(args,capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'dock_keyboard.vvp')],capture_output=True,text=True,timeout=30)
log=r.stdout+r.stderr;(T/'dock-keyboard.log').write_text(log);print(log)
assert r.returncode==0 and 'PASS Dock keyboard' in log
