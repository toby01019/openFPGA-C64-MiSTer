from pathlib import Path
import subprocess
T=Path(__file__).resolve().parent;P=T.parent
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
Q=Path('C:/Users/toby0/Documents/Codex/tools/quartus25/quartus')
log=''
for vendor in [False,True]:
 cmd=[str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'sector_ram.vvp')]
 if vendor:cmd+=['-DPOCKET_ALTERA_RAM']
 cmd += [str(T/'tb_sector_ram.sv'),str(P/'core/pocket_1581.sv')]
 if vendor:cmd += [str(Q/'eda/sim_lib/altera_mf.v')]
 r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
 r=subprocess.run([str(B/'vvp.exe'),str(T/'sector_ram.vvp')],capture_output=True,text=True)
 assert 'PASS sector RAM' in r.stdout and 'FATAL' not in r.stdout,r.stdout+r.stderr
 log+=('Intel: ' if vendor else 'Behavioral: ')+r.stdout
(T/'sector_ram.log').write_text(log);print(log)
