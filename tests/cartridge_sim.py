"""Actual MiSTer cartridge sources with syntax-only Icarus 10 compatibility."""
from pathlib import Path
P=Path(__file__).resolve().parents[1]

def cartridge_sources():
 out=P/'tests'/'cartridge_converted';out.mkdir(exist_ok=True)
 mapper=(P/'rtl/cartridge.v').read_text().replace('always begin','always @* begin')
 flash=(P/'core/am29f040.sv').read_text().replace('always_comb','always @*').replace('always_ff','always')
 # Older Icarus creates an implicit net for a referenced-before-declared signal.
 flash=flash.replace('logic mem_rom_sel;','').replace('logic  [7:0] dq0_out;','logic mem_rom_sel;\nlogic [7:0] dq0_out;')
 for name,text in [('cartridge.v',mapper),('am29f040.sv',flash)]:
  target=out/name
  if not target.exists() or target.read_text()!=text:target.write_text(text)
 return [P/'core/pocket_crt.sv',P/'core/pocket_cartridge.sv',P/'core/pocket_easyflash.sv',out/'cartridge.v',out/'am29f040.sv']
