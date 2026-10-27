// SPDX-License-Identifier: MIT
// Paused track readback -> bounded APF write chunks -> mandatory flush.
// write_limit is the exclusive end of the EXISTING destination track region.
// The caller must hold the drive paused and own the file buffer for all busy.
// done pulses only after a successful flush. Errors latch until next start.
module pocket_track_save(
 input wire clk,reset,start,input wire [1:0] format,input wire [6:0] half_track,
 input wire [15:0] raw_length,input wire [31:0] file_offset,write_limit,
 input wire [7:0] disk_id1,disk_id2,input wire [15:0] slot,
 output reg busy=0,output reg done=0,output reg error=0,output reg [7:0] error_code=0,
 output reg [9:0] track_addr=0,input wire [63:0] track_q,
 output reg buffer_we=0,output reg [7:0] buffer_addr=0,output reg [31:0] buffer_data=0,
 output wire io_start,input wire io_ready,io_done,io_error,
 output reg [2:0] io_operation=0,output reg [15:0] io_slot=0,
 output reg [31:0] io_offset=0,output reg [10:0] io_length=0
);
 localparam IDLE=0,VALIDATE=1,READ_ADDR=2,READ_WAIT1=3,READ_WAIT2=4,READ_WAIT3=5,
  READ_SAMPLE=6,READ_BYTE=7,DECODE_OUTPUT=8,WRITE_GAP=9,IO_REQUEST=10,IO_WAIT=11,
  FLUSH_SETUP=12,FAIL=13;
 reg [3:0] state=IDLE;
 reg [1:0] format_hold=0;
 reg [6:0] half_hold=0;
 reg [7:0] id1_hold=0,id2_hold=0;
 reg [15:0] raw_hold=0,total_length=0,written=0,source_index=0;
 reg [31:0] offset_hold=0,limit_hold=0;
 reg [7:0] current_byte=0,header_low=0;
 reg second_turn=0,decoder_start=0;
 reg [1:0] pack_count=0;
 reg [31:0] pack_word=0;
 reg [7:0] buffer_index=0;
 reg [10:0] chunk_count=0,chunk_size=0;
 wire decoder_in_ready,decoder_out_valid,decoder_busy,decoder_done,decoder_error;
 wire [7:0] decoder_out_data,decoder_error_code;
 wire [5:0] full_track=half_hold[6:1]+6'd1;
 wire decoder_in_valid=state==READ_BYTE && format_hold==1 && source_index>=2;
 wire decoder_in_last=second_turn && source_index==raw_hold+16'd1;
 pocket_gcr_d64 decoder(.clk(clk),.reset(reset || state==IDLE),.start(decoder_start),
  .track(full_track),.disk_id1(id1_hold),.disk_id2(id2_hold),
  .in_valid(decoder_in_valid),.in_data(current_byte),.in_last(decoder_in_last),.in_ready(decoder_in_ready),
  .out_valid(decoder_out_valid),.out_data(decoder_out_data),.out_ready(state==DECODE_OUTPUT),
  .busy(decoder_busy),.done(decoder_done),.error(decoder_error),.error_code(decoder_error_code));
 wire pack_valid=(state==READ_BYTE && format_hold==2 && source_index>=2) ||
                 (state==DECODE_OUTPUT && decoder_out_valid);
 wire [7:0] pack_byte=format_hold==2 ? current_byte:decoder_out_data;
 reg [31:0] pack_value;
 always @*begin pack_value=pack_word;pack_value[{pack_count,3'b0} +:8]=pack_byte;end
 wire [32:0] final_offset={1'b0,offset_hold}+{17'b0,total_length};
 assign io_start=state==IO_REQUEST && io_ready;
 function automatic [15:0] d64_bytes(input [5:0] track);
  if(track<=17)d64_bytes=5376;
  else if(track<=24)d64_bytes=4864;
  else if(track<=30)d64_bytes=4608;
  else d64_bytes=4352;
 endfunction
 always @(posedge clk)begin
  done<=0;buffer_we<=0;decoder_start<=0;
  if(reset)begin state<=IDLE;busy<=0;error<=0;error_code<=0;io_operation<=0;end
  else begin
   case(state)
    IDLE:if(start)begin
     busy<=1;error<=0;error_code<=0;format_hold<=format;half_hold<=half_track;
     raw_hold<=raw_length;offset_hold<=file_offset;limit_hold<=write_limit;
     id1_hold<=disk_id1;id2_hold<=disk_id2;io_slot<=slot;
     source_index<=0;second_turn<=0;written<=0;chunk_count<=0;
     pack_count<=0;pack_word<=0;buffer_index<=0;
     total_length<=format==1 ? d64_bytes(half_track[6:1]+6'd1):raw_length+16'd2;
     state<=VALIDATE;
    end
    VALIDATE:begin
     if(format_hold!=1 && format_hold!=2)begin error_code<=1;state<=FAIL;end
     else if(raw_hold>8190 || (raw_hold!=0 && raw_hold<=6000) ||
             (format_hold==1 && (raw_hold==0 || half_hold[0] || half_hold>=84)))begin error_code<=2;state<=FAIL;end
     else if(final_offset>{1'b0,limit_hold} || final_offset[32] || limit_hold<offset_hold)begin error_code<=3;state<=FAIL;end
     else begin chunk_size<=total_length>1024 ? 11'd1024:total_length[10:0];state<=READ_ADDR;end
    end
    READ_ADDR:begin track_addr<=source_index[12:3];state<=READ_WAIT1;end
    READ_WAIT1:state<=READ_WAIT2;
    READ_WAIT2:state<=READ_WAIT3;
    READ_WAIT3:state<=READ_SAMPLE;
    READ_SAMPLE:begin current_byte<=track_q >> {source_index[2:0],3'b0};state<=READ_BYTE;end
    READ_BYTE:begin
     if(source_index==0)begin header_low<=current_byte;source_index<=1;state<=READ_ADDR;end
     else if(source_index==1)begin
      if({current_byte,header_low}!=raw_hold)begin error_code<=4;state<=FAIL;end
      else if(format_hold==1)begin decoder_start<=1;source_index<=2;state<=READ_ADDR;end
      else if(raw_hold==0)begin
       buffer_we<=1;buffer_addr<=0;buffer_data<=0;written<=2;
       io_operation<=1;io_offset<=offset_hold;io_length<=2;state<=WRITE_GAP;
      end else begin
       pack_word<={16'b0,raw_hold};pack_count<=2;chunk_count<=2;
       source_index<=2;state<=READ_ADDR;
      end
     end else if(format_hold==1 && decoder_in_ready)begin
      if(source_index==raw_hold+16'd1)begin
       if(second_turn)state<=DECODE_OUTPUT;
       else begin second_turn<=1;source_index<=2;state<=READ_ADDR;end
      end else begin source_index<=source_index+1'b1;state<=READ_ADDR;end
     end
    end
    DECODE_OUTPUT:if(decoder_done && decoder_error)begin error_code<=8'h20|decoder_error_code;state<=FAIL;end
    WRITE_GAP:state<=IO_REQUEST;
    IO_REQUEST:if(io_ready)state<=IO_WAIT;
    IO_WAIT:if(io_done)begin
     if(io_error)begin error_code<=io_operation==2 ? 7:6;state<=FAIL;end
     else if(io_operation==2)begin done<=1;busy<=0;state<=IDLE;end
     else if(written==total_length)state<=FLUSH_SETUP;
     else begin
      chunk_size<=total_length-written>1024 ? 11'd1024:11'(total_length-written);
      state<=format_hold==2 ? READ_ADDR:DECODE_OUTPUT;
     end
    end
    FLUSH_SETUP:begin io_operation<=2;io_offset<=0;io_length<=0;state<=IO_REQUEST;end
    FAIL:begin busy<=0;error<=1;state<=IDLE;end
    default:begin error_code<=8'hff;state<=FAIL;end
   endcase
   if(pack_valid)begin
    if(format_hold==2)begin source_index<=source_index+1'b1;state<=READ_ADDR;end
    chunk_count<=chunk_count+1'b1;
    if(pack_count==3)begin
     buffer_we<=1;buffer_addr<=buffer_index;buffer_data<=pack_value;
     buffer_index<=buffer_index+1'b1;pack_count<=0;pack_word<=0;
    end else begin pack_count<=pack_count+1'b1;pack_word<=pack_value;end
    if(chunk_count+1'b1==chunk_size)begin
     if(pack_count!=3)begin buffer_we<=1;buffer_addr<=buffer_index;buffer_data<=pack_value;end
     pack_count<=0;pack_word<=0;buffer_index<=0;chunk_count<=0;
     written<=written+{5'b0,chunk_size};io_operation<=1;
     io_offset<=offset_hold+{16'b0,written};io_length<=chunk_size;state<=WRITE_GAP;
    end
   end
  end
 end
endmodule
