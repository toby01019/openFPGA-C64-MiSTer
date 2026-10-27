from pathlib import Path
import subprocess, json
P=Path(__file__).resolve().parents[1]; T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
LIB=Path('C:/Users/toby0/Documents/Codex/tools/quartus25/quartus/eda/sim_lib/altera_mf.v')
def run(pad):
    target=T/f'video-384-pad{pad}.vvp'
    cmd=[str(B/'iverilog.exe'),'-g2012','-s','tb',f'-Ptb.PAD={pad}','-o',str(target),
         str(T/'tb_video_384.sv'),str(P/'core/pocket_video.sv'),str(P/'apf/mf_ddio_bidir_12.v'),str(LIB)]
    r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
    r=subprocess.run([str(B/'vvp.exe'),str(target)],capture_output=True,text=True)
    (T/f'video-384-pad{pad}.log').write_text(r.stdout+r.stderr)
    print(r.stdout,flush=True)
    if pad==0: assert 'FATAL:' in r.stdout and 'line width 382, expected 384' in r.stdout
    else: assert r.returncode==0 and 'FATAL:' not in r.stdout and 'PASS 384x270 DDR receiver' in r.stdout
run(0) # Negative control: detects old 382-pixel transport. Not a scaler model.
run(2)
assert '.RIGHT_PAD(2)' in (P/'core/core_top.sv').read_text()
mode=json.loads((P/'dist/Cores/toby01019.C64/video.json').read_text())['video']['scaler_modes'][0]
assert (mode['width'],mode['height'])==(384,270)
print('PASS top-level padding and video.json agree')
# Also exercise the real converted MiSTer blanker, including its last
# active row and wrapped horizontal coordinates (not only ideal stimuli).
text=(T/'tb_native_video.sv').read_text()
text=text.replace('.NATIVE_PIXEL_CLOCK(1)', '.NATIVE_PIXEL_CLOCK(1),.RIGHT_PAD(2)')
text=text.replace('103140','103680').replace('row_pixels!=382','row_pixels!=384').replace('row_clocks!=382','row_clocks!=384')
text=text.replace('if(de && rgb!==expected_rgb) $fatal(1,"RGB pipeline mismatch");','')
text=text.replace('if(row_pixels>0 && (current_x', 'if(row_pixels>0 && row_pixels<382 && (current_x')
text=text.replace('previous_x=current_x;accept_gap=0;', 'if(row_pixels>=382 && current_x!=previous_x) $fatal(1,"bad padded pixel");\n   previous_x=current_x;accept_gap=0;')
text=text.replace('382x270 accepted pixels','384x270 accepted pixels (382 source + 2 border)')
(T/'tb_video_384_blanker.sv').write_text(text)
target=T/'video-384-blanker.vvp'
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(target),str(T/'tb_video_384_blanker.sv'),str(T/'converted/video_sync.v'),str(P/'core/pocket_video.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(target)],capture_output=True,text=True)
(T/'video-384-blanker.log').write_text(r.stdout+r.stderr)
print(r.stdout);assert 'PASS Pocket VIDEO' in r.stdout and 'FATAL:' not in r.stdout
