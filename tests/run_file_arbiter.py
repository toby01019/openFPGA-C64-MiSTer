from pathlib import Path
import subprocess
T=Path(__file__).resolve().parent;P=T.parent
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
names=['pocket_file_arbiter.sv','file_reader.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_track_save.sv','pocket_gcr_d64.sv','pocket_d81.sv','pocket_d81_storage.sv']
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'file_arbiter.vvp'),str(T/'tb_file_arbiter.sv'),str(P/'apf/common.v')]+[str(P/'core'/n) for n in names],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'file_arbiter.vvp')],capture_output=True,text=True)
(T/'file_arbiter.log').write_text(r.stdout+r.stderr)
assert 'PASS central arbiter' in r.stdout and 'FATAL' not in r.stdout,r.stdout+r.stderr
print(r.stdout,end='')
