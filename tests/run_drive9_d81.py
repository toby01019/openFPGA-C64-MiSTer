from pathlib import Path
import subprocess
from drive_sim import drive_sources
T=Path(__file__).resolve().parent;P=T.parent
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
names=['pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_track_save.sv','pocket_gcr_d64.sv','file_reader.sv']
sources=[(T/'drive_converted/t65.v' if s.name=='standalone_T65.v' else s) for s in drive_sources()]+[P/'core'/n for n in names]+[P/'apf/common.v',T/'tb_drive9_d81.sv']
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'drive9_d81.vvp')]+[str(s) for s in sources],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'drive9_d81.vvp')],cwd=T,capture_output=True,text=True)
(T/'drive9_d81.log').write_text(r.stdout+r.stderr)
assert 'PASS drive9 D81' in r.stdout and 'FATAL' not in r.stdout,r.stdout+r.stderr
print(r.stdout,end='')

