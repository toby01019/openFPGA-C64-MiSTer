from pathlib import Path
import os, subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-s','tb','-o',str(T/'review_keyboard_overlap.vvp'),
 str(T/'review_keyboard_overlap.sv'),str(P/'core/pocket_keyboard.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'review_keyboard_overlap.vvp')],capture_output=True,text=True)
log=r.stdout+r.stderr;(T/'review_keyboard_overlap.log').write_text(log);print(log)
assert r.returncode==0 and 'PASS overlapping' in log,log
