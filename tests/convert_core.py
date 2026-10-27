"""GHDL converts VHDL; original SID/CIA Verilog is linked by Icarus."""
from pathlib import Path
import re,subprocess
P=Path(__file__).resolve().parents[1]
W=P.parent
G=W/'ghdl/runtime/bin/ghdl.exe'
O=P/'tests/converted';O.mkdir(exist_ok=True)
src=(P/'rtl/fpga64_sid_iec.vhd').read_text()
entities=[]
for name in ['sid_top','mos6526']:
    m=re.search(r'component\s+'+name+r'\b(.*?)end component;',src,re.S|re.I)
    assert m,name
    entities.append('library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;\nentity '+name+' is'+m[1]+'end entity;\narchitecture blackbox of '+name+' is begin end architecture;\n')
(O/'vendor.vhd').write_text('\n'.join(entities))
bindings='\nfor sid : sid_top use entity vendor.sid_top;\nfor cia1, cia2 : mos6526 use entity vendor.mos6526;\n'
# Insert component binding declarations at architecture's begin, not a process.
where=src.index('\nbegin',src.index('architecture rtl'))
src='library vendor;\n'+src[:where]+bindings+src[where:]
(O/'core_bound.vhd').write_text(src)
def run(args,output=None):
    r=subprocess.run([str(G),*args],cwd=O,capture_output=True,text=True)
    (O/'ghdl.log').open('a').write(' '.join(args)+'\n'+r.stderr+'\n')
    assert r.returncode==0,r.stderr[-10000:]
    if output: (O/output).write_text(r.stdout)
run(['-a','--std=08','-fsynopsys','-frelaxed','--work=vendor','vendor.vhd'])
files=['t65/T65_Pack.vhd','t65/T65_MCode.vhd','t65/T65_ALU.vhd','t65/T65.vhd',
'cpu_6510.vhd','dprom.vhd','spram.vhd','video_sync.vhd','video_vicII_656x.vhd','fpga64_rgbcolor.vhd','fpga64_keyboard.vhd','fpga64_buslogic.vhd']
run(['-a','--std=08','-fsynopsys','-frelaxed',*[str(P/'rtl'/f)for f in files],'core_bound.vhd'])
run(['--synth','--std=08','-fsynopsys','-frelaxed','--vendor-library=vendor','--out=verilog','fpga64_sid_iec'], 'c64.v')
# GHDL preserves the legal VHDL identifier 'break', a SystemVerilog keyword.
v=O/'c64.v';v.write_text(re.sub(r'\bbreak\b','break_flag',v.read_text()))
run(['--synth','--std=08','-fsynopsys','-frelaxed','--out=verilog','video_sync'],'video_sync.v')
top=(P/'core/core_top.sv').read_text()
m=re.search(r'fpga64_sid_iec c64\(.*?\n\);',top,re.S)
assert m
# GHDL preserves case of top-level VHDL port names.
(O/'core_top_sim.sv').write_text(top)
print('Converted VHDL for mixed-language functional simulation')
