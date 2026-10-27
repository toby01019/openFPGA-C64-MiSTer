from pathlib import Path
import os,subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'file_ops.vvp'),str(T/'tb_file_ops.sv'),str(P/'core/file_reader.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'file_ops.vvp')],capture_output=True,text=True,timeout=30)
log=r.stdout+r.stderr;(T/'file_ops.log').write_text(log);print(log);assert r.returncode==0 and 'PASS APF file operations' in log
