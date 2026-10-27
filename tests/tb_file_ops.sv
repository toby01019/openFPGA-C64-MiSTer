`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg reset=1,start=0;reg [2:0] op=0;reg [15:0] slot=6;
reg [31:0] offset=32'h12345;reg [10:0] length=1024;
wire ready,done,error,req;wire [7:0] events;wire [31:0] addr,data;wire [3:0] strb;
reg ack=0;reg [31:0] rdata=0;
pocket_file_reader #(.TIMEOUT(2000)) dut(.clk(clk),.reset(reset),.start(start),.operation(op),
 .slot(slot),.offset(offset),.length(length),.ready(ready),.done(done),.error(error),.events(events),
 .cpu_req(req),.cpu_addr(addr),.cpu_data(data),.cpu_wstrb(strb),.cpu_ack(ack),.cpu_rdata(rdata));
reg served=0,stall=0;reg [15:0] status=0;integer phase=0,commands=0,polls=0;
function [15:0] code(input integer n);
case(n)0:code='h180;1:code='h184;2:code='h188;3:code='h190;4:code='h192;endcase
endfunction
always @(posedge clk)begin
 ack<=0;
 if(!req)served<=0;
 if(req && !served && !stall)begin
  served<=1;ack<=1;rdata<=0;
  if(strb==0)begin
   if(addr==32'h40000080)begin rdata<=32'h94;polls=polls+1;end
   else if(addr==32'h40000000)begin
    if(phase!=5)$fatal(1,"command poll before parameters");
    rdata<={16'h6f6b,status};phase=0;
   end else $fatal(1,"unknown read register");
  end else begin
   if(strb!=15)$fatal(1,"byte strobes");
   case(phase)
    0:if(addr!=32'h40000020 || data!=6)$fatal(1,"slot");
    1:if(addr!=32'h40000024 || data!=((op==3 || op==4) ? 32'h70000000:32'h12345))$fatal(1,"offset/name pointer");
    2:if(addr!=32'h40000028 || data!=32'h70000000)$fatal(1,"buffer pointer");
    3:if(addr!=32'h4000002c || data!=1024)$fatal(1,"length");
    4:begin
     if(addr!=32'h40000000 || data!={16'h636d,code(op)})$fatal(1,"operation command");
     commands=commands+1;
    end
    default:$fatal(1,"extra write");
   endcase
   phase=phase+1;
  end
 end
end
task request(input [2:0] operation,input [15:0] result,input expected_error);
integer n;
begin
 while(!ready)@(negedge clk);
 op=operation;status=result;start=1;@(negedge clk);start=0;n=0;
 while(!done)begin @(negedge clk);n=n+1;if(n>2100)$fatal(1,"request stuck");end
 if(error!==expected_error)$fatal(1,"operation %0d status %0d error %0d",operation,result,error);
 @(negedge clk);
end endtask
integer i;
initial begin
 repeat(3)@(negedge clk);reset=0;
 for(i=0;i<5;i=i+1)request(i,0,0);
 request(4,1,0); // 0192: created is a successful result too.
 request(4,2,1);request(1,1,1);request(2,3,1);
 wait(events!=0);if(events!==8'h94)$fatal(1,"event polling");
 @(negedge clk);stall=1;phase=0;op=0;start=1;@(negedge clk);start=0;
 wait(done);@(negedge clk);if(!error || !ready || req)$fatal(1,"timeout recovery");
 stall=0;request(0,0,0);
 if(commands!=10 || polls<1)$fatal(1,"coverage");
 $display("PASS APF file operations: read/write/flush/getfilename/open, parameter byte order, created result, errors, events, timeout and recovery");$finish;
end
initial begin #2000000;$fatal(1,"test timeout");end
endmodule
