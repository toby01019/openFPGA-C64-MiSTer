// SPDX-License-Identifier: MIT
// Validate a raw 1541 GCR track before exposing any bytes for D64 writeback.
// Feed two revolutions, without the little-endian raw length header, and mark
// the final accepted byte with in_last. Bit alignment/track rotation is free.
// A separate sector scratch RAM prevents a bad duplicate from damaging a
// previously valid sector. Output starts only when every sector is verified.
module pocket_gcr_d64(
 input wire clk,reset,start,input wire [5:0] track,
 input wire [7:0] disk_id1,disk_id2,
 input wire in_valid,input wire [7:0] in_data,input wire in_last,output wire in_ready,
 output wire out_valid,output reg [7:0] out_data=0,input wire out_ready,
 output reg busy=0,output reg done=0,output reg error=0,output reg [7:0] error_code=0
);
 localparam IDLE=0,RECEIVE=1,COPY_READ=2,COPY_WRITE=3,CHECK=4,OUT_READ=5,OUT_SEND=6;
 reg [2:0] state=IDLE;
 reg [5:0] track_hold=0;
 reg [7:0] id1_hold=0,id2_hold=0;
 reg [4:0] sectors=0;
 reg [20:0] seen=0,required_mask=0;
 reg [7:0] byte_hold=0;
 reg [3:0] bits_left=0,ones=0;
 reg input_ended=0,collecting=0,low_nibble=0;
 reg [4:0] symbol=0;
 reg [2:0] symbol_bits=0;
 reg [3:0] high_nibble=0;
 reg [1:0] block_kind=0;
 reg [8:0] block_index=0;
 reg [7:0] header_checksum=0,header_sector=0;
 reg header_good=0,header_pending=0,data_good=0;
 reg [4:0] candidate_sector=0;
 reg [7:0] checksum=0,copy_index=0,copy_byte=0;
 reg [12:0] output_index=0,output_size=0;
 (* ramstyle="M10K" *) reg [7:0] sector_scratch[0:255];
 (* ramstyle="M10K" *) reg [7:0] track_ram[0:5375];
 wire serial_bit=byte_hold[7];
 wire [4:0] next_symbol={symbol[3:0],serial_bit};
 function automatic [4:0] decode_symbol(input [4:0] code);
  case(code)
   5'h0a:decode_symbol=5'h10;5'h0b:decode_symbol=5'h11;
   5'h12:decode_symbol=5'h12;5'h13:decode_symbol=5'h13;
   5'h0e:decode_symbol=5'h14;5'h0f:decode_symbol=5'h15;
   5'h16:decode_symbol=5'h16;5'h17:decode_symbol=5'h17;
   5'h09:decode_symbol=5'h18;5'h19:decode_symbol=5'h19;
   5'h1a:decode_symbol=5'h1a;5'h1b:decode_symbol=5'h1b;
   5'h0d:decode_symbol=5'h1c;5'h1d:decode_symbol=5'h1d;
   5'h1e:decode_symbol=5'h1e;5'h15:decode_symbol=5'h1f;
   default:decode_symbol=0;
  endcase
 endfunction
 wire [4:0] decoded=decode_symbol(next_symbol);
 wire [7:0] decoded_byte={high_nibble,decoded[3:0]};
 assign in_ready=state==RECEIVE && bits_left==0 && !input_ended && !reset;
 assign out_valid=state==OUT_SEND && !reset;
 always @(posedge clk)begin
  done<=0;
  if(reset)begin
   state<=IDLE;busy<=0;error<=0;error_code<=0;bits_left<=0;input_ended<=0;
   collecting<=0;ones<=0;header_pending<=0;seen<=0;out_data<=0;
  end else case(state)
   IDLE:if(start)begin
    error<=0;error_code<=0;track_hold<=track;id1_hold<=disk_id1;id2_hold<=disk_id2;
    seen<=0;bits_left<=0;ones<=0;input_ended<=0;collecting<=0;low_nibble<=0;
    header_pending<=0;header_good<=0;data_good<=0;block_index<=0;block_kind<=0;
    if(track==0 || track>42)begin done<=1;error<=1;error_code<=1;end
    else begin
     state<=RECEIVE;busy<=1;
     if(track<=17)begin sectors<=21;required_mask<=21'h1fffff;output_size<=5376;end
     else if(track<=24)begin sectors<=19;required_mask<=21'h07ffff;output_size<=4864;end
     else if(track<=30)begin sectors<=18;required_mask<=21'h03ffff;output_size<=4608;end
     else begin sectors<=17;required_mask<=21'h01ffff;output_size<=4352;end
    end
   end
   RECEIVE:begin
    if(bits_left==0)begin
     if(input_ended)state<=CHECK;
     else if(in_valid)begin byte_hold<=in_data;bits_left<=8;input_ended<=in_last;end
    end else begin
     byte_hold<={byte_hold[6:0],1'b0};bits_left<=bits_left-1'b1;
     if(serial_bit)begin if(ones!=15)ones<=ones+1'b1;end
     else ones<=0;
     if(!serial_bit && ones>=10)begin
      // This zero is already the first bit of the first GCR symbol.
      collecting<=1;symbol<=0;symbol_bits<=1;low_nibble<=0;
      block_index<=0;block_kind<=0;
     end else if(collecting)begin
      symbol<=next_symbol;
      if(symbol_bits==4)begin
       symbol_bits<=0;
       if(!decoded[4])begin collecting<=0;header_pending<=0;end
       else if(!low_nibble)begin high_nibble<=decoded[3:0];low_nibble<=1;end
       else begin
        low_nibble<=0;block_index<=block_index+1'b1;
        if(block_index==0)begin
         if(decoded_byte==8'h08)begin block_kind<=1;header_good<=1;header_pending<=0;end
         else if(decoded_byte==8'h07 && header_pending)begin
          block_kind<=2;candidate_sector<=header_sector[4:0];data_good<=1;
          checksum<=0;header_pending<=0;
         end else begin collecting<=0;header_pending<=0;end
        end else if(block_kind==1)begin
         case(block_index)
          1:header_checksum<=decoded_byte;
          2:begin header_sector<=decoded_byte;if(decoded_byte>={3'b0,sectors})header_good<=0;end
          3:if(decoded_byte!={2'b0,track_hold})header_good<=0;
          4:if(decoded_byte!=id2_hold)header_good<=0;
          5:if(decoded_byte!=id1_hold)header_good<=0;
          6:if(decoded_byte!=8'h0f)header_good<=0;
          7:begin
           header_pending<=header_good && decoded_byte==8'h0f &&
             header_checksum==(header_sector^{2'b0,track_hold}^id1_hold^id2_hold);
           collecting<=0;
          end
          default:collecting<=0;
         endcase
        end else if(block_kind==2)begin
         if(block_index<=256)begin
          sector_scratch[8'(block_index-1'b1)]<=decoded_byte;checksum<=checksum^decoded_byte;
         end else if(block_index==257)begin if(decoded_byte!=checksum)data_good<=0;end
         else if(block_index==258)begin if(decoded_byte!=0)data_good<=0;end
         else begin
          collecting<=0;
          if(data_good && decoded_byte==0)begin copy_index<=0;state<=COPY_READ;end
         end
        end
       end
      end else symbol_bits<=symbol_bits+1'b1;
     end
    end
   end
   COPY_READ:begin copy_byte<=sector_scratch[copy_index];state<=COPY_WRITE;end
   COPY_WRITE:begin
    track_ram[{candidate_sector,copy_index}]<=copy_byte;
    if(copy_index==255)begin seen[candidate_sector]<=1;state<=RECEIVE;end
    else begin copy_index<=copy_index+1'b1;state<=COPY_READ;end
   end
   CHECK:begin
    if(seen!=required_mask)begin error<=1;error_code<=2;done<=1;busy<=0;state<=IDLE;end
    else begin output_index<=0;state<=OUT_READ;end
   end
   OUT_READ:begin out_data<=track_ram[output_index];state<=OUT_SEND;end
   OUT_SEND:if(out_ready)begin
    if(output_index+1'b1==output_size)begin done<=1;busy<=0;state<=IDLE;end
    else begin output_index<=output_index+1'b1;state<=OUT_READ;end
   end
   default:begin state<=IDLE;busy<=0;done<=1;error<=1;error_code<=3;end
  endcase
 end
endmodule
