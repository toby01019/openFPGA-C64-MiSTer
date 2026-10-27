`timescale 1ns/1ps
module tb;
reg core=0,host=0;
always #15.859 core=~core;
always #6.734 host=~host;
reg reset=1,pause=1,mounted=0,wp=1,atn=1;
reg rom_we=0; reg[14:0]rom_addr=0;reg[7:0]rom_data=0;
wire data_o,clock_o,fast_o,led,power,we;wire[7:0]track;
wire[31:0]lba;wire rd,wr;reg ack=0,buff_wr=0;reg[8:0]addr=0;reg[7:0]dout=0;wire[7:0]din;
pocket_1581 dut(.clk_core(core),.clk74(host),.reset(reset),.pause(pause),
.iec_atn_i(atn),.iec_data_i(1'b1),.iec_clk_i(1'b1),.iec_fclk_i(1'b1),
.iec_data_o(data_o),.iec_clk_o(clock_o),.iec_fclk_o(fast_o),
.drive_num(2'b0),.mounted(mounted),.write_protect(wp),.img_size(32'd819200),
.led(led),.power(power),.track(track),.we(we),.rom_we(rom_we),.rom_addr(rom_addr),.rom_data(rom_data),
.sd_lba(lba),.sd_rd(rd),.sd_wr(wr),.sd_ack(ack),.sd_buff_addr(addr),.sd_buff_dout(dout),.sd_buff_din(din),.sd_buff_wr(buff_wr));
reg[7:0]rom[0:32767];integer i,ce_count,cpu_count,wd_count;reg[23:0]saved_pc;reg[25:0]saved_fraction;reg[2:0]saved_phase;
initial begin #20000000;$display("TIMEOUT pc=%h ram=%h fdc busy=%b state=%d read=%b req=%b img=%b",dut.drive.cpu_a,dut.drive.ram.ram[513],dut.drive.fdc.busy,dut.drive.fdc.sd_state,dut.drive.fdc.sd_card_read,rd,dut.drive.fdc.fdn_present[0]);$fatal;end
initial begin
$readmemh("diagnostic_rom.hex",rom);
for(i=0;i<32768;i=i+1)begin @(negedge host);rom_we=1;rom_addr=i;rom_data=rom[i];end
@(negedge host);rom_we=0;mounted=1;
repeat(20)@(negedge core);reset=0;pause=0;
wait(rd===1);$display("1581 real CPU/FDC read requested LBA %d",lba);
if(lba!==0)$fatal(1,"LBA");
@(negedge core);pause=1;saved_pc=dut.drive.cpu_a;saved_fraction=dut.clock_fraction;saved_phase=dut.phase;
@(negedge host);ack=1;
for(i=0;i<512;i=i+1)begin @(negedge host);addr=i;dout=(i*37+11)&255;buff_wr=1;end
@(negedge host);buff_wr=0;ack=0;
wait(dut.transfer_state==0);repeat(20)@(negedge core);
for(i=0;i<512;i=i+1)if(dut.drive.fdc.fifo.ram[i]!==((i*37+11)&255))$fatal(1,"FIFO %d got %h",i,dut.drive.fdc.fifo.ram[i]);
if(dut.drive.cpu_a!==saved_pc || dut.clock_fraction!==saved_fraction || dut.phase!==saved_phase)$fatal(1,"pause");
if(dut.drive.fdc.sd_state!==0)$fatal(1,"ACK completion");
$display("1581 paused CDC read: 512 exact bytes and completed FDC handshake");
pause=0;wait(dut.drive.ram.ram[513]===8'h42);repeat(2000)@(negedge core);
if(dut.drive.ram.ram[517]!==8'ha5 || led!==1 || power!==1)$fatal(1,"CPU/VIA/CIA LEDs");
atn=0;repeat(2000)@(negedge core);
if(dut.drive.ram.ram[512][7]!==1 || data_o!==0)$fatal(1,"IEC ATN");
if(dut.drive.ram.ram[512][6]!==0)$fatal(1,"WP input");
if(dut.drive.ram.ram[518]!==1 || dut.drive.ram.ram[514][6]!==1 || dut.drive.ram.ram[514][0]!==0)$fatal(1,"protected FDC command %h",dut.drive.ram.ram[514]);
ce_count=0;cpu_count=0;wd_count=0;
repeat(31528)begin @(negedge core);ce_count=ce_count+dut.ce16;cpu_count=cpu_count+dut.ph2_r;wd_count=wd_count+dut.wd_ce;end
if(ce_count<15999 || ce_count>16001 || cpu_count<1999 || cpu_count>2001 || wd_count<7999 || wd_count>8001)$fatal(1,"clock rates");
pause=1;
// Independent sector-transport write request: CPU/FDC execution above remains real.
wp=0;force dut.fdc_wr=1;
wait(wr===1);if(rd!==0)$fatal(1,"direction");
@(negedge host);ack=1;
for(i=0;i<512;i=i+1)begin
 @(negedge host);addr=i;repeat(2)@(negedge host);
 if(din!==((i*37+11)&255))$fatal(1,"write staging %d %h",i,din);
end
@(negedge host);ack=0;wait(dut.fdc_ack);release dut.fdc_wr;
wait(dut.transfer_state==0);$display("1581 paused CDC write: 512 exact bytes");
wp=1;force dut.fdc_wr=1;wait(dut.fdc_ack);release dut.fdc_wr;
repeat(30)@(negedge core);if(wr!==0)$fatal(1,"protected host write");
mounted=0;repeat(20)@(negedge core);if(dut.drive.fdc.fdn_present[0]!==0)$fatal(1,"unmount");
mounted=1;repeat(20)@(negedge core);if(dut.drive.fdc.fdn_present[0]!==1)$fatal(1,"remount");
force dut.fdc_rd=1;wait(rd);release dut.fdc_rd;
reset=1;repeat(20)@(negedge core);
if(rd!==0 || wr!==0 || dut.drive.fdc.sd_state!==0 || data_o!==1 || clock_o!==1 || fast_o!==1)$fatal(1,"reset");
$display("PASS 1581 CPU VIA CIA IEC read/write CDC pause write-protection reset");$finish;
end
endmodule

