from pathlib import Path
import subprocess,re
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
text=(P/'rtl/sid/sid_top.sv').read_text().replace('always_comb','always @*').replace("signed'(",'$signed(')
text=re.sub(r'wire(\s+\[7:0\]\s+(?:_st_out|p_t_out|ps__out|pst_out)\[)',r'reg\1',text)
declarations=re.search(r'wire  \[7:0\] f__st_out;.*?reg   \[3:0\] state;',text,re.S).group(0)
text=text.replace(declarations,'').replace('wire [15:0] F0;',declarations+'\nwire [15:0] F0;')
(T/'sid_i2s_source.sv').write_text(text)
sources=[T/'tb_sid_i2s.sv',T/'sid_i2s_source.sv',P/'core/audio.sv']
sources += [p for p in (T/'converted').glob('sid*.sv') if p.name!='sid_top.sv']
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'sid-i2s.vvp'),*map(str,sources)],capture_output=True,text=True)
assert r.returncode==0,r.stderr
logs=[];signatures=[]
for model in [0,1]:
 r=subprocess.run([str(B/'vvp.exe'),str(T/'sid-i2s.vvp'),f'+MODEL={model}'],cwd=T,capture_output=True,text=True)
 log=r.stdout+r.stderr;logs.append(log);print(log)
 assert r.returncode==0 and 'PASS real SID-to-I2S' in log and 'FATAL' not in log,log
 signatures.append(re.search(r'SIGNATURE ([0-9a-f]+)',log)[1])
assert signatures[0]!=signatures[1],signatures
(T/'sid-i2s.log').write_text(''.join(logs)+'PASS both SID models produce changing, distinct real waveforms through I2S\n')
