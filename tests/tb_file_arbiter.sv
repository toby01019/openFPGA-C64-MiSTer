`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;reg reset=1;
reg [2:0] pending=7;wire [2:0] ready,done,error;wire [2:0] start=ready&pending;
reg [8:0] operation=0;wire [47:0]slots={16'd12,16'd11,16'd10};
wire [95:0]offsets={32'h123402,32'h123401,32'h123400};wire [32:0]lengths={11'd512,11'd768,11'd1024};
wire [7:0]events;wire req;wire [31:0]addr,data;wire [3:0]strb;reg ack=0;reg [31:0]rdata=0;
pocket_file_arbiter dut(.clk(clk),.reset(reset),.start(start),.ready(ready),.done(done),.error(error),
 .operation(operation),.slot(slots),.offset(offsets),.length(lengths),.events(events),
 .cpu_req(req),.cpu_addr(addr),.cpu_data(data),.cpu_wstrb(strb),.cpu_ack(ack),.cpu_rdata(rdata));
integer n,phase=0,owner=-1,op=0,completed=0,commands=0,polls=0;reg served=0;
function [15:0]code(input integer o);case(o)0:code='h180;1:code='h184;2:code='h188;3:code='h190;4:code='h192;endcase endfunction
always @(posedge clk)begin
 ack<=0;if(!req)served<=0;
 if(!reset)begin
  if((ready&(ready-1))!=0)$fatal(1,"multiple grants");
  for(n=0;n<3;n=n+1)begin
   if(start[n])begin
    if(owner!=-1)$fatal(1,"interleaved reader start");owner=n;op=operation[n*3 +:3];pending[n]<=0;
   end
   if(done[n])begin
    if(owner!=n || error[n])$fatal(1,"wrong completion owner/error");
    completed=completed+1;owner=-1;
    if(operation[n*3 +:3]<4)begin operation[n*3 +:3]<=operation[n*3 +:3]+1'b1;pending[n]<=1;end
   end
  end
 end
 if(req && !served)begin
  served<=1;ack<=1;rdata<=0;
  if(strb==0)begin
   if(addr==32'h40000080)begin
    if(phase!=0)$fatal(1,"poll interleaved with transaction");polls=polls+1;rdata<=32'h14;
   end else begin
    if(addr!=32'h40000000 || phase!=5)$fatal(1,"bad completion poll");
    rdata<=32'h6f6b0000;phase=0;
   end
  end else begin
   if(owner<0)$fatal(1,"parameters before ownership");
   case(phase)
    0:if(addr!=32'h40000020 || data!=10+owner)$fatal(1,"slot interleave");
    1:if(addr!=32'h40000024 || data!=((op==3 || op==4)?32'h70000000+owner*1024:32'h123400+owner))$fatal(1,"offset/name base");
    2:if(addr!=32'h40000028 || data!=32'h70000000+owner*1024)$fatal(1,"isolated buffer base");
    3:if(addr!=32'h4000002c || data!=1024-owner*256)$fatal(1,"length");
    4:begin if(addr!=32'h40000000 || data!={16'h636d,code(op)})$fatal(1,"operation");commands=commands+1;end
    default:$fatal(1,"extra parameter");
   endcase
   phase=phase+1;
  end
 end
end
reg bw=0;reg [31:0]ba=0,bd=0;wire [31:0]q8,q9,q81;
pocket_storage #(.EXTERNAL_IO(1)) s8(.clk(clk),.reset(1'b1),.bridge_addr(ba),.bridge_wr_data(bd),.bridge_wr(bw),.buffer_bridge_data(q8));
pocket_storage #(.EXTERNAL_IO(1),.IMAGE_SLOT(4),.EVENT_BIT(4),.ALIAS_SLOT(7),.BUFFER_BASE(32'h70000400)) s9(.clk(clk),.reset(1'b1),.bridge_addr(ba),.bridge_wr_data(bd),.bridge_wr(bw),.buffer_bridge_data(q9));
pocket_d81_storage s81(.clk(clk),.reset(1'b1),.bridge_addr(ba),.bridge_data(bd),.bridge_wr(bw),.bridge_q(q81));
task put(input [31:0]a,input [31:0]d);begin @(negedge clk);ba=a;bd=d;bw=1;@(negedge clk);bw=0;end endtask
initial begin
 put(32'h70000000,32'h11223344);put(32'h70000400,32'h55667788);put(32'h70000800,32'h99aabbcc);
 repeat(3)@(negedge clk);
 if(q8!==32'h11223344 || q9!==32'h55667788 || q81!==32'h99aabbcc)$fatal(1,"buffer bridge isolation/endian");
 if(s8.file_buffer.mem[0]!==32'h44332211 || s9.file_buffer.mem[0]!==32'h88776655 || s81.file_buffer.mem[0]!==32'hccbbaa99)$fatal(1,"normalized host byte order");
 reset=0;wait(completed==15);wait(events!=0);
 if(events!=8'h14 || commands!=15 || polls!=1)$fatal(1,"single shared poll/coverage");
 $display("PASS central arbiter: 3 concurrent clients x 5 real APF commands, grant-before-start, no parameter interleaving, exclusive completion, single event poll, 3 isolated endian-correct buffers");$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
