from pathlib import Path
import os,subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'reu_sim';O.mkdir(exist_ok=True)
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'physical.vvp'),str(T/'tb_reu_psram.sv'),str(P/'core/pocket_reu.v'),str(P/'core/pocket_psram.sv'),str(P/'core/psram.sv')],capture_output=True,text=True)
(T/'reu_psram_compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(O/'physical.vvp')],capture_output=True,text=True,timeout=120)
log=r.stdout+r.stderr;(T/'reu_psram.log').write_text(log);print(log);assert r.returncode==0 and 'PASS REU' in log
