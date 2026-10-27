// SPDX-License-Identifier: MIT
// Bundled-data CDC: payload stays fixed until the return acknowledgement.
module pocket_mailbox #(parameter WIDTH=26)(
 input wire src_clk,src_reset,input wire src_valid,
 input wire [WIDTH-1:0] src_data,output reg src_done=0,
 input wire dst_clk,dst_reset,output wire dst_valid,
 output wire [WIDTH-1:0] dst_data,input wire dst_ready
);
 reg [WIDTH-1:0] payload_hold=0;
 reg request_toggle=0,ack_toggle=0,busy=0,consumed=0;
 (* async_reg="true" *) reg ack_meta=0,ack_sync=0,req_meta=0,req_sync=0;
 assign dst_valid=req_sync!=ack_toggle;
 assign dst_data=payload_hold;
 always @(posedge src_clk) begin
   ack_meta<=ack_toggle; ack_sync<=ack_meta; src_done<=0;
   if(src_reset) begin request_toggle<=0;busy<=0;consumed<=0; end
   else begin
     if(!src_valid) consumed<=0;
     if(!busy && src_valid && !consumed) begin
       payload_hold<=src_data;request_toggle<=~request_toggle;
       busy<=1;consumed<=1;
     end
     if(busy && ack_sync==request_toggle) begin busy<=0;src_done<=1; end
   end
 end
 always @(posedge dst_clk) begin
   req_meta<=request_toggle;req_sync<=req_meta;
   if(dst_reset) ack_toggle<=0;
   else if(dst_valid && dst_ready) ack_toggle<=req_sync;
 end
endmodule
