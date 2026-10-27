"""Test exact production virtual-matrix merge plus the real MiSTer keyboard."""
from pathlib import Path
import os, re, subprocess
P = Path(__file__).resolve().parents[1]
T = P / 'tests'
O = T / 'review_matrix_build'
O.mkdir(exist_ok=True)
G = Path(os.environ.get('GHDL', str(P.parent/'ghdl/runtime/bin/ghdl.exe')))
source = (P/'rtl/fpga64_sid_iec.vhd').read_text()
merge = source.split('-- Pocket virtual keyboard merge begin', 1)[1].split('-- Pocket virtual keyboard merge end', 1)[0]
keyboard = re.search(r'Keyboard: entity work.fpga64_keyboard\s*port map \(.*?\n\);', source, re.S)[0]
wrapper = '''library ieee;
use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity review_matrix is port(
 clk32,kbd_reset: in std_logic;
 virtual_keys: in std_logic_vector(63 downto 0);
 virtual_restore: in std_logic;
 ps2_key: in std_logic_vector(10 downto 0);
 joyA,joyB: in std_logic_vector(6 downto 0);
 shift_mod: in std_logic_vector(1 downto 0);
 cia1_pao,cia1_pbo: in unsigned(7 downto 0);
 cia1_pai,cia1_pbi: out unsigned(7 downto 0);
 freeze_key: out std_logic);
end;
architecture rtl of review_matrix is
signal keyboard_pa,keyboard_pb: unsigned(7 downto 0);
signal keyboard_restore,mod_key,tape_play,tape_rew,tape_stop,tape_ff,tape_reset_counter: std_logic;
begin
'''+keyboard+'\n'+merge+'\nend architecture;\n'
(O/'review_matrix.vhd').write_text(wrapper)
tb = '''library ieee;
use ieee.std_logic_1164.all; use ieee.numeric_std.all;
use std.env.all;
entity tb is end;
architecture sim of tb is
signal clk: std_logic := '0';
signal reset: std_logic := '1';
signal vk: std_logic_vector(63 downto 0) := (others=>'0');
signal vr: std_logic := '0';
signal ps2: std_logic_vector(10 downto 0) := (others=>'0');
signal ja,jb: std_logic_vector(6 downto 0) := (others=>'0');
signal pa,pb,ai,bi: unsigned(7 downto 0) := (others=>'1');
signal restore: std_logic;
begin
clk <= not clk after 5 ns;
dut: entity work.review_matrix port map(clk,reset,vk,vr,ps2,ja,jb,"11",pa,pb,ai,bi,restore);
process
 variable single_key: std_logic_vector(63 downto 0);
 procedure key(code: natural; down: std_logic) is
 begin
   ps2 <= (not ps2(10)) & down & '0' & std_logic_vector(to_unsigned(code,8));
   wait for 100 ns;
 end procedure;
begin
 wait for 100 ns;reset<='0';wait for 100 ns;
 for row in 0 to 7 loop
  for col in 0 to 7 loop
   single_key := (others=>'0');single_key(row*8+col):='1';vk<=single_key;
   pa <= not shift_left(to_unsigned(1,8),row);pb<=x"ff";wait for 100 ns;
   assert bi=(not shift_left(to_unsigned(1,8),col)) report "forward matrix position" severity failure;
   pa<=x"ff";pb<=not shift_left(to_unsigned(1,8),col);wait for 100 ns;
   assert ai=(not shift_left(to_unsigned(1,8),row)) report "reverse matrix position" severity failure;
   pa<=not shift_left(to_unsigned(1,8),(row+1) mod 8);pb<=x"ff";wait for 100 ns;
   assert bi=x"ff" report "unselected row affected matrix" severity failure;
  end loop;
 end loop;
 -- Two virtual keys on one row: A plus left Shift.
 vk<=(15=>'1',10=>'1',others=>'0');pa<=x"fd";pb<=x"ff";wait for 100 ns;
 assert bi=x"7b" report "virtual multi-key chord" severity failure;
 -- Combine PS/2 Return, virtual Delete, and joystick port 1 fire.
 vk<=(0=>'1',others=>'0');pa<=x"fe";pb<=x"ff";ja<="0010000";
 key(16#5a#,'1');
 assert bi=x"ec" report "PS2/virtual/joystick forward merge" severity failure;
 -- Reverse scan: PS/2 Return, virtual W, and joystick port 2 fire.
 ja<=(others=>'0');jb<="0010000";vk<=(9=>'1',others=>'0');pa<=x"ff";pb<=x"fd";wait for 100 ns;
 assert ai=x"ec" report "PS2/virtual/joystick reverse merge" severity failure;
 key(16#5a#,'0');ja<=(others=>'0');jb<=(others=>'0');vk<=(others=>'0');pa<=x"ff";pb<=x"ff";
 key(16#78#,'1');assert restore='1' report "PS2 Restore missing" severity failure;
 vr<='1';key(16#78#,'0');assert restore='1' report "virtual Restore missing" severity failure;
 vr<='0';wait for 100 ns;assert restore='0' report "Restore release missing" severity failure;
 -- Reset suppresses virtual input and clears held PS/2 keys.
 key(16#5a#,'1');vk<=(0=>'1',others=>'0');vr<='1';pa<=x"fe";pb<=x"ff";
 reset<='1';wait for 100 ns;
 assert bi=x"ff" and restore='0' report "reset did not clear/suppress keyboard" severity failure;
 reset<='0';wait for 100 ns;
 assert bi=x"fe" and restore='1' report "held virtual level not restored after reset" severity failure;
 vk<=(others=>'0');vr<='0';wait for 100 ns;
 assert bi=x"ff" and restore='0' report "released key remained stuck" severity failure;
 report "PASS 64 matrix positions in both directions, deselection, chords, PS2/joystick coexistence, Restore and reset";
 stop;wait;
end process;
end;
'''
(O/'tb.vhd').write_text(tb)
log=''
core_files=['t65/T65_Pack.vhd','t65/T65_MCode.vhd','t65/T65_ALU.vhd','t65/T65.vhd',
 'cpu_6510.vhd','dprom.vhd','spram.vhd','video_sync.vhd','video_vicII_656x.vhd',
 'fpga64_rgbcolor.vhd','fpga64_keyboard.vhd','fpga64_buslogic.vhd','fpga64_sid_iec.vhd']
for args in [
 ['-a','--std=08','-fsynopsys','-frelaxed',*[str(P/'rtl'/f) for f in core_files]],
 ['-a','--std=08','-fsynopsys',str(P/'rtl/fpga64_keyboard.vhd'),'review_matrix.vhd','tb.vhd'],
 ['-e','--std=08','-fsynopsys','tb'],
 ['-r','--std=08','-fsynopsys','tb','--assert-level=error','--stop-time=100us']]:
 r=subprocess.run([str(G),*args],cwd=O,capture_output=True,text=True)
 log+=r.stdout+r.stderr
 (T/'review_matrix.log').write_text(log)
 assert r.returncode==0,log
print(log)
assert 'PASS 64 matrix positions' in log,log
