from pathlib import Path
import subprocess,time
from drive_sim import drive_sources
from cartridge_sim import cartridge_sources
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'converted'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
sources=[T/'tb_integration.sv',O/'core_top_sim.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources += [P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_keyboard.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
sources+=list(O.glob('sid_*.sv'))+drive_sources()+cartridge_sources()
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-pfileline=1','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'review_delta.vvp'),*[str(s)for s in sources]],capture_output=True,text=True)
assert r.returncode==0,r.stderr[-3000:]
with (T/'review_delta.log').open('w')as out:
 p=subprocess.Popen([str(B/'vvp.exe'),'-v','-i','-s',str(T/'review_delta.vvp')],cwd=T,stdin=subprocess.PIPE,stdout=out,stderr=subprocess.STDOUT,text=True)
 try:p.communicate('trace on\ncont\n',timeout=5)
 except subprocess.TimeoutExpired:p.kill();p.communicate()
lines=(T/'review_delta.log').read_text().splitlines();print('\n'.join(lines[-60:]))
