from pathlib import Path
import os, subprocess
P = Path(__file__).resolve().parents[1]
T = P / 'tests'
B = Path(os.environ.get('ICARUS_BIN', 'C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
cmd = [str(B/'iverilog.exe'), '-g2012', '-s', 'tb', '-o', str(T/'review_keys.vvp'),
       str(T/'review_keys.sv'), str(P/'core/loader.sv'), str(P/'core/keys.sv')]
r = subprocess.run(cmd, capture_output=True, text=True)
assert r.returncode == 0, r.stderr
r = subprocess.run([str(B/'vvp.exe'), str(T/'review_keys.vvp')], capture_output=True, text=True)
log = r.stdout + r.stderr
(T/'review_keys.log').write_text(log)
print(log)
assert r.returncode == 0 and 'PASS loader RUN/Return macro' in log, log
