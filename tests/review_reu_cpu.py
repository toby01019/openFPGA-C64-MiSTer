from pathlib import Path
import subprocess
from drive_sim import drive_sources
from cartridge_sim import cartridge_sources
T=Path(__file__).resolve().parent;P=T.parent;O=T/'converted'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
sources=[T/'review_reu_cpu.sv',O/'core_top_sim.sv',O/'c64.v',O/'video_sync.v',P/'rtl/mos6526.v',P/'apf/common.v',P/'core/core_bridge_cmd.v']
sources += [P/'core'/n for n in ['audio.sv','keys.sv','pocket_dock_keyboard.sv','mailbox.sv','loader.sv','file_reader.sv','pocket_video.sv','pocket_keyboard.sv','pocket_keyboard_video.sv','pocket_storage.sv','pocket_disk.sv','pocket_d64_gcr.sv','pocket_gcr_d64.sv','pocket_track_save.sv','pocket_reu.v','psram.sv','pocket_psram.sv']]
sources += [O/s.name for s in (P/'rtl/sid').glob('*.sv')]
sources += drive_sources()+cartridge_sources()+[T/'psram_model.sv']
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-D__VERILATOR__','-s','tb','-o',str(T/'review_reu_cpu.vvp')]+[str(s) for s in sources],capture_output=True,text=True)
assert r.returncode==0,r.stderr
with (T/'review_reu_cpu.log').open('w') as f:r=subprocess.run([str(B/'vvp.exe'),str(T/'review_reu_cpu.vvp')],cwd=T,stdout=f,stderr=subprocess.STDOUT,timeout=300)
log=(T/'review_reu_cpu.log').read_text()
print(log[-1500:])
assert r.returncode==0 and 'PASS isolated actual CPU' in log and 'FATAL' not in log,log[-1500:]
