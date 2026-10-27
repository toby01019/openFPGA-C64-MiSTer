`timescale 1ns/1ps
module tb;
reg clk=0,reset=1,restart=0;
always #5 clk=~clk;
reg [7:0] events=0;
wire start,valid,run,pause;
wire [25:0] data;
reg done=0,err=0,wdone=0;
wire [15:0] slot;
wire [31:0] offset;
wire [10:0] length;
wire [7:0] baddr;
wire [5:0] taddr,state;
reg [31:0] bdata=0,tdata=0;
wire [7:0] keys,error_code;
reg [31:0] size=1403;
reg [15:0] load_address=16'h0801;
reg bad_rom=0,consumed=0;
integer writes=0,romwrites=0,charwrites=0,clearwrites=0;
reg [7:0] memory[0:65535],buffer[0:1023];
integer delay_count=0;
pocket_loader #(.BOOT_CYCLES(10),.KEY_CYCLES(4)) dut(
 .clk(clk),.reset(reset),.restart(restart),.restart_safe(1'b1),.storage_hold(1'b0),.events(events),.read_start(start),.read_ready(1'b1),
 .read_done(done),.read_error(err),.read_slot(slot),.read_offset(offset),.read_length(length),
 .buffer_addr(baddr),.buffer_data(bdata),.table_addr(taddr),.table_data(tdata),
 .write_valid(valid),.write_data(data),.write_done(wdone),.core_run(run),.pause_request(pause),
 .paused(pause),.auto_keys(keys),.error_code(error_code),.debug_state(state));
function [7:0] filebyte(input [15:0] s,input integer pos);
 begin
 if(s!=1) filebyte=(s+pos)&255;
 else if(pos==0)filebyte=load_address[7:0];
 else if(pos==1)filebyte=load_address[15:8];
 else filebyte=(pos*37+11)&255;
 end
endfunction
always @(posedge clk) begin
 done<=0;wdone<=0;
 bdata<={buffer[{baddr,2'b00}+3],buffer[{baddr,2'b00}+2],buffer[{baddr,2'b00}+1],buffer[{baddr,2'b00}]};
 case(taddr)
 0:tdata<=200;1:tdata<=bad_rom?16:8192;
 2:tdata<=201;3:tdata<=4096;
 4:tdata<=202;5:tdata<=8192;
 6:tdata<=1;7:tdata<=size;
 default:tdata<=0;
 endcase
 if(start) begin
   if(offset+length>(slot==1?size:slot==201?4096:8192)) $fatal(1,"out-of-bounds file read");
   for(k=0;k<1024;k=k+1) buffer[k]<=filebyte(slot,offset+k);
   delay_count<=5;
 end else if(delay_count>0) begin
   delay_count<=delay_count-1;if(delay_count==1) done<=1;
 end
 if(!valid) consumed<=0;
 if(valid && !consumed && !reset) begin
   consumed<=1;wdone<=1;
   if(data[25:24]==0) begin memory[data[23:8]]<=data[7:0];writes=writes+1;end
   else if(data[25:24]==1) romwrites=romwrites+1;
   else if(data[25:24]==2) charwrites=charwrites+1;
   if(!run && data[25:24]==0) clearwrites=clearwrites+1;
 end
end
task event_prg;
 begin @(negedge clk);events=2;@(negedge clk);events=0;end
endtask
integer before_writes,j,k;
initial begin
 repeat(4) @(negedge clk);reset=0;
 wait(state==12);
 if(clearwrites!=65536 || romwrites!=16384 || charwrites!=4096) $fatal(1,"startup counts");
 before_writes=writes;event_prg();wait(state!=12);wait(state==12);
 if(writes-before_writes!=1401+8) $fatal(1,"PRG byte count");
 for(j=0;j<1401;j=j+1) if(memory[16'h0801+j]!==filebyte(1,j+2)) $fatal(1,"PRG data mismatch %0d",j);
 if({memory[16'h002e],memory[16'h002d]}!==16'h0d7a) $fatal(1,"BASIC pointer");
 before_writes=writes;@(negedge clk);restart=1;@(negedge clk);restart=0;
 wait(state!=12);wait(state==12);
 if(!run || pause || keys || error_code || writes-before_writes!=65536 || romwrites!=16384 || charwrites!=4096)$fatal(1,"non-CRT reset counts/run");
 for(j=0;j<65536;j=j+1)if(memory[j]!==0)$fatal(1,"non-CRT reset RAM %0d",j);
 $display("PASS non-CRT Reset Core: PRG removed, full RAM clear, ROMs retained, no automatic RUN");
 size=2;before_writes=writes;event_prg();wait(state==23);
 if(error_code!=2 || writes!=before_writes) $fatal(1,"short file not rejected");
 size=5;load_address=16'hffff;event_prg();wait(state!=23);wait(state==23);
 if(error_code!=3 || writes!=before_writes) $fatal(1,"overflow not rejected");
 size=3;load_address=16'h4000;event_prg();wait(state!=23);wait(state==12);
 if(error_code!=0 || memory[16'h4000]!==filebyte(1,2)) $fatal(1,"recovery after invalid file");
 @(negedge clk);reset=1;bad_rom=1;repeat(3)@(negedge clk);reset=0;
 wait(state==23);
 if(error_code!=5 || run) $fatal(1,"wrong ROM size not rejected");
 @(negedge clk);restart=1;@(negedge clk);restart=0;repeat(100)@(negedge clk);
 if(state!=23 || error_code!=5 || run)$fatal(1,"reset booted with incomplete system ROMs");
 $display("PASS loader: full 65536-byte clear; ROM metadata and upload; multi-chunk/unaligned PRG; BASIC pointers; truncated/overflow rejection; recovery; wrong ROM size");$finish;
end
initial begin #20000000;$fatal(1,"timeout state=%0d",state);end
endmodule
