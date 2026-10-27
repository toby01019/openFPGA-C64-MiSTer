from pathlib import Path
import subprocess,sys
P=Path(__file__).resolve().parents[1];T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
text=(T/'review_vkb_video.sv').read_text()
phase=int(sys.argv[1]) if len(sys.argv)>1 else 0
pad=int(sys.argv[2]) if len(sys.argv)>2 else 0
pipeline=int(sys.argv[3]) if len(sys.argv)>3 else 0
assert pad in (0,2)
assert pipeline in (0,1)
text=text.replace('wire [23:0] mixed,rgb;', f'reg dotclk=0; initial begin #{phase}; forever #20 dotclk=~dotclk; end\nwire [23:0] mixed,rgb;')
text=text.replace('pocket_video transport(.clk(clk)', f'pocket_video #(.NATIVE_PIXEL_CLOCK(1),.RIGHT_PAD({pad})) transport(.clk(dotclk)')
# Move only the output monitor to the pixel clock. The renderer and the
# staging registers below must stay on the core clock, as in core_top.sv.
text=text.replace('always @(posedge clk) begin','always @(posedge dotclk) begin')
text=text.replace('pocket_video #', '''reg [23:0] staged_rgb=0;reg staged_hs=0,staged_vs=0,staged_active=0;
always @(posedge clk) begin staged_rgb<=mixed;staged_hs<=hsync;staged_vs<=vsync;staged_active<=active;end
pocket_video #''')
text=text.replace('.hsync(hsync),.vsync(vsync)', '.hsync(staged_hs),.vsync(staged_vs)')
text=text.replace('.hblank(!active),.vblank(1\'b0),.rgb(mixed)', '.hblank(!staged_active),.vblank(1\'b0),.rgb(staged_rgb)')
if pipeline:
    text=text.replace('pocket_keyboard_video ui(', 'pocket_keyboard_video #(.PIPELINED(1)) ui(')
    text=text.replace('always @(posedge clk) begin staged_rgb<=mixed;staged_hs<=hsync;staged_vs<=vsync;staged_active<=active;end', '''reg [2:0] ui_control[0:3];integer k;
initial for(k=0;k<4;k=k+1)ui_control[k]=0;
always @(posedge clk)begin
 ui_control[0]<={hsync,vsync,active};
 for(k=1;k<4;k=k+1)ui_control[k]<=ui_control[k-1];
 staged_rgb<=mixed;{staged_hs,staged_vs,staged_active}<=ui_control[3];
end''')
    text=text.replace('reg capture=0,old_de=0;', 'integer monitor_ticks=0;reg capture=0,old_de=0;')
    text=text.replace('if(!visible && mixed!==background)', 'monitor_ticks=monitor_ticks+1;\n if(monitor_ticks>8 && !visible && mixed!==background)')
text=text.replace('review_vkb_pixels.hex','native_keyboard_pixels.hex').replace('4x transport sampling','native pixel sampling')
text=text.replace('line_accepted!=382',f'line_accepted!={382+pad}').replace('accepted!=382*270',f'accepted!={382+pad}*270')
(T/'tb_native_keyboard.sv').write_text(text)
cmd=[str(B/'iverilog.exe'),'-g2012','-I',str(P/'core'),'-s','tb','-o',str(T/'native-keyboard.vvp'),str(T/'tb_native_keyboard.sv'),str(P/'core/pocket_keyboard_video.sv'),str(P/'core/pocket_video.sv')]
r=subprocess.run(cmd,capture_output=True,text=True);assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'native-keyboard.vvp')],cwd=T,capture_output=True,text=True)
(T/'native-keyboard.log').write_text(r.stdout+r.stderr)
print(r.stdout+r.stderr);assert 'PASS keyboard video' in r.stdout
pixels=(T/'native_keyboard_pixels.hex').read_text().splitlines()
assert len(pixels)==(382+pad)*270
# Compare the rendered key geometry and glyph pixels to the previous verified
# renderer, independently of the output clock. Neither rendering is a photo.
old=(T/'review_vkb_pixels.hex').read_text().splitlines()
if pad:
    for y in range(270):
        row=pixels[y*384:(y+1)*384]
        assert row[:382]==old[y*382:(y+1)*382],f'Changed source pixels row {y}'
        assert row[382:]==[row[381]]*2,f'Bad right padding row {y}'
else:
    assert pixels==old,'Native transport altered keyboard pixels'
print('PASS native keyboard: all 103140 pixels match the verified renderer')
with (T/'native-keyboard.log').open('a') as f:f.write('PASS native keyboard: all 103140 pixels match the verified renderer\n')
suffix='-pipeline' if pipeline else ''
(T/f'native-keyboard-pad{pad}-phase{phase}{suffix}.log').write_text(f'Pixel clock phase: {phase} ns; padding: {pad}; pipeline: {pipeline}\n'+(T/'native-keyboard.log').read_text())
