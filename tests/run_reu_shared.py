"""Real registered-start REU client through the shared PCM/REU RAM arbiter."""
from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'reu_sim'
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
s=(T/'tb_reu_psram.sv').read_text()
s=s.replace('pocket_psram memory(.clk(clk),.reset(reset),.start(rstart),.write(rwe),.addr(ra),.wdata(rdout),.ready(rready),.done(rack),.rdata(rdin),', '''pocket_sample_memory memory(.clk(clk),.reset(reset),.c64_reset(reset),.enabled(1'b0),.paused(1'b0),
 .command(26'b0),.command_valid(1'b0),.command_ready(),
 .reu_start(rstart),.reu_write(rwe),.reu_addr(ra),.reu_out(rdout),.reu_ready(rready),.reu_done(rack),.reu_in(rdin),
 .io_select(1'b0),.io_write(1'b0),.io_addr(8'b0),.io_data(8'b0),.io_claim(),.io_q(),
 .sid_left(18'sd0),.sid_right(18'sd0),.left(),.right(),.bank_valid(),.bank_size(),.underrun(),''')
s=s.replace('PASS REU with actual Pocket PSRAM controller','PASS registered-start REU through shared PCM arbiter with actual Pocket PSRAM controller')
s=s.replace(".enabled(1'b0)",".enabled(1'b1)").replace(".io_select(1'b0),.io_write(1'b0),.io_addr(8'b0),.io_data(8'b0),.io_claim()", ".io_select(cs),.io_write(cwe),.io_addr(ca[7:0]),.io_data(cd),.io_claim(pcm_claim)")
s=s.replace('pocket_reu dut(', 'wire pcm_claim;\npocket_reu dut(').replace('.cpu_cs(cs)', '.cpu_cs(cs && !pcm_claim)')
s=s.replace('integer i;reg[7:0]status;', r"""task audio_poke(input[15:0]ad,input[7:0]v);begin
 @(negedge clk);ca=ad;cd=v;cwe=1;cs=1;
 @(negedge clk);cs=0;cwe=0;@(negedge clk);
end endtask
integer i,ch;reg[15:0]voice_base;reg[7:0]status;""")
s=s.replace('repeat(5)@(negedge clk);reset=0;', r"""repeat(5)@(negedge clk);reset=0;
 for(i=0;i<32;i=i+1)mem[i]=16'h1234+i;
 force memory.bank_valid=1;force memory.bank_size=64;
 for(ch=0;ch<2;ch=ch+1)begin
  voice_base=ch ? 16'hdf40:16'hdf20;
  audio_poke(voice_base+1,48);audio_poke(voice_base+2,8);audio_poke(voice_base+4,1);
  audio_poke(voice_base+5,0);audio_poke(voice_base+6,0);audio_poke(voice_base+7,0);
  audio_poke(voice_base+9,0);audio_poke(voice_base+10,0);audio_poke(voice_base+11,64);
  audio_poke(voice_base+14,0);audio_poke(voice_base+15,142);audio_poke(voice_base,8'h11);
 end""")
s=s.replace('$display("PASS registered-start', 'wait(memory.pcm.active==0);if(memory.underrun)$fatal(1,"registered REU starved PCM");\n $display("PASS registered-start')
s=s.replace('roundtrip, swap, verify, shadow lastword and 16M wrap', 'roundtrip, swap, verify, shadow lastword and 16M wrap with both PCM voices active, no underrun')
(T/'tb_reu_shared.sv').write_text(s)
sources=[T/'tb_reu_shared.sv',*[P/'core'/n for n in ['pocket_reu.v','pocket_sample_memory.sv','pocket_pcm.sv','pocket_ram_arbiter.sv','pocket_psram.sv','psram.sv']]]
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'shared.vvp'),*map(str,sources)],capture_output=True,text=True)
assert r.returncode==0,r.stderr
r=subprocess.run([str(B/'vvp.exe'),str(O/'shared.vvp')],capture_output=True,text=True,timeout=120)
(T/'reu-shared.log').write_text(r.stdout+r.stderr);print((r.stdout+r.stderr)[-1300:]);assert r.returncode==0 and 'PASS registered-start'in r.stdout
