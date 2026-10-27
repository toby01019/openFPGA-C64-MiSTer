from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
# Icarus requires an explicit tri-state driver for the vendor inout-reg idiom
# and empty trailing positional ports. Receiver/FSM logic is unchanged.
vendor=(P/'apf/io_pad_controller.v').read_text(encoding='utf-8')
vendor=vendor.replace('inout   reg             pad_1wire,','inout wire pad_1wire,')
vendor=vendor.replace('    wire        reset_n_s;','    reg pad_drive;\n    assign pad_1wire=pad_drive;\n    wire        reset_n_s;')
vendor=vendor.replace('pad_1wire <=','pad_drive <=')
vendor=vendor.replace('s00(reset_n, reset_n_s, clk);','s00(reset_n, reset_n_s, clk,,);')
(T/'dock_pad_sim.v').write_text(vendor,encoding='utf-8')
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'dock_pad.vvp'),str(T/'tb_dock_pad.sv'),str(T/'dock_pad_sim.v'),str(P/'apf/common.v')],capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'dock_pad.vvp')],capture_output=True,text=True,timeout=45)
log=r.stdout+r.stderr;(T/'dock-pad.log').write_text(log);print(log)
assert r.returncode==0 and 'PASS real PAD' in log
