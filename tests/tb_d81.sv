`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg reset=1,enable=1,grant=0,event_mount=0,wp=0;
reg [31:0] rom_size=32768,image_size=819200,lba=0;
reg rd=0,wr=0;wire ack,busy,mounted,romloaded,dirty;
wire [8:0] sa;wire [7:0] so;reg [7:0] si;wire sw,rw;wire [14:0]ra;wire [7:0]ro,err,state;
wire start;reg ready=1,done=0,ioerror=0;wire [2:0]op;wire [15:0]slot;wire [31:0]off;wire [10:0]len;
wire [7:0]ba;reg [31:0]bq;wire bw;wire [31:0]bd;
reg [31:0]buffer[0:255];reg [7:0]sector[0:511];
pocket_d81 dut(.clk(clk),.reset(reset),.enable(enable),.grant(grant),.mount_event(event_mount),
 .rom_size(rom_size),.image_size(image_size),.write_protect(wp),.sd_lba(lba),.sd_rd(rd),.sd_wr(wr),.sd_ack(ack),
 .sd_buff_addr(sa),.sd_buff_dout(so),.sd_buff_din(si),.sd_buff_wr(sw),
 .rom_we(rw),.rom_addr(ra),.rom_data(ro),.busy(busy),.mounted(mounted),.rom_loaded(romloaded),.dirty(dirty),
 .error_code(err),.debug_state(state),.io_start(start),.io_ready(ready),.io_done(done),.io_error(ioerror),
 .io_operation(op),.io_slot(slot),.io_offset(off),.io_length(len),.buffer_addr(ba),.buffer_q(bq),.buffer_we(bw),.buffer_data(bd));
integer i,n,delay=0,rombytes=0,reads=0,writes=0,flushes=0,opens=0,getnames=0,ackfalls=0;
reg lastack=0,failflush=0,swapwrite=0;reg [2:0]savedop;reg [31:0]savedoff;
function [7:0] pattern(input integer a);pattern=(a*37+11)&255;endfunction
always @(posedge clk)begin
 bq<=buffer[ba];si<=sector[sa];done<=0;ioerror<=0;event_mount<=0;
 if(bw)begin if(!busy || !grant)$fatal(1,"buffer ownership");buffer[ba]<=bd;end
 if(sw)begin if(!ack)$fatal(1,"copy without ack");sector[sa]<=so;end
 if(rw)begin
  if(ra!=rombytes || ro!==pattern(ra))$fatal(1,"ROM upload %d/%d",ra,rombytes);
  rombytes=rombytes+1;
 end
 if(ack)begin rd<=0;wr<=0;end
 if(lastack && !ack)ackfalls=ackfalls+1;lastack<=ack;
 if(start)begin
  if(!grant || !busy || !ready)$fatal(1,"request grant");
  ready<=0;delay<=7;savedop<=op;savedoff<=off;
  case(op)
   0:begin
    if(slot==204)begin
     if(len!=1024 || off+len>32768)$fatal(1,"ROM bounds");
    end else begin
     if(slot!=7 || len!=512 || off[8:0]!=0 || off+len>819200)$fatal(1,"image read bounds");reads=reads+1;
    end
    for(i=0;i<len;i=i+1)buffer[i/4][(i%4)*8 +:8]=pattern(off+i);
   end
   1:begin
    if(slot!=7 || len!=512 || !dirty || !ack)$fatal(1,"write protocol");
    for(i=0;i<512;i=i+1)if(buffer[i/4][(i%4)*8 +:8]!==((i*19+3)&255))$fatal(1,"write payload %d",i);
    writes=writes+1;
    if(swapwrite)begin event_mount<=1;swapwrite<=0;end
   end
   2:begin if(slot!=7 || !dirty)$fatal(1,"flush");flushes=flushes+1;end
   3:begin
    if(slot!=4 || dirty)$fatal(1,"filename before old flush");getnames=getnames+1;
    for(i=0;i<67;i=i+1)buffer[i]=32'hffffffff;
   end
   4:begin
    if(slot!=7 || buffer[64]!=0 || buffer[65]!=0 || dirty)$fatal(1,"unsafe alias open");opens=opens+1;
   end
   default:$fatal(1,"unknown operation");
  endcase
 end else if(delay>0)begin
  delay<=delay-1;
  if(delay==1)begin done<=1;ready<=1;ioerror<=failflush && savedop==2;end
 end
end
task eventpulse;begin @(negedge clk);event_mount=1;@(negedge clk);event_mount=0;end endtask
task sectorread(input integer a);integer prior;begin
 prior=ackfalls;@(negedge clk);lba=a;rd=1;
 wait(ackfalls>prior);wait(!busy);@(negedge clk);
 for(n=0;n<512;n=n+1)if(sector[n]!==pattern(a*512+n))$fatal(1,"read payload %d",n);
end endtask
task preparewrite(input integer a);begin
 for(n=0;n<512;n=n+1)sector[n]=(n*19+3)&255;
 @(negedge clk);lba=a;wr=1;
end endtask
task reboot;begin
 @(negedge clk);reset=1;rd=0;wr=0;event_mount=0;
 repeat(3)@(negedge clk);
 rombytes=0;reads=0;writes=0;flushes=0;opens=0;getnames=0;failflush=0;
 delay=0;ready=1;reset=0;
end endtask
initial begin
 repeat(3)@(negedge clk);reset=0;
 wait(busy);repeat(20)@(negedge clk);
 if(start || rombytes!=0)$fatal(1,"work before grant");grant=1;
 wait(mounted);wait(!busy);
 if(!romloaded || rombytes!=32768 || opens!=1)$fatal(1,"boot mount");
 sectorread(0);sectorread(1599);
 // enable controls admission only; the accepted operation must finish.
 @(negedge clk);lba=2;rd=1;wait(ack);@(negedge clk);enable=0;
 wait(!busy);@(negedge clk);enable=1;
 swapwrite=1;preparewrite(1599);
 wait(opens==2);wait(!busy);
 if(dirty || flushes!=1 || writes!=1 || ack)$fatal(1,"swap/flush ordering");
 // Image size with an appended error table must not be silently accepted.
 image_size=822400;eventpulse();wait(!mounted);wait(!busy);
 if(err!=2 || opens!=2)$fatal(1,"invalid image accepted");
 image_size=819200;eventpulse();wait(mounted);wait(!busy);
 // Failure retains staging and ownership, with no false completion.
 failflush=1;preparewrite(4);wait(err==8'h15);repeat(30)@(negedge clk);
 if(!dirty || !busy || !ack || opens!=3)$fatal(1,"flush failure lost write");
 reboot();wait(mounted);wait(!busy);wp=1;preparewrite(0);
 wait(err==4);repeat(10)@(negedge clk);
 if(writes!=0 || dirty || !ack)$fatal(1,"readonly accepted write");
 wp=0;reboot();wait(mounted);wait(!busy);
 @(negedge clk);lba=1600;rd=1;wait(err==3);
 if(reads!=0 || !ack)$fatal(1,"out-of-range LBA accepted");
 rom_size=0;reboot();repeat(20)@(negedge clk);
 if(busy || romloaded || mounted || err!=0)$fatal(1,"optional missing ROM blocks host");
 rom_size=32767;reboot();repeat(20)@(negedge clk);
 if(busy || romloaded || err!=1)$fatal(1,"bad ROM size");
 $display("PASS D81 frontend: 32KiB ROM, alias7, boundary sectors, 512-byte LE writes, flush-before-swap, error-table rejection, retained dirty/ack on flush failure, readonly, LBA bounds, optional ROM, enable lifetime");
 $finish;
end
initial begin #10000000;$fatal(1,"timeout state %d",state);end
endmodule
