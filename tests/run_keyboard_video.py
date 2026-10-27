from pathlib import Path
import os,subprocess,sys
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
cmd=[str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-s','tb','-o',str(T/'review_vkb_video.vvp'),
     str(T/'review_vkb_video.sv'),str(P/'core/pocket_keyboard_video.sv'),str(P/'core/pocket_video.sv')]
r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'review_vkb_video.vvp')],cwd=T,capture_output=True,text=True)
(T/'review_vkb_video.log').write_text(r.stdout+r.stderr)
print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS keyboard video' in r.stdout
r=subprocess.run([sys.executable,str(T/'review_vkb_preview.py')],capture_output=True,text=True)
(T/'keyboard-preview.log').write_text(r.stdout+r.stderr)
print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS keyboard pixels' in r.stdout
