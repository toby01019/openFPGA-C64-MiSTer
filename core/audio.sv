// SPDX-License-Identifier: MIT
// 48 kHz, 16-bit stereo I2S in the 74.25 MHz domain. No internal audio clocks.
module pocket_audio(input wire clk74,reset74,input wire core_clk,core_reset,
 input wire [17:0] left,right,output reg mclk=0,output reg lrck=0,output reg dac=0);
 reg [26:0] accumulator=0;
 reg [1:0] divider=0;
 reg [5:0] bit_index=63;
 reg [15:0] frame_l=0,frame_r=0;
 reg request_toggle=0,ack_toggle=0;
 reg [31:0] sample_hold=0,sample_ready=0;
 (* async_reg="true" *) reg req_meta=0,req_sync=0,ack_meta=0,ack_sync=0;
 reg ack_seen=0;
 always @(posedge core_clk) begin
   req_meta<=request_toggle;req_sync<=req_meta;
   if(core_reset) begin ack_toggle<=0;sample_hold<=0;end
   else if(req_sync!=ack_toggle) begin
     sample_hold<={left[17:2],right[17:2]};ack_toggle<=req_sync;
   end
 end
 always @(posedge clk74) begin
   ack_meta<=ack_toggle;ack_sync<=ack_meta;
   if(reset74) begin
     request_toggle<=0;ack_seen<=0;sample_ready<=0;
   end else begin
     if(ack_sync!=ack_seen) begin sample_ready<=sample_hold;ack_seen<=ack_sync;end
   end
   if(accumulator>=74250000-24576000) begin
     accumulator<=accumulator+24576000-74250000;
     mclk<=~mclk;
     // The Pocket reconstructs SCLK from MCLK. Keep its /4 phase and the
     // 64-bit stereo frame running across core resets, just like MCLK.
     // Mute only at the next frame boundary; never truncate a channel.
     if(!mclk) begin
       divider<=divider+1'b1;
       if(divider==3) begin
         bit_index<=bit_index+1'b1;
         // bit_index is the previous bit; count 0 is the I2S one-bit delay.
         if(bit_index==63) begin
           lrck<=0;dac<=0;
           frame_l<=reset74 ? 16'b0:sample_ready[31:16];
           frame_r<=reset74 ? 16'b0:sample_ready[15:0];
           if(!reset74 && ack_sync==request_toggle) request_toggle<=~request_toggle;
         end else if(bit_index==31) begin lrck<=1;dac<=0;end
         else if(bit_index<16) dac<=frame_l[15-bit_index];
         else if(bit_index>=32 && bit_index<48) dac<=frame_r[47-bit_index];
         else dac<=0;
       end
     end
   end else accumulator<=accumulator+24576000;
 end
endmodule
