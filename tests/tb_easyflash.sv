`timescale 1ns/1ps
module tb;
reg clk=0;always #15.859 clk=~clk;
reg reset=1,c64reset=1,start=0,valid=0,finish=0;
reg [31:0] size;reg [7:0] byte_data=0;
wire ready,busy,attached,error;wire [3:0]error_code;
reg roml=0,romh=0,umax=0,ioe=0,iof=0,wr=0,ce=0;
reg [15:0]addr=0;reg [7:0]data=0;
wire exrom,game,io_rd;wire [7:0]q,io_q;
wire [21:16]a;tri[15:0]dq;wire ramclk,adv,cre,ce0,ce1,oe,we,ub,lb;
pocket_cartridge #(.ROM_BYTES(73728),.OCEAN_FF_TAIL(1),.EASYFLASH(1)) dut(
 .clk(clk),.reset(reset),.c64_reset(c64reset),.load_start(start),.file_size(size),
 .byte_valid(valid),.byte_data(byte_data),.byte_ready(ready),.finish(finish),.busy(busy),.attached(attached),.error(error),.error_code(error_code),
 .romL(roml),.romH(romh),.UMAXromH(umax),.IOE(ioe),.IOF(iof),.mem_write(wr),.mem_ce(ce),.addr_in(addr),.data_in(data),.main_ram_data(8'h69),
 .freeze_key(1'b0),.mod_key(1'b0),.nmi_ack(1'b0),.exrom(exrom),.game(game),.IO_rom(),.IO_rd(io_rd),.IO_data(io_q),.data_out(q),
 .nmi(),.mem_addr(),.mem_ce_out(),.mem_write_out(),.mem_data_out(),
 .cram_a(a),.cram_dq(dq),.cram_wait(1'b1),.cram_clk(ramclk),.cram_adv_n(adv),.cram_cre(cre),.cram_ce0_n(ce0),.cram_ce1_n(ce1),
 .cram_oe_n(oe),.cram_we_n(we),.cram_ub_n(ub),.cram_lb_n(lb));
cart_psram_model physical(.a(a),.dq(dq),.clk(ramclk),.adv(adv),.cre(cre),.ce0(ce0),.ce1(ce1),.oe(oe),.we(we),.ub(ub),.lb(lb));
reg[7:0]image[0:1100000],expected[0:1048575];reg[4095:0]path,expect_path;
integer i,j,b,k,offset,checks=0;
task tick;begin @(negedge clk);end endtask
task idle_bus;begin roml=0;romh=0;umax=0;ioe=0;iof=0;wr=0;ce=0;end endtask
task reg_write(input[15:0]ad,input[7:0]v);
begin idle_bus;addr=ad;data=v;wr=1;ioe=1;repeat(3)tick;idle_bus;repeat(3)tick;end endtask
task flash_write(input bit high,input[15:0]ad,input[7:0]v);
begin idle_bus;addr=ad;data=v;wr=1;roml=!high;romh=high;repeat(12)tick;ce=1;tick;ce=0;repeat(3)tick;idle_bus;repeat(16)tick;end endtask
task cart_read(input bit high,input bit vic,input[15:0]ad,input[7:0]v);
begin idle_bus;addr=ad;roml=!high;romh=high&&!vic;umax=vic;
 repeat(12)tick;ce=1;tick;ce=0;repeat(2)tick;
 if(q!==v)$fatal(1,"ROM read bank=%d high=%b vic=%b addr=%h expected=%h got=%h",dut.easyflash_port.ef.bank,high,vic,ad,v,q);
 checks=checks+1;tick;idle_bus;
end endtask
task unlock(input bit high,input[7:0]cmd);
begin flash_write(high,16'h8555,8'haa);flash_write(high,16'h82aa,8'h55);flash_write(high,16'h8555,cmd);end endtask
initial begin
 if(!$value$plusargs("FILE=%s",path) || !$value$plusargs("SIZE=%d",size) || !$value$plusargs("EXPECTED=%s",expect_path))$fatal;
 $readmemh(path,image,0,size-1);$readmemh(expect_path,expected);
 repeat(5)tick;reset=0;repeat(4)tick;start=1;tick;start=0;
 $display("EasyFlash loading %0d bytes",size);$fflush();
 for(i=0;i<size;i=i+1)begin while(!ready && !error)tick;if(error)$fatal(1,"Caren rejected error=%d byte=%d",error_code,i);
  byte_data=image[i];valid=1;tick;valid=0;tick;end
 finish=1;tick;finish=0;
 while(busy)tick;if(error || !attached)$fatal(1,"Caren did not attach");
 for(i=0;i<524288;i=i+1)if(physical.memory[i]!=={expected[i*2+1],expected[i*2]})$fatal(1,"Caren sparse payload/erased bank word %h",i);
 $display("PASS complete CRT payload and all erased gaps: 1 MiB physical PSRAM identical");$fflush();
 c64reset=0;repeat(8)tick;if({exrom,game}!==2'b10)$fatal(1,"EasyFlash Ultimax boot mode");
 for(b=0;b<64;b=b+1)begin
  reg_write(16'hde00,b);
  for(k=0;k<4;k=k+1)begin
   offset=k==0 ? 0:k==1 ? 1:k==2 ? 4095:8191;
   cart_read(0,0,16'h8000+offset,expected[b*8192+offset]);
   cart_read(1,0,16'ha000+offset,expected[524288+b*8192+offset]);
   cart_read(1,1,16'he000+offset,expected[524288+b*8192+offset]);
  end
 end
 for(k=4;k<8;k=k+1)begin reg_write(16'hde02,k);if({exrom,game}!=={!k[1],!k[0]&&k[2]})$fatal(1,"EasyFlash mode register");end
 // IO2 RAM is present in every mode, including cartridge-off mode.
 reg_write(16'hde02,4);
 for(i=0;i<256;i=i+1)begin addr=16'hdf00+i;data=i^8'h5a;wr=1;iof=1;repeat(3)tick;idle_bus;tick;end
 for(i=0;i<256;i=i+1)begin addr=16'hdf00+i;iof=1;repeat(3)tick;if(!io_rd || io_q!==(i[7:0]^8'h5a))$fatal(1,"EasyFlash IO2 RAM");idle_bus;tick;end
 reg_write(16'hde02,7);reg_write(16'hde00,0);
 for(j=0;j<2;j=j+1)begin
  unlock(j,8'h90);cart_read(j,0,16'h8000,8'h01);cart_read(j,0,16'h8001,8'ha4);flash_write(j,16'h8000,8'hf0);
 end
 // A missing bank starts erased; programming is NOR AND, never OR/overwrite.
 reg_write(16'hde00,63);
 for(j=0;j<2;j=j+1)begin
  unlock(j,8'ha0);flash_write(j,16'h9ff0,8'h5a);idle_bus;repeat(128)tick;
  cart_read(j,0,16'h9ff0,8'h5a);
 end
 unlock(0,8'ha0);flash_write(0,16'h9ff0,8'ha5);idle_bus;repeat(128)tick;cart_read(0,0,16'h9ff0,0);
 unlock(0,8'h80);flash_write(0,16'h8555,8'haa);flash_write(0,16'h82aa,8'h55);flash_write(0,16'h9ff0,8'h30);idle_bus;
 while(dut.easyflash_port.ef.req0 || dut.easyflash_port.ef.flash0.state!=0)tick;repeat(64)tick;
 for(i=458752;i<524288;i=i+1)if(physical.memory[i/2][(i%2)*8+:8]!==8'hff)$fatal(1,"sector erase");
 for(i=0;i<458752;i=i+1)if(physical.memory[i/2][(i%2)*8+:8]!==expected[i])$fatal(1,"sector erase changed another sector");
 cart_read(0,0,16'h9ff0,8'hff);cart_read(1,0,16'h9ff0,8'h5a);
 c64reset=1;repeat(4)tick;c64reset=0;repeat(8)tick;
 if({exrom,game}!==2'b10 || dut.easyflash_port.ef.bank!=0)$fatal(1,"soft reset control");
 reset=1;tick;reset=0;repeat(12)tick;if(attached || {exrom,game}!==2'b11)$fatal(1,"eject");
 $display("PASS EasyFlash: CRT, all64banks/byte lanes/CPU+VIC reads, modes,256-byteIO2RAM, both AM29F040 IDs, NOR programming, sector erase isolation, reset/eject, %0d read checks",checks);$finish;
end
initial begin forever begin #1000000;$display("EF progress time=%t byte=%d init=%d state=%d ready=%b",$time,i,dut.easyflash_port.ef.init_word,dut.parser.state,ready);$fflush();end end
initial begin #1000000000;$fatal(1,"EasyFlash timeout");end
endmodule



