"""Review APF menu metadata and simulate the actual register/mux/CDC source."""
from pathlib import Path
import ast, os, re, subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests'
source=(P/'core/core_top.sv').read_text()
declaration=re.search(r'reg \[1:0\] keyboard_transparency=0;',source)[0]
write=re.search(r"always @\(posedge clk_74a\)begin\s*if\(bridge_wr && bridge_addr==32'ha0000004\).*?\n end",source,re.S)[0]
toggle_decl=re.search(r'\(\* async_reg="true" \*\) reg transparency_toggle_meta=0,transparency_toggle_sync=0;',source)[0]
toggle_seen=re.search(r'reg transparency_toggle_seen=0;',source)[0]
toggle_cdc=re.search(r'always @\(posedge clk_74a\)begin\s*transparency_toggle_meta<=.*?\n end',source,re.S)[0]
read_line=re.search(r"else if\(bridge_addr==32'ha0000004\) bridge_rd_data=.*?;",source)[0]
read='always @* begin '+read_line.replace('else if','if',1)+" else bridge_rd_data=32'b0; end"
cdc_decl=re.search(r'\(\* async_reg="true" \*\) reg \[1:0\] transparency_meta=0,transparency_sync=0;',source)[0]
cdc=re.search(r'transparency_meta<=keyboard_transparency;transparency_sync<=transparency_meta;',source)[0]
assert '.transparency(transparency_sync)' in source
menu=None
for node in ast.walk(ast.parse((P/'package.py').read_text())):
 if isinstance(node,ast.Call) and isinstance(node.func,ast.Name) and node.func.id=='save':
  if isinstance(node.args[0],ast.BinOp) and isinstance(node.args[0].right,ast.Constant) and node.args[0].right.value=='interact.json':
   menu=ast.literal_eval(node.args[1])['interact']
assert menu and menu['magic']=='APF_VER_1'
entries=menu['variables'];assert len({v['id'] for v in entries})==len(entries)
setting=next(v for v in entries if int(v['address'],0)==0xa0000004)
assert setting['type']=='list' and setting['enabled'] and not setting['writeonly'] and setting['persist']
assert setting['defaultval']==0 and setting['name']=='Transparenz Tastatur' and len(setting['name'])<=23
assert setting['options']==[{'value':0,'name':'Deckend'},{'value':1,'name':'25%'},{'value':2,'name':'50%'}]
tb='''`timescale 1ns/1ps
module tb;
reg clk_74a=0,clk_core=0;
always #6.734 clk_74a=~clk_74a;
always #15.859 clk_core=~clk_core;
reg bridge_wr=0;
reg keyboard_transparency_toggle=0,reset_n=1;
reg [31:0] bridge_addr=0,bridge_wr_data=0;
reg [31:0] bridge_rd_data;
wire [31:0] table_bridge_data=32'h1357,cmd_rdata=32'h2468;
wire [5:0] load_state=0;wire [7:0] error_code=0;
'''+declaration+'\n'+toggle_decl+'\n'+toggle_seen+'\n'+toggle_cdc+'\n'+write+'\n'+read+'\n'+cdc_decl+'\nalways @(posedge clk_core) begin '+cdc+' end\n'+'''
task write_value(input [31:0] address,input [31:0] value);
begin
 @(negedge clk_74a);bridge_addr=address;bridge_wr_data=value;bridge_wr=1;
 @(negedge clk_74a);bridge_wr=0;
end
endtask
task check_value(input [1:0] expected);
begin
 repeat(4) @(negedge clk_core);
 bridge_addr=32'ha0000004;#1;
 if(bridge_rd_data!=={30'b0,expected} || transparency_sync!==expected)
  $fatal(1,"register/CDC mismatch expected=%0d read=%h CDC=%h",expected,bridge_rd_data,transparency_sync);
end
endtask
initial begin
 check_value(0);
 write_value(32'ha0000004,1);check_value(1);
 write_value(32'ha0000004,2);check_value(2);
 write_value(32'ha0000000,0);check_value(2);
 write_value(32'ha0000008,0);check_value(2);
 write_value(32'ha0000004,3);check_value(0);
 write_value(32'ha0000004,0);check_value(0);
 // UI toggles cross to host and mode crosses back independently.
 @(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;check_value(1);
 @(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;check_value(2);
 @(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;check_value(0);
 // Simultaneous menu write takes priority and consumes the UI event once.
 @(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;
 wait(transparency_toggle_sync!=transparency_toggle_seen);
 write_value(32'ha0000004,2);check_value(2);
 reset_n=0;@(negedge clk_core);keyboard_transparency_toggle=~keyboard_transparency_toggle;
 repeat(5)@(negedge clk_core);reset_n=1;check_value(2);
 $display("PASS transparency: UI toggle roundtrip, menu priority, reset event suppression, APF menu values, exact register decode/readback, invalid mode clamp, asynchronous two-stage CDC");
 $finish;
end
endmodule
'''
(T/'review_transparency.sv').write_text(tb)
B=Path(os.environ.get('ICARUS_BIN','C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin'))
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(T/'review_transparency.vvp'),str(T/'review_transparency.sv')],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(T/'review_transparency.vvp')],capture_output=True,text=True)
log=r.stdout+r.stderr;(T/'review_transparency.log').write_text(log);print(log)
assert r.returncode==0 and 'PASS transparency' in log,log
