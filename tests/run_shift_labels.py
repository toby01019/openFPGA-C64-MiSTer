from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-s','tb','-o',str(T/'shift_labels.vvp'),str(T/'tb_shift_labels.sv'),str(P/'core/pocket_keyboard.sv'),str(P/'core/pocket_keyboard_video.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'shift_labels.vvp')],capture_output=True,text=True)
log=r.stdout+r.stderr;(T/'shift-labels.log').write_text(log);print(log)
assert r.returncode==0 and 'PASS Shift labels' in log
