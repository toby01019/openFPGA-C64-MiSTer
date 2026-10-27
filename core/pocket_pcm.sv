// SPDX-License-Identifier: MIT
// TobyPink Pocket extension: two signed LE16 one-shot voices, backed by REU RAM.
// Compatible subset of Ultimate Audio's register layout, NOT its host file API.
// DF18..1B = 'P','K',version,bank-ready. DF20/40 = voice register blocks.
// Register format reference: https://1541ultimate.net/content/download/ultimate_audio_v0.2.pdf
module pocket_pcm #(parameter CLOCK_HZ=31527954, SAMPLE_CLOCK_HZ=6250000)(
 input wire clk,reset,enabled,paused,bank_valid,
 input wire [20:0] bank_size,
 input wire io_select,io_write,input wire [7:0] io_addr,io_data,
 output wire io_claim,output reg [7:0] io_q,
 output wire ram_start,output wire [23:0] ram_addr,
 input wire ram_ready,ram_done,input wire [7:0] ram_data,
 input wire signed [17:0] sid_left,sid_right,
 output wire signed [17:0] left,right,
 output reg underrun=0
);
 reg old_io=0;
 wire write_reg=io_select && !old_io && io_write && enabled;
 wire voice=io_addr[6];
 wire voice_address=(io_addr[7:5]==1 || io_addr[7:5]==2);
 assign io_claim=enabled && io_select && (io_addr>=8'h18 && io_addr<8'h60);
 always @* case(io_addr)
  8'h18:io_q=8'h50;8'h19:io_q=8'h4b;8'h1a:io_q=1;
  8'h1b:io_q={7'b0,bank_valid};8'h21:io_q=8'h10;
  default:io_q=0;
 endcase
 reg [23:0] base[0:1],length[0:1];
 reg [7:0] region[0:1];
 reg [15:0] rate[0:1],timer[0:1];
 reg [5:0] volume[0:1];reg [3:0] pan[0:1];
 reg [20:0] position[0:1],remaining[0:1];
 reg [1:0] active=0,next_valid=0;
 reg signed [15:0] sample[0:1],next_sample[0:1];
 reg [25:0] phase=0;
 wire sample_tick=phase>=CLOCK_HZ-SAMPLE_CLOCK_HZ;
 reg pending=0,owner=0,high_byte=0,last_owner=1,discard=0;
 reg [7:0] low_byte=0;
 wire need0=active[0] && !next_valid[0] && remaining[0]>=2;
 wire need1=active[1] && !next_valid[1] && remaining[1]>=2;
 wire chosen=high_byte ? owner:need1 && (!need0 || !last_owner);
 wire restart_owner=write_reg && voice_address && io_addr[4:0]==0 && voice==owner;
 wire changing=write_reg && voice_address && io_addr[4:0]==0;
 wire issue=!reset && enabled && !pending && ram_ready && (high_byte || need0 || need1) && !changing;
 assign ram_start=issue;
 assign ram_addr={3'b0,position[chosen]};
 integer i;
 initial begin
  for(i=0;i<2;i=i+1)begin
   base[i]=0;length[i]=0;region[i]=1;rate[i]=283;timer[i]=0;
   volume[i]=63;pan[i]=8;position[i]=0;remaining[i]=0;sample[i]=0;next_sample[i]=0;
  end
 end
 always @(posedge clk)begin
  old_io<=io_select;
  if(reset || !enabled)begin
   active<=0;next_valid<=0;phase<=0;sample[0]<=0;sample[1]<=0;underrun<=0;
   // A memory operation may outlive a C64 soft reset. Drain its result.
   if(pending)begin discard<=1;if(ram_done)pending<=0;end
   high_byte<=0;
  end else begin
   if(sample_tick)phase<=phase+SAMPLE_CLOCK_HZ-CLOCK_HZ;
   else phase<=phase+SAMPLE_CLOCK_HZ;
   if(issue)begin pending<=1;owner<=chosen;last_owner<=chosen;discard<=0;end
   if(pending && ram_done)begin
    pending<=0;
    if(!discard && !restart_owner && active[owner])begin
     position[owner]<=position[owner]+1'b1;
     remaining[owner]<=remaining[owner]-1'b1;
     if(high_byte)begin next_sample[owner]<={ram_data,low_byte};next_valid[owner]<=1;high_byte<=0;end
     else begin low_byte<=ram_data;high_byte<=1;end
    end else high_byte<=0;
   end
   if(sample_tick && !paused)for(i=0;i<2;i=i+1)if(active[i])begin
    if(timer[i]!=0)timer[i]<=timer[i]-1'b1;
    else if(next_valid[i])begin sample[i]<=next_sample[i];next_valid[i]<=0;timer[i]<=rate[i]-1'b1;end
    else if(remaining[i]==0)begin active[i]<=0;sample[i]<=0;end
    else underrun<=1;
   end
   if(write_reg && voice_address)case(io_addr[4:0])
    0:begin
     active[voice]<=0;sample[voice]<=0;next_valid[voice]<=0;timer[voice]<=rate[voice]-1'b1;
     position[voice]<=base[voice][20:0];remaining[voice]<=length[voice][20:0];
     if(pending && owner==voice)discard<=1;
     // The other voice may be between its low- and high-byte reads.
     // Starting/stopping this voice must not discard that partial word.
     if(owner==voice)high_byte<=0;
     // Only mode 01, one-shot, no interleave, no IRQ is advertised/supported.
     if(io_data==8'h11 && bank_valid && region[voice]==1 && rate[voice]!=0 &&
        base[voice][23:20]==0 && length[voice]>=2 && !length[voice][0] &&
        {1'b0,base[voice]}+{1'b0,length[voice]}<={4'b0,bank_size})active[voice]<=1;
    end
    1:volume[voice]<=io_data[5:0];2:pan[voice]<=io_data[3:0];
    4:region[voice]<=io_data;5:base[voice][23:16]<=io_data;6:base[voice][15:8]<=io_data;7:base[voice][7:0]<=io_data;
    9:length[voice][23:16]<=io_data;10:length[voice][15:8]<=io_data;11:length[voice][7:0]<=io_data;
    14:rate[voice][15:8]<=io_data;15:rate[voice][7:0]<=io_data;
    default:;
   endcase
  end
 end
 // Pans 7 and 8 are the documented centre positions; endpoints are hard L/R.
 wire [4:0] pr0=pan[0]<7 ? {1'b0,pan[0]}:pan[0]<9 ? 5'd8:{1'b0,pan[0]}+1'b1;
 wire [4:0] pr1=pan[1]<7 ? {1'b0,pan[1]}:pan[1]<9 ? 5'd8:{1'b0,pan[1]}+1'b1;
 wire [4:0] pl0=16-pr0,pl1=16-pr1;
 wire signed [22:0] v0=sample[0]*$signed({1'b0,volume[0]});
 wire signed [22:0] v1=sample[1]*$signed({1'b0,volume[1]});
 wire signed [28:0] l0=v0*$signed({1'b0,pl0}),r0=v0*$signed({1'b0,pr0});
 wire signed [28:0] l1=v1*$signed({1'b0,pl1}),r1=v1*$signed({1'b0,pr1});
 wire signed [20:0] ml=$signed(sid_left)+(l0>>>8)+(l1>>>8);
 wire signed [20:0] mr=$signed(sid_right)+(r0>>>8)+(r1>>>8);
 function automatic signed [17:0] saturate(input signed [20:0] v);
  if(v>131071)saturate=18'sh1ffff;else if(v< -131072)saturate=18'sh20000;else saturate=v[17:0];
 endfunction
 assign left=enabled ? saturate(ml):sid_left;
 assign right=enabled ? saturate(mr):sid_right;
endmodule
