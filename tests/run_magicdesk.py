from pathlib import Path
import struct,subprocess,sys
from cartridge_sim import cartridge_sources
P=Path(__file__).resolve().parents[1];T=P/'tests';O=T/'magicdesk_sim';O.mkdir(exist_ok=True)
B=Path('C:/Users/toby0/Documents/Codex/Projekte/IMSAI8080/08_Werkzeuge/Icarus/bin')
t=(T/'tb_easyflash.sv').read_text().split('initial begin',1)[0]
t=t.replace('pocket_cartridge #','defparam dut.easyflash_port.ef.INIT_WORDS=1024;\npocket_cartridge #').replace('cart_psram_model physical',"cart_psram_model #(.INITIAL_WORD(16'hffff)) physical")
t+='''
initial begin
 if(!$value$plusargs("FILE=%s",path)||!$value$plusargs("SIZE=%d",size)||!$value$plusargs("EXPECTED=%s",expect_path))$fatal;
 $readmemh(path,image,0,size-1);$readmemh(expect_path,expected);
 repeat(5)tick;reset=0;repeat(4)tick;start=1;tick;start=0;
 for(i=0;i<size;i=i+1)begin while(!ready && !error)tick;if(error)$fatal(1,"MagicDesk rejected code=%d byte=%d",error_code,i);byte_data=image[i];valid=1;tick;valid=0;tick;end
 finish=1;tick;finish=0;while(busy)tick;if(error||!attached)$fatal(1,"No attach");
 for(i=0;i<524288;i=i+1)if(physical.memory[i]!=={expected[i*2+1],expected[i*2]})$fatal(1,"Payload mismatch %d",i);
 c64reset=0;repeat(8)tick;if({exrom,game}!==2'b01)$fatal(1,"Boot lines");
 for(b=0;b<64;b=b+1)begin
  reg_write(16'hde00,b);
  for(k=0;k<4;k=k+1)begin offset=k==0?0:k==1?1:k==2?4095:8191;cart_read(0,0,16'h8000+offset,expected[b*8192+offset]);end
 end
 reg_write(16'hde00,8'hbf);if({exrom,game}!==2'b11)$fatal(1,"Disable");
 reg_write(16'hde00,63);if({exrom,game}!==2'b01)$fatal(1,"Re-enable");
 cart_read(0,0,16'h8000,expected[63*8192]);
 // MagicDesk ROM is read-only, including flash-command-looking writes.
 unlock(0,8'ha0);flash_write(0,16'h8100,8'h00);cart_read(0,0,16'h8100,expected[63*8192+256]);
 addr=16'hdf00;iof=1;repeat(3)tick;if(io_rd)$fatal(1,"Unexpected IO2 RAM");idle_bus;
 c64reset=1;repeat(4)tick;c64reset=0;repeat(8)tick;
 if({exrom,game}!==2'b01 || dut.easyflash_port.ef.bank!=0)$fatal(1,"Reset");
 cart_read(0,0,16'h8000,expected[0]);
 reset=1;tick;reset=0;repeat(12)tick;if(attached||{exrom,game}!==2'b11)$fatal(1,"Eject");
 $display("PASS MagicDesk 512KiB: exact payload, all 64 banks, disable/re-enable, ROM write protection, reset/eject");$finish;
end
initial begin #2000000000;$fatal(1,"timeout");end
endmodule
'''
(O/'tb.sv').write_text(t)
r=subprocess.run([str(B/'iverilog.exe'),'-g2012','-s','tb','-o',str(O/'test.vvp'),str(O/'tb.sv'),str(T/'cart_psram_model.sv'),str(P/'core/psram.sv'),*map(str,cartridge_sources())],capture_output=True,text=True);assert r.returncode==0,r.stderr
for arg in sys.argv[1:]:
 raw=Path(arg).read_bytes();expected=bytearray(b'\xff'*1048576);pos=64
 while pos<len(raw):
  packet,typ,bank,addr,n=struct.unpack('>IHHHH',raw[pos+4:pos+16]);assert addr==0x8000 and n==8192;expected[bank*8192:(bank+1)*8192]=raw[pos+16:pos+packet];pos+=packet
 for name,data in [('input.hex',raw),('expected.hex',expected)]: (O/name).write_text('\n'.join(f'{v:02x}' for v in data))
 with (O/(Path(arg).stem+'.log')).open('w') as f:r=subprocess.run([str(B/'vvp.exe'),str(O/'test.vvp'),f'+FILE={O/"input.hex"}',f'+SIZE={len(raw)}',f'+EXPECTED={O/"expected.hex"}'],stdout=f,stderr=subprocess.STDOUT,timeout=900)
 log=(O/(Path(arg).stem+'.log')).read_text();print(Path(arg).name,log,flush=True);assert r.returncode==0 and 'PASS MagicDesk' in log,log
