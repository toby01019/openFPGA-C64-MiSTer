from pathlib import Path
import subprocess,re,sys
P=Path(__file__).resolve().parents[1]; T=P/'tests'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
def run(name,sources,expect_fail=False):
 r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/(name+'.vvp')),*map(str,sources)],capture_output=True,text=True)
 assert r.returncode==0,r.stderr
 r=subprocess.run([str(B/'vvp.exe'),str(T/(name+'.vvp'))],capture_output=True,text=True)
 (T/(name+'.log')).write_text(r.stdout+r.stderr)
 print(name,r.stdout,flush=True)
 assert ('FATAL:' in r.stdout) if expect_fail else (r.returncode==0 and 'PASS' in r.stdout)
def sid_source(source,target):
 text=source.read_text().replace('always_comb','always @*').replace("signed'(",'$signed(')
 text=re.sub(r'wire(\s+\[7:0\]\s+(?:_st_out|p_t_out|ps__out|pst_out)\[)',r'reg\1',text)
 declarations=re.search(r'wire  \[7:0\] f__st_out;.*?reg   \[3:0\] state;',text,re.S).group(0)
 text=text.replace(declarations,'').replace('wire [15:0] F0;',declarations+'\nwire [15:0] F0;')
 target.write_text(text);return target
deps=[p for p in (T/'converted').glob('sid*.sv') if p.name!='sid_top.sv']
run('sid-capture-before',[T/'tb_sid_capture.sv',sid_source(T/'hardware-fix-baseline/sid_top.sv',T/'sid_before.sv'),*deps],True)
run('sid-capture-after',[T/'tb_sid_capture.sv',sid_source(P/'rtl/sid/sid_top.sv',T/'sid_after.sv'),*deps])
# Reuse the independent PAL source generator and protocol assertions at the
# real 4:1 core/pixel clock ratio, with one accepted pixel per output clock.
text=(T/'tb_pocket_video.sv').read_text()
text=text.replace('wire ohs,ovs,de,skip;', 'reg dotclk=0; always #20 dotclk=~dotclk;\nwire ohs,ovs,de,skip;')
text=text.replace('pocket_video dut(.clk(clk)', 'pocket_video #(.NATIVE_PIXEL_CLOCK(1)) dut(.clk(dotclk)')
text=text.replace('always @(posedge clk) expected_rgb', 'always @(posedge dotclk) expected_rgb')
text=text.replace('always @(negedge clk) begin','always @(negedge dotclk) begin')
text=text.replace('tick-last_hs!=2016','tick-last_hs!=504').replace('accept_gap!=4','accept_gap!=1').replace('row_clocks!=1528','row_clocks!=382')
text=text.replace('3/4 SKIP only inside DE','native pixel clock, SKIP disabled')
text=text.replace('if(skip && !de)', 'if(skip)')
(T/'tb_native_video.sv').write_text(text)
run('native-video',[T/'tb_native_video.sv',T/'converted/video_sync.v',P/'core/pocket_video.sv'])
# Exercise the actual APF DDR megafunction, sampling both halves at the
# forwarded +90 degree clock. The 24-bit reconstruction must match, including
# arbitrary colors, blanking, first/last pixels and line/frame pulses.
ddr='''
wire [11:0] pins; wire [11:0] control; wire [11:0] forwarded;
reg dot90=0; always begin #10; dot90=~dot90; #30; dot90=~dot90; end
// dotclk rises at 20,60,...; use a delayed copy, with quarter-period shift.
wire delayed_dot; assign #10 delayed_dot=dotclk;
mf_ddio_bidir_12 color_ddr(.oe(1'b1),.datain_h(rgb[23:12]),.datain_l(rgb[11:0]),.outclock(dotclk),.padio(pins));
mf_ddio_bidir_12 control_ddr(.oe(1'b1),.datain_h({8'b0,ovs,ohs,de,skip}),.datain_l({8'b0,ovs,ohs,de,skip}),.outclock(dotclk),.padio(control));
mf_ddio_bidir_12 clock_ddr(.oe(1'b1),.datain_h(12'b1),.datain_l(12'b0),.outclock(delayed_dot),.padio(forwarded));
reg [23:0] expected_wire;reg [3:0] expected_control;
always @(posedge dotclk) begin expected_wire<=rgb;expected_control<={ovs,ohs,de,skip};end
always @(posedge forwarded[0]) if(tick>10) begin
 if(pins!==expected_wire[23:12] || control[3:0]!==expected_control) $fatal(1,"DDR upper/control mismatch");
end
always @(negedge forwarded[0]) if(tick>10) begin
 if(pins!==expected_wire[11:0] || control[3:0]!==expected_control) $fatal(1,"DDR lower/control mismatch");
end
'''
text=text.replace('endmodule',ddr+'\nendmodule')
(T/'tb_native_ddr.sv').write_text(text)
run('native-ddr',[T/'tb_native_ddr.sv',T/'converted/video_sync.v',P/'core/pocket_video.sv',P/'apf/mf_ddio_bidir_12.v',Path('C:/Users/toby0/Documents/Codex/tools/quartus25/quartus/eda/sim_lib/altera_mf.v')])

