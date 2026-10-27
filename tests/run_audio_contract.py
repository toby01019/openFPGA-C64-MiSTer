from pathlib import Path
import subprocess,sys
P=Path(__file__).resolve().parents[1]; T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
before='--before' in sys.argv
source=T/'hardware-fix-baseline/audio-0.4.1.sv' if before else P/'core/audio.sv'
name='audio-contract-before' if before else 'audio-contract'
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/(name+'.vvp')),str(T/'tb_audio_contract.sv'),str(source)],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/(name+'.vvp'))],capture_output=True,text=True)
log=r.stdout+r.stderr;(T/(name+'.log')).write_text(log);print(log)
if before:assert 'FATAL' in log and 'channel truncated' in log,log
else:assert r.returncode==0 and 'PASS I2S contract' in log and 'FATAL' not in log,log
