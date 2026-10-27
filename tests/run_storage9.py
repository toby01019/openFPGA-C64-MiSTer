from pathlib import Path
import os,subprocess
T=Path(__file__).resolve().parent;P=T.parent
B=Path(os.environ.get('IVERILOG_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
sources=['tests/tb_storage9.sv','core/pocket_storage.sv','core/pocket_disk.sv','core/pocket_d64_gcr.sv','core/pocket_track_save.sv','core/pocket_gcr_d64.sv','apf/common.v']
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'storage9.vvp')]+[str(P/s) for s in sources],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'storage9.vvp')],capture_output=True,text=True)
(T/'storage9.log').write_text(r.stdout+r.stderr)
assert 'PASS drive9 1541 storage session' in r.stdout and 'FATAL' not in r.stdout,r.stdout+r.stderr
print(r.stdout,end='')
# Also elaborate production reader and storage together (mock is not included).
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','pocket_storage','-o',str(T/'storage_production.vvp')]+[str(P/s) for s in sources[1:]]+[str(P/'core/file_reader.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
print('PASS production storage/file_reader elaboration')
