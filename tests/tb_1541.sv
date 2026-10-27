`timescale 1ns/1ps
module tb;
reg core=0,host=0;
always #15.859 core=~core;
always #6.734 host=~host;
reg reset=1,pause=1,mounted=0,wp=1,clear_modified=0;
reg atn=1,data=1,serial_clock=1;
wire data_o,clock_o,led,motor,dirty;
wire [6:0] track;
reg rom_we=0,track_we=0;
reg [13:0] rom_addr=0;
reg [7:0] rom_data=0;
reg [9:0] track_addr=0;
reg [63:0] track_data=0;
wire [63:0] track_q;
pocket_1541 dut(.clk_core(core),.clk74(host),.reset(reset),.pause(pause),
 .iec_atn_i(atn),.iec_data_i(data),.iec_clk_i(serial_clock),.iec_data_o(data_o),.iec_clk_o(clock_o),
 .mounted(mounted),.write_protect(wp),.drive_num(2'b0),.track(track),.led(led),.motor(motor),
 .modified(dirty),.clear_modified(clear_modified),.rom_we(rom_we),.rom_addr(rom_addr),.rom_data(rom_data),
 .track_we(track_we),.track_addr(track_addr),.track_data(track_data),.track_q(track_q));
reg [7:0] rom[0:16383];
integer i,j,byte_events=0,sync_events=0,ce_count=0;
reg last_byte=1,last_sync=1;
always @(posedge core) if(!reset && !pause)begin
 if(!dut.byte_n && last_byte)byte_events=byte_events+1;
 if(!dut.sync_n && last_sync)sync_events=sync_events+1;
 last_byte=dut.byte_n;last_sync=dut.sync_n;
end
function [63:0] original_word(input integer address);
begin
 if(address==0) original_word=64'hffffffffffff1be6;
 else if(address<2) original_word=64'hffffffffffffffff;
 else original_word=64'h5555555555555555;
end
endfunction
task read_word(input integer address);
begin @(negedge host);track_addr=address;repeat(5)@(negedge host);end
endtask
reg [23:0] paused_pc;
reg [15:0] paused_bit;
reg [3:0] paused_phase;
reg [25:0] paused_fraction;
reg [63:0] modified_word;
integer changed;
initial begin
 $readmemh("diagnostic_rom.hex",rom);
 repeat(10)@(negedge host);
 if(data_o!==1 || clock_o!==1)$fatal(1,"IEC must release during reset");
 for(i=0;i<16384;i=i+1)begin
  @(negedge host);rom_we=1;rom_addr=i;rom_data=rom[i];
 end
 @(negedge host);rom_we=0;
 for(i=0;i<1024;i=i+1)begin
  @(negedge host);track_we=1;track_addr=i;track_data=original_word(i);
 end
 @(negedge host);track_we=0;mounted=1;
 repeat(10)@(negedge core);reset=0;pause=0;
 wait(dut.logic1541.ram.ram[16'h0201]===8'h42);
 repeat(2000)@(negedge core);
 if(track!==34 || !motor || !led || data_o!==1 || clock_o!==1)
  $fatal(1,"CPU/VIA setup track=%0d motor=%b led=%b IEC=%b%b",track,motor,led,data_o,clock_o);
 atn=0;wait(track==35);wait(dut.logic1541.ram.ram[16'h0200][7]===1);repeat(100)@(negedge core);
 if(data_o!==0 || dut.logic1541.ram.ram[16'h0200][7]!==1)$fatal(1,"IEC ATN receive/ack data=%b ram=%h pb=%h oe=%h input=%b",data_o,dut.logic1541.ram.ram[16'h0200],dut.logic1541.uc1_pb_o,dut.logic1541.uc1_pb_oe,dut.atn_in);
 atn=1;wait(track==34);repeat(15000)@(negedge core);
 if(byte_events<4 || sync_events<1)$fatal(1,"GCR missing byte=%0d sync=%0d data=%h",byte_events,sync_events,dut.gcr_data);
 if(dirty)$fatal(1,"read-only drive became dirty");
 pause=1;repeat(8)@(negedge core);
 paused_pc=dut.logic1541.cpu_a;paused_bit=dut.gcr.buff_addr;paused_phase=dut.phase;paused_fraction=dut.clock_fraction;
 repeat(300)@(negedge core);
 if(dut.logic1541.cpu_a!==paused_pc || dut.gcr.buff_addr!==paused_bit || dut.phase!==paused_phase || dut.clock_fraction!==paused_fraction)
  $fatal(1,"pause failed to freeze drive CPU/rotation/phase");
 read_word(0);if(track_q!==original_word(0))$fatal(1,"header readback %h",track_q);
 read_word(20);if(track_q!==original_word(20))$fatal(1,"track readback %h",track_q);
 @(negedge host);track_we=1;track_data=64'h0123456789abcdef;
 @(negedge host);track_we=0;read_word(20);
 if(track_q!==64'h0123456789abcdef)$fatal(1,"paused track upload/readback");
 @(negedge host);track_we=1;track_data=original_word(20);
 @(negedge host);track_we=0;repeat(8)@(negedge core);
 if(dut.logic1541.ram.ram[16'h0201]!==8'h42 || dut.logic1541.cpu_a!==paused_pc)$fatal(1,"track upload reset CPU");
 pause=0;ce_count=0;
 for(i=0;i<31528;i=i+1)begin @(posedge core);if(dut.ce16)ce_count=ce_count+1;end
 if(ce_count<15999 || ce_count>16001)$fatal(1,"16MHz enable rate %0d",ce_count);
 @(negedge core);serial_clock=0;
 wait(dut.logic1541.ram.ram[16'h0201]===8'h43);
 repeat(5000)@(negedge core);if(dirty)$fatal(1,"write protection failed");
 mounted=0;wp=0;repeat(5000)@(negedge core);if(dirty)$fatal(1,"empty drive became dirty");
 pause=1;repeat(10)@(negedge core);
 for(j=8;j<128;j=j+1)begin read_word(j);if(track_q!==original_word(j))$fatal(1,"protected or empty drive changed track memory");end
 mounted=1;pause=0;wait(dirty);repeat(6000)@(negedge core);pause=1;
 repeat(10)@(negedge core);
 if(!dirty)$fatal(1,"dirty flag not sticky");
 changed=0;
 for(j=8;j<128;j=j+1)begin read_word(j);if(track_q!==original_word(j))changed=changed+1;end
 if(changed==0)$fatal(1,"write pulses never changed track memory");
 clear_modified=1;repeat(3)@(negedge core);clear_modified=0;
 if(dirty)$fatal(1,"dirty clear failed while paused");
 pause=0;wait(dirty);wp=1;
 repeat(10)@(negedge core);pause=1;repeat(10)@(negedge core);
 clear_modified=1;repeat(3)@(negedge core);clear_modified=0;
 pause=0;repeat(5000)@(negedge core);if(dirty)$fatal(1,"protection failed after clear");
 $display("PASS 1541: original T65/VIA ROM execution, IEC ATN/ack, half-track forward/back, motor/LED, GCR sync/byte-ready, pause/upload without reset, 16MHz CE, write protection, raw-track writes/readback, sticky modified/clear. bytes=%0d sync=%0d changed_words=%0d",byte_events,sync_events,changed);
 $finish;
end
initial begin #20000000;$display("DIAG pc=%h data=%h RAM201=%h track=%0d phase=%0d ce=%b",dut.logic1541.cpu_a,dut.logic1541.cpu_di,dut.logic1541.ram.ram[16'h0201],track,dut.phase,dut.ce16);$fatal(1,"drive timeout");end
endmodule
