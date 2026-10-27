from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
cmd=[str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'units.vvp'),str(T/'tb_mailbox_audio.sv'),str(P/'core/mailbox.sv'),str(P/'core/audio.sv')]
r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'units.vvp')],capture_output=True,text=True)
(T/'units.log').write_text(r.stdout+r.stderr)
print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS' in r.stdout
cmd=[str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'pocket-video-test.vvp'),str(T/'tb_pocket_video.sv'),str(T/'converted/video_sync.v'),str(P/'core/pocket_video.sv')]
r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'pocket-video-test.vvp')],capture_output=True,text=True)
(T/'pocket-video.log').write_text(r.stdout+r.stderr)
print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS Pocket VIDEO' in r.stdout
cmd=[str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'video-test.vvp'),str(T/'tb_video.sv'),str(T/'converted/video_sync.v')]
r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'video-test.vvp')],capture_output=True,text=True)
(T/'video.log').write_text(r.stdout+r.stderr)
print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS' in r.stdout
cmd=[str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'loader-test.vvp'),str(T/'tb_loader.sv'),str(P/'core/loader.sv')]
r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'loader-test.vvp')],capture_output=True,text=True)
(T/'loader.log').write_text(r.stdout+r.stderr)
print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS' in r.stdout
