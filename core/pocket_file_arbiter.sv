// SPDX-License-Identifier: MIT
// Exactly one APF reader/poller. Grants precede client start; all command
// parameters and response ownership remain fixed until that request completes.
module pocket_file_arbiter(
 input wire clk,reset,input wire [2:0] start,output wire [2:0] ready,done,error,
 input wire [8:0] operation,input wire [47:0] slot,input wire [95:0] offset,
 input wire [32:0] length,output wire [7:0] events,
 output wire cpu_req,output wire [31:0] cpu_addr,cpu_data,output wire [3:0] cpu_wstrb,
 input wire cpu_ack,input wire [31:0] cpu_rdata
);
 reg [1:0] grant_owner=0,response_owner=0;
 reg active=0;
 wire rready,rdone,rerror;
 wire accept=!active && rready && start[grant_owner];
 assign ready=(!active && rready) ? (3'b001<<grant_owner):3'b0;
 assign done=(active && rdone) ? (3'b001<<response_owner):3'b0;
 assign error=(active && rdone && rerror) ? (3'b001<<response_owner):3'b0;
 always @(posedge clk)begin
  if(reset)begin grant_owner<=0;response_owner<=0;active<=0;end
  else if(accept)begin response_owner<=grant_owner;active<=1;end
  else if(active && rdone)begin active<=0;grant_owner<=response_owner==2 ? 0:response_owner+1'b1;end
  else if(!active && rready)grant_owner<=grant_owner==2 ? 0:grant_owner+1'b1;
 end
 pocket_file_reader #(.DYNAMIC_BUFFER(1)) reader(.clk(clk),.reset(reset),.start(accept),
  .buffer_base(32'h70000000+({30'b0,grant_owner}<<10)),
  .operation(operation[grant_owner*3 +:3]),.slot(slot[grant_owner*16 +:16]),
  .offset(offset[grant_owner*32 +:32]),.length(length[grant_owner*11 +:11]),
  .ready(rready),.done(rdone),.error(rerror),.events(events),.cpu_req(cpu_req),
  .cpu_addr(cpu_addr),.cpu_data(cpu_data),.cpu_wstrb(cpu_wstrb),.cpu_ack(cpu_ack),.cpu_rdata(cpu_rdata));
endmodule
