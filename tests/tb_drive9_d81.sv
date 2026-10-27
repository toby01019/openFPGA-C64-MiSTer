`timescale 1ns/1ps
module tb;
reg host=0,core=0;always #6.734 host=~host;always #15.859 core=~core;
reg reset=1;reg [1:0]mode=2;wire [1:0]active;wire pause_req;
wire [1:0]start;reg [1:0]ready=3,done=0,err=0;wire [5:0]ops;wire [31:0]slots;wire [63:0]offsets;wire [21:0]lengths;
reg [31:0]ba=0,bd=0;reg bw=0;wire [7:0]errorcode;wire dataout,clockout;
pocket_drive9 dut(.clk74(host),.clk_core(core),.reset_host(reset),.reset_core(reset),.pause_core(pause_req),.paused_host(pause_req),
 .requested_mode(mode),.write_protect(1'b0),.host_enable(1'b1),.bridge_addr(ba),.bridge_data(bd),.bridge_wr(bw),.events(8'b0),
 .iec_atn(1'b1),.iec_data(dataout),.iec_clock(clockout),.data_o(dataout),.clock_o(clockout),
 .pause_request(pause_req),.active_mode(active),.error_code(errorcode),
 .io_start(start),.io_ready(ready),.io_done(done),.io_error(err),.io_operation(ops),.io_slot(slots),.io_offset(offsets),.io_length(lengths));
reg [7:0]rom[0:32767];integer i,j,sl,off,len,op,reads=0,writes=0,flushes=0,opens=0;
reg [31:0]value;
task bridge(input [31:0]a,input [31:0]d);begin @(negedge host);ba=a;bd=d;bw=1;@(negedge host);bw=0;end endtask
function [7:0]payload(input integer a);payload=(a*37+11)&255;endfunction
initial begin
 $readmemh("drive1581_converted/diagnostic_rom.hex",rom);
 bridge(32'hf80020f8,204);bridge(32'hf80020fc,32768);
 bridge(32'hf80020f0,4);bridge(32'hf80020f4,819200);
 repeat(5)@(negedge host);reset=0;
 forever begin
  @(posedge host);
  if(start[0])$fatal(1,"inactive 1541 requested IO");
  if(start[1])begin
   sl=slots[31:16];off=offsets[63:32];len=lengths[21:11];op=ops[5:3];
   @(negedge host);ready=0;
   case(op)
    0:begin
     if(sl!=204 && sl!=7)$fatal(1,"wrong ROM/image slot");
     if(sl==7)begin if(len!=512 || off!=0)$fatal(1,"FDC sector");reads=reads+1;end
     for(i=0;i<len;i=i+4)begin
      value=0;
      for(j=0;j<4;j=j+1)value[24-j*8 +:8]=sl==204 ? rom[off+i+j]:payload(off+i+j);
      bridge(32'h70000800+i,value);
     end
    end
    3:begin if(sl!=4)$fatal(1,"filename slot");for(i=0;i<268;i=i+4)bridge(32'h70000800+i,32'hffffffff);end
    4:begin
     if(sl!=7 || dut.storage1581.file_buffer.mem[64]!=0 || dut.storage1581.file_buffer.mem[65]!=0)$fatal(1,"alias open");opens=opens+1;
    end
    1:begin
     if(sl!=7 || len!=512 || off!=0)$fatal(1,"sector write");
     for(i=0;i<512;i=i+1)if(dut.storage1581.file_buffer.mem[i/4][i%4*8 +:8]!==payload(i))$fatal(1,"sector payload %d",i);
     writes=writes+1;
    end
    2:begin if(writes==0)$fatal(1,"flush without write");flushes=flushes+1;end
    default:$fatal(1,"unknown IO");
   endcase
   repeat(4)@(negedge host);done=2;@(negedge host);done=0;ready=3;
  end
 end
end
initial begin
 wait(reads==1);wait(dut.drive1581.transfer_state==0);repeat(3)@(negedge core);
 for(j=0;j<512;j=j+1)if(dut.drive1581.drive.fdc.fifo.ram[j]!==payload(j))$fatal(1,"actual FDC FIFO %d",j);
 wait(dut.drive1581.drive.ram.ram[513]===8'h42);
 // CPU/FDC read above is real. Exercise write transport and delayed mode exit.
 force dut.drive1581.fdc_wr=1;
 wait(dut.d81dirty);mode=0;
 wait(dut.drive1581.fdc_ack);release dut.drive1581.fdc_wr;
 wait(active==0);
 if(writes!=1 || flushes!=1 || opens!=1 || errorcode!=0)$fatal(1,"write/flush/mode exit");
 repeat(10)@(negedge core);
 if(dataout!==1 || clockout!==1)$fatal(1,"inactive IEC bus drive");
 $display("PASS drive9 D81: actual 1581 CPU/FDC sector read through slot4/alias7/buffer, exact 512 bytes, write+flush before mode-off, IEC released");$finish;
end
initial begin #15000000;$fatal(1,"timeout active=%d frontend=%d err=%h",active,dut.storage1581.frontend.state,errorcode);end
endmodule
