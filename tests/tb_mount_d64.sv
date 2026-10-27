`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg reset=1,dirty=0,writing=0,wp=0,loader_idle=1;reg [6:0] head=0;
wire busy,pause_req,mounted,rom,commit,savepause,clear,write_ready;
wire [6:0] loaded;wire [7:0] err,state;wire [1:0] fmt;wire [15:0] len;
wire [9:0] ta,ra;wire [63:0] td;wire tw;
reg [63:0] tracks[0:1023],q1,q2,q3;
wire req;wire [31:0] ca,cd;wire [3:0] cs;
reg initwr=0;reg [31:0] ia,id;
wire [31:0] ba=initwr?ia:ca,bd=initwr?id:cd;
wire bw=initwr || req;
reg [5:0] pause_pipe=0;
always @(posedge clk)pause_pipe<={pause_pipe[4:0],pause_req};
wire need=mounted && head!=loaded;
reg [3:0] cleardelay=0;
integer commits=0;reg seen=0;integer prior_opens=0;
pocket_storage #(.AUTOSAVE_CYCLES(100)) dut(.clk(clk),.reset(reset),.bridge_addr(ba),.bridge_wr_data(bd),.bridge_wr(bw),
 .cpu_req(req),.cpu_addr(ca),.cpu_data(cd),.cpu_wstrb(cs),.cpu_ack(1'b1),.cpu_rdata(32'b0),
 .loader_idle(loader_idle),.loader_start(1'b0),.loader_slot(16'b0),.loader_offset(32'b0),.loader_length(11'b0),
 .loader_buffer_addr(8'b0),.loader_table_addr(6'b0),.head_track(head),.need_track(need),.paused(pause_pipe[5]),
 .dirty(dirty),.writing(writing),.write_protect(wp),.write_enable(1'b1),.save_pause(savepause),
 .clear_modified(clear),.write_ready(write_ready),.track_read_addr(ra),.track_read_q(q3),
 .disk_busy(busy),.disk_pause(pause_req),.mounted(mounted),.rom_loaded(rom),
 .track_we(tw),.track_addr(ta),.track_data(td),.commit_toggle(commit),.loaded_track(loaded),
 .disk_error(err),.disk_state(state),.disk_format(fmt),.track_len(len));
integer rom_bytes=0;
always @(posedge clk)begin
 if(dut.rom_we)begin
  if(dut.rom_data!==dut.internal_io.reader.rom_data[dut.rom_addr])$fatal(1,"ROM upload corruption");
  rom_bytes<=rom_bytes+1;
 end
 q1<=tracks[ra];q2<=q1;q3<=q2;
 if(tw)begin
  if(dirty)$fatal(1,"dirty track overwritten before flush/clear");
  tracks[ta]<=td;
 end
 if(clear)begin
  if(dut.internal_io.reader.flushes==0)$fatal(1,"clear before flush");
  if(cleardelay==7)dirty<=0;else cleardelay<=cleardelay+1;
 end else cleardelay<=0;
 if(commit!=seen)begin seen<=commit;commits<=commits+1;end
 if(dut.internal_io.reader.opens>prior_opens && dirty)$fatal(1,"alias rebound while dirty");
 prior_opens<=dut.internal_io.reader.opens;
end
task tableword(input integer n,input [31:0] value);begin
 @(negedge clk);initwr=1;ia=32'hf8002000+n*4;id=value;
 @(negedge clk);initwr=0;
end endtask
task waitcommit(input integer n);integer t;begin
 t=0;while(commits<n && t<500000)begin @(negedge clk);t=t+1;end
 if(commits<n)$fatal(1,"commit timeout state=%d session=%d err=%h",state,dut.session_state,err);
 repeat(10)@(negedge clk);
end endtask
initial begin
 wait(!reset);wait(dut.bind_request);
 // A queued PRG withdraws loader_idle while disk owns table/file buffer.
 @(negedge clk);loader_idle=0;
 wait(dut.alias_valid || dut.direct_read_only);@(negedge clk);loader_idle=1;
end
integer opens_before, track_number, dumpfile, byte_index;
initial begin
 if($test$plusargs("swap"))begin
  wait(dut.disk.state==10 && dut.disk.kind==7);
  @(negedge clk);dut.internal_io.reader.inject_event=1;
  repeat(2)@(negedge clk);dut.internal_io.reader.inject_event=0;
 end
end
initial begin
 if($test$plusargs("readonly"))wp=1;
 tableword(0,203);tableword(1,16384);tableword(2,2);tableword(3,$test$plusargs("runtime") ? 0:174848);
 tableword(4,0);tableword(5,0);
 repeat(4)@(negedge clk);reset=0;
 if($test$plusargs("runtime"))begin
  wait(rom && !busy);repeat(20)@(negedge clk);
  tableword(3,174848);
  dut.internal_io.reader.inject_event=1;repeat(2)@(negedge clk);dut.internal_io.reader.inject_event=0;
 end
 waitcommit(1);
 if($test$plusargs("swap"))waitcommit(2);
 if(fmt!=1 || len!=7602)$fatal(1,"initial alias/mount");
 if(($test$plusargs("failopen") || $test$plusargs("failget")) && write_ready)$fatal(1,"fallback writable");
 if(rom_bytes!=16384)$fatal(1,"ROM length");
 if(pause_req || busy)$fatal(1,"mount did not resume");
 if(wp && (write_ready || dut.internal_io.reader.opens!=0))$fatal(1,"protected mount opened alias");
 dumpfile=$fopen("mount_tracks.hex","w");
 for(track_number=0;track_number<35;track_number=track_number+1)begin
  if(track_number!=0)begin head=track_number*2;waitcommit(commits+1);end
  if(!mounted || pause_req || busy)$fatal(1,"track refill did not resume");
  $fdisplay(dumpfile,"TRACK %0d %0d",head,len);
  for(byte_index=0;byte_index<len+2;byte_index=byte_index+1)
   $fdisplay(dumpfile,"%02x",(tracks[byte_index/8] >> ((byte_index%8)*8)) & 255);
 end
 $fclose(dumpfile);
 $display("PASS D64 mount and all 35 D64 track refills, no stuck pause, commits=%0d",commits);$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule

// Transaction-level APF service mock; real file_reader register commands are
// independently covered by run_file_ops.py. Uses real dual-port file buffer.
module pocket_file_reader(input clk,reset,start,input [15:0]slot,input [2:0]operation,
 input [31:0]offset,input [10:0]length,output wire ready,output reg done=0,output reg error=0,
 output reg [7:0]events=0,output reg cpu_req=0,output reg [31:0]cpu_addr=0,output reg [31:0]cpu_data=0,
 output wire [3:0]cpu_wstrb,input cpu_ack,input [31:0]cpu_rdata);
reg active=0;integer pos=0,n=0;reg [31:0]off;reg [15:0]sl;reg [2:0]op;
integer opens=0,writes=0,flushes=0;reg inject_event=0,fail_flush=0;
assign ready=!active;assign cpu_wstrb=15;
reg [7:0] image_data[0:174847];
reg [7:0] rom_data[0:16383];
initial begin $readmemh("mount_d64.hex",image_data);$readmemh("mount_rom.hex",rom_data);end
function [7:0] imagebyte(input integer a);begin imagebyte=image_data[a];end endfunction
integer k;reg [31:0]worddata;
always @(posedge clk)begin
 done<=0;cpu_req<=0;events<=inject_event ? 8'h04:0;
 if(reset)begin active<=0;error<=0;opens<=0;writes<=0;flushes<=0;fail_flush<=0;end
 else if(start && ready)begin
  active<=1;pos<=0;off<=offset;sl<=slot;op<=operation;n<=length;error<=0;
  if(operation==0 && slot!=203 && slot!=6 && slot!=2)$fatal(1,"image read without alias");
  if(operation==1)begin
   if(slot!=6)$fatal(1,"wrong save alias");writes<=writes+1;
  end
  if(operation==2)flushes<=flushes+1;
  if(operation==3 && slot!=2)$fatal(1,"wrong filename source");
  if(operation==4)begin
   if(slot!=6 || tb.dut.file_buffer.mem[64]!=0 || tb.dut.file_buffer.mem[65]!=0)$fatal(1,"unsafe open flags/size");
   opens<=opens+1;
  end
 end else if(active)begin
  if(op==0 && pos<n)begin
   worddata=0;
   for(k=0;k<4;k=k+1)if(pos+k<n)worddata[24-k*8 +:8]=sl==203 ? rom_data[off+pos+k]:imagebyte(off+pos+k);
   cpu_req<=1;cpu_addr<=32'h70000000+pos;cpu_data<=worddata;pos<=pos+4;
  end else if(op==3 && pos<268)begin
   cpu_req<=1;cpu_addr<=32'h70000000+pos;cpu_data<=32'hffffffff;pos<=pos+4;
  end else begin active<=0;done<=1;error<=(op==2 && fail_flush) || (op==4 && $test$plusargs("failopen")) || (op==3 && $test$plusargs("failget"));end
 end
end
endmodule


