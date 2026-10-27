"""Check the synthesised mixed-width primitive using Intel's simulation model."""
from pathlib import Path
import os, subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'bitmem_sim';O.mkdir(exist_ok=True)
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
Q=Path(os.environ.get('QUARTUS_ROOTDIR','C:/Users/toby0/Documents/Codex/tools/quartus25/quartus'))
s=(P/'rtl/iec_drive/iecdrv_misc.sv').read_text().replace('parameter DATAWIDTH, ADDRWIDTH,','parameter DATAWIDTH=8, ADDRWIDTH=11,').replace('parameter ADDRWIDTH)','parameter ADDRWIDTH=10)')
# Icarus 10 promotes Intel's tri0/tri1 input ports to inouts. Explicit
# net buffers isolate those pull nets from procedural source registers.
s=s.replace(') track_ram(',') track_ram(')
s=s.replace('altsyncram #(', 'wire pin_wa=wren_a_d,pin_wb=wren_b_d,pin_ca=clock_a,pin_cb=clock_b;\naltsyncram #(')
s=s.replace('.clock0(clock_a),.clock1(clock_b)', '.clock0(pin_ca),.clock1(pin_cb)').replace('.wren_a(wren_a_d)', '.wren_a(pin_wa)').replace('.wren_b(wren_b_d)', '.wren_b(pin_wb)')
(O/'misc.sv').write_text(s)
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-DPOCKET_ALTERA_RAM','-s','tb','-o',str(O/'test.vvp'),str(T/'tb_bitmem.sv'),str(O/'misc.sv'),str(Q/'eda/sim_lib/altera_mf.v')],capture_output=True,text=True)
(T/'bitmem_compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(O/'test.vvp')],capture_output=True,text=True,timeout=30)
log=r.stdout+r.stderr;(T/'bitmem.log').write_text(log);print(log);assert r.returncode==0 and 'PASS mixed-width' in log
