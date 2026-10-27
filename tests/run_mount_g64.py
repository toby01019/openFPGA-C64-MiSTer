from pathlib import Path
import os,subprocess,sys
T=Path(__file__).resolve().parent;P=T.parent
B=Path(os.environ.get('IVERILOG_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
sources=['tests/tb_mount_g64.sv','core/pocket_storage.sv','core/pocket_disk.sv','core/pocket_d64_gcr.sv','core/pocket_track_save.sv','core/pocket_gcr_d64.sv','apf/common.v']
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'mount_g64.vvp')]+[str(P/s) for s in sources],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'mount_g64.vvp')]+sys.argv[1:],capture_output=True,text=True,cwd=T)
(T/('mount_g64'+''.join(sys.argv[1:])+'.log')).write_text(r.stdout+r.stderr)
assert 'PASS G64 mount' in r.stdout and 'FATAL' not in r.stdout,r.stdout+r.stderr
print(r.stdout,end='')

lines=iter((T/'mount_g64_tracks.hex').read_text().splitlines());checked=0
for line in lines:
 _,head,size=line.split();head=int(head);size=int(size)
 data=bytes(int(next(lines),16)for _ in range(size+2))
 off=64 if head==0 else 6070
 assert data[:2]==(6001).to_bytes(2,'little')
 assert data[2:]==bytes((a&255)^0x5a for a in range(off+2,off+6003))
 checked+=1
assert checked==2
print('PASS G64 raw track bytes exact, runtime mount, no stuck pause')
