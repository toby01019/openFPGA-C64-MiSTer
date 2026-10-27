// SPDX-License-Identifier: MIT
// Streaming D64 track -> 1541 raw GCR, with a two-byte little-endian length.
// Layout matches MiSTer Main's c64_synthesize_gcr_track (support/c64/c64.cpp):
// 5 sync, 10 encoded header, 9 gap, 5 sync, 325 encoded data, zone gap.
// Input is sector 0..N-1, 256 bytes each. D64 error tables are not consumed.
// Hold valid/data until ready. Both streams may stall for an arbitrary time.
module pocket_d64_gcr(
 input wire clk,reset,start,
 input wire [5:0] track,
 input wire [7:0] disk_id1,disk_id2,
 input wire in_valid,input wire [7:0] in_data,output wire in_ready,
 output reg out_valid,output reg [7:0] out_data,input wire out_ready,
 output reg busy=0,output reg done=0,output reg error=0,
 output reg [15:0] track_length=0
);
 localparam IDLE=0,LENGTH_LO=1,LENGTH_HI=2,HEADER_SYNC=3,HEADER=4,
            HEADER_GAP=5,DATA_SYNC=6,DATA=7,GCR_OUT=8,DATA_GAP=9;
 reg [3:0] state=IDLE,after_emit=IDLE;
 reg [5:0] track_hold=0;
 reg [7:0] id1_hold=0,id2_hold=0,checksum=0;
 reg [4:0] sector=0,sectors=0,gap_length=0,raw_count=0;
 reg [8:0] source_index=0;
 reg [1:0] packed_count=0;
 reg [2:0] emit_count=0;
 reg [39:0] packed_bits=0;
 reg [7:0] source_byte;
 wire data_input=source_index>=9'd1 && source_index<=9'd256;
 assign in_ready=busy && state==DATA && data_input && !reset;

 function automatic [4:0] gcr_nibble(input [3:0] nibble);
  case(nibble)
   0:gcr_nibble=5'h0a;1:gcr_nibble=5'h0b;2:gcr_nibble=5'h12;3:gcr_nibble=5'h13;
   4:gcr_nibble=5'h0e;5:gcr_nibble=5'h0f;6:gcr_nibble=5'h16;7:gcr_nibble=5'h17;
   8:gcr_nibble=5'h09;9:gcr_nibble=5'h19;10:gcr_nibble=5'h1a;11:gcr_nibble=5'h1b;
   12:gcr_nibble=5'h0d;13:gcr_nibble=5'h1d;14:gcr_nibble=5'h1e;15:gcr_nibble=5'h15;
  endcase
 endfunction

 always @* begin
  source_byte=0;
  if(state==HEADER) case(source_index)
   0:source_byte=8'h08;
   1:source_byte={3'b0,sector}^{2'b0,track_hold}^id1_hold^id2_hold;
   2:source_byte={3'b0,sector};
   3:source_byte={2'b0,track_hold};
   4:source_byte=id2_hold;
   5:source_byte=id1_hold;
   default:source_byte=8'h0f;
  endcase
  else if(state==DATA) begin
   if(source_index==0) source_byte=8'h07;
   else if(data_input) source_byte=in_data;
   else if(source_index==257) source_byte=checksum;
  end
  out_valid=0;out_data=0;
  if(!reset) case(state)
   LENGTH_LO:begin out_valid=1;out_data=track_length[7:0];end
   LENGTH_HI:begin out_valid=1;out_data=track_length[15:8];end
   HEADER_SYNC,DATA_SYNC:begin out_valid=1;out_data=8'hff;end
   HEADER_GAP,DATA_GAP:begin out_valid=1;out_data=8'h55;end
   GCR_OUT:begin out_valid=1;out_data=packed_bits[39:32];end
   default:begin end
  endcase
 end

 always @(posedge clk) begin
  done<=0;
  if(reset) begin
   state<=IDLE;busy<=0;error<=0;track_length<=0;
   packed_count<=0;emit_count<=0;source_index<=0;raw_count<=0;checksum<=0;
  end else begin
   case(state)
    IDLE:if(start) begin
     error<=0;sector<=0;raw_count<=0;packed_count<=0;source_index<=0;
     track_hold<=track;id1_hold<=disk_id1;id2_hold<=disk_id2;
     if(track==0 || track>42) begin error<=1;done<=1;track_length<=0;end
     else begin
      busy<=1;state<=LENGTH_LO;
      if(track<=17)begin sectors<=21;gap_length<=8;track_length<=7602;end
      else if(track<=24)begin sectors<=19;gap_length<=17;track_length<=7049;end
      else if(track<=30)begin sectors<=18;gap_length<=12;track_length<=6588;end
      else begin sectors<=17;gap_length<=9;track_length<=6171;end
     end
    end
    LENGTH_LO:if(out_ready)state<=LENGTH_HI;
    LENGTH_HI:if(out_ready)begin state<=HEADER_SYNC;raw_count<=0;end
    HEADER_SYNC:if(out_ready)begin
     if(raw_count==4)begin state<=HEADER;raw_count<=0;source_index<=0;packed_count<=0;end
     else raw_count<=raw_count+1'b1;
    end
    HEADER,DATA:if(state==HEADER || !data_input || in_valid)begin
     packed_bits<={packed_bits[29:0],gcr_nibble(source_byte[7:4]),gcr_nibble(source_byte[3:0])};
     source_index<=source_index+1'b1;
     if(state==DATA && data_input) checksum<=checksum^in_data;
     if(packed_count==3)begin
      packed_count<=0;emit_count<=0;state<=GCR_OUT;
      if(state==HEADER)after_emit<=source_index==7 ? HEADER_GAP:HEADER;
      else after_emit<=source_index==259 ? DATA_GAP:DATA;
     end else packed_count<=packed_count+1'b1;
    end
    GCR_OUT:if(out_ready)begin
     packed_bits<={packed_bits[31:0],8'b0};
     if(emit_count==4)begin state<=after_emit;raw_count<=0;end
     else emit_count<=emit_count+1'b1;
    end
    HEADER_GAP:if(out_ready)begin
     if(raw_count==8)begin state<=DATA_SYNC;raw_count<=0;end
     else raw_count<=raw_count+1'b1;
    end
    DATA_SYNC:if(out_ready)begin
     if(raw_count==4)begin state<=DATA;source_index<=0;packed_count<=0;checksum<=0;raw_count<=0;end
     else raw_count<=raw_count+1'b1;
    end
    DATA_GAP:if(out_ready)begin
     if(raw_count==gap_length-1'b1)begin
      raw_count<=0;
      if(sector==sectors-1'b1)begin state<=IDLE;busy<=0;done<=1;end
      else begin sector<=sector+1'b1;state<=HEADER_SYNC;end
     end else raw_count<=raw_count+1'b1;
    end
    default:begin state<=IDLE;busy<=0;error<=1;done<=1;end
   endcase
  end
 end
endmodule
