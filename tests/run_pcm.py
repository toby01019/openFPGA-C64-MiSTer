from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'private-audio';O.mkdir(exist_ok=True)
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
bank_path=P/'test_assets/V027-AUDIO.REU'
if not bank_path.exists():bank_path=P/'tobypink-pocket/resources/V027-AUDIO.REU'
bank=bank_path.read_bytes();assert len(bank)==272296
(O/'bank.hex').write_text('\n'.join(f'{x:02x}'for x in bank))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'pcm.vvp'),str(T/'tb_pcm.sv'),str(P/'core/pocket_pcm.sv')],capture_output=True,text=True)
(T/'pcm-compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(O/'pcm.vvp'),f'+BANK={O/"bank.hex"}'],capture_output=True,text=True,timeout=120)
(T/'pcm.log').write_text(r.stdout+r.stderr);print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS PCM:'in r.stdout
