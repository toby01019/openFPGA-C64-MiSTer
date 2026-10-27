// SPDX-License-Identifier: MIT
// Serialize APF register accesses through the existing command bridge.
module pocket_file_reader #(parameter TIMEOUT=742500000, parameter DYNAMIC_BUFFER=0)(
 input wire clk,reset,input wire [31:0] buffer_base,input wire start,input wire [15:0] slot,
 // 0 read, 1 write, 2 flush, 3 get filename, 4 open filename from buffer.
 input wire [2:0] operation,
 input wire [31:0] offset,input wire [10:0] length,
 output wire ready,output reg done=0,output reg error=0,output reg [7:0] events=0,
 output reg cpu_req=0,output reg [31:0] cpu_addr=0,output reg [31:0] cpu_data=0,
 output reg [3:0] cpu_wstrb=0,input wire cpu_ack,
 input wire [31:0] cpu_rdata
);
 localparam IDLE=0,ISSUE=1,ACK=2,GAP=3,ADVANCE=4;
 reg [2:0] state=IDLE,phase=0;
 reg [3:0] gap=0;
 reg poll=0;
 reg [11:0] poll_count=1;
 reg [31:0] elapsed=0,result=0,off_hold=0,buffer_hold=32'h70000000;
 reg [15:0] slot_hold=0;
 reg [10:0] len_hold=0;
 reg [2:0] op_hold=0;
 function automatic [15:0] command_code(input [2:0] op);
  case(op)
   1:command_code=16'h0184;2:command_code=16'h0188;
   3:command_code=16'h0190;4:command_code=16'h0192;
   default:command_code=16'h0180;
  endcase
 endfunction
 assign ready=state==IDLE;
 always @(posedge clk) begin
  done<=0;events<=0;
  if(reset) begin state<=IDLE;cpu_req<=0;poll_count<=1;error<=0;elapsed<=0;end
  else begin
   poll_count<=poll_count+1'b1;
   if(state!=IDLE) elapsed<=elapsed+1'b1;
   case(state)
   IDLE: begin
     elapsed<=0;error<=0;
     if(start) begin
       buffer_hold<=DYNAMIC_BUFFER ? buffer_base:32'h70000000;
       slot_hold<=slot;off_hold<=offset;len_hold<=length;op_hold<=operation;
       phase<=0;poll<=0;state<=ISSUE;
     end else if(poll_count==0) begin poll<=1;state<=ISSUE;end
   end
   ISSUE: begin
     cpu_req<=1;cpu_wstrb<=4'b1111;
     if(poll) begin cpu_addr<=32'h40000080;cpu_wstrb<=0;end
     else case(phase)
       0:begin cpu_addr<=32'h40000020;cpu_data<={16'b0,slot_hold};end
       1:begin cpu_addr<=32'h40000024;cpu_data<=(op_hold==3 || op_hold==4) ? buffer_hold:off_hold;end
       2:begin cpu_addr<=32'h40000028;cpu_data<=buffer_hold;end
       3:begin cpu_addr<=32'h4000002c;cpu_data<={21'b0,len_hold};end
       4:begin cpu_addr<=32'h40000000;cpu_data<={16'h636d,command_code(op_hold)};end
       5:begin cpu_addr<=32'h40000000;cpu_wstrb<=0;end
       default:cpu_wstrb<=0;
     endcase
     state<=ACK;
   end
   ACK: if(cpu_ack) begin result<=cpu_rdata;cpu_req<=0;gap<=0;state<=GAP;end
   GAP: if(gap==8) state<=ADVANCE;else gap<=gap+1'b1;
   ADVANCE: begin
     if(poll) begin events<=result[7:0];state<=IDLE;end
     else if(phase==5) begin
       if(result[31:16]==16'h6f6b) begin
         error<=op_hold==4 ? result[15:0]>1:result[15:0]!=0;done<=1;state<=IDLE;
       end else state<=ISSUE;
     end else begin phase<=phase+1'b1;state<=ISSUE;end
   end
   endcase
   if(state!=IDLE && elapsed==TIMEOUT-1) begin
     cpu_req<=0;error<=1;done<=1;state<=IDLE;
   end
  end
 end
endmodule
