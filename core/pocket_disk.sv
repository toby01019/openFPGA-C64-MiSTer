// SPDX-License-Identifier: MIT
// Read-only APF disk frontend. Owns the shared table/file buffer while busy.
// D64 -> raw GCR; G64 v0 -> validated raw track. No save/writeback support.
// Error codes: 1=APF read, 2=missing/wrong 1541 ROM, 3=image size/format,
// 4=G64 version/count/maxlen, 5=G64 offset/bounds, 6=variable speed map,
// 7=unsupported raw length, 8=non-normal D64 error table, 9=converter failure.
module pocket_disk #(parameter SESSION=0, parameter IMAGE_SLOT=2, EVENT_BIT=2, ALIAS_SLOT=6, ROM_SLOT=203)(
 input wire clk,reset,enable,input wire [7:0] events,
 input wire image_ready, output wire bind_request,
 output wire [31:0] save_offset,output reg [31:0] save_limit=0, output wire [7:0] save_id1,save_id2,
 input wire [6:0] head_track,input wire need_track,
 output reg busy=0,output reg pause_request=0,input wire paused,
 output reg mounted=0,output reg rom_loaded=0,
 output reg rom_we=0,output reg [13:0] rom_addr=0,output reg [7:0] rom_data=0,
 output reg track_we=0,output reg [9:0] track_addr=0,output reg [63:0] track_data=0,
 output reg commit_toggle=0,output reg [6:0] loaded_track=0,
 output wire read_start,input wire read_ready,read_done,read_error,
 output reg [15:0] read_slot=0,output reg [31:0] read_offset=0,
 output reg [10:0] read_length=0,
 output wire [7:0] buffer_addr,input wire [31:0] buffer_data,
 output reg [5:0] table_addr=0,input wire [31:0] table_data,
 output reg [7:0] error_code=0,output wire [7:0] debug_state,
 output reg [1:0] format=0,output reg [15:0] track_len=0
);
 localparam IDLE=0,TABLE_REQ=1,TABLE_WAIT=2,TABLE_ID=3,TABLE_SIZE_WAIT=4,TABLE_SIZE=5,
  REQUEST=6,WAIT_READ=7,FETCH=8,FETCH_WAIT=9,BYTE=10,NEXT_BYTE=11,STREAM_DONE=12,
  CLASSIFY=13,G64_VALIDATE=14,D64_IDS=15,TRACK_BEGIN=16,WAIT_PAUSE=17,
  TRACK_SELECT=18,G64_LENGTH_CHECK=19,D64_WAIT=20,EMPTY=21,FLUSH=22,
  COMMIT_WAIT1=23,COMMIT_WAIT2=24,COMMIT=25,RELEASE=26,FAIL=27;
 localparam ROM=0,PROBE=1,G64_TABLE=2,D64_ERRORS=3,IDS=4,G64_LENGTH=5,G64_TRACK=6,D64_TRACK=7;
 reg [7:0] state=IDLE;
 reg [2:0] kind=ROM;
 reg pending=0,boot_checked=0,table_rom=1;
 reg [4:0] table_index=0;
 reg [31:0] file_size=0,bytes_left=0,stream_pos=0,d64_bytes=0;
 reg [10:0] index=0;
 reg [7:0] current_byte=0;
 reg [63:0] magic=0;
 reg [7:0] version=0,g64_count=0;
 reg [15:0] g64_max=0;
 (* ramstyle="M10K" *) reg [31:0] offsets[0:127];
 reg [31:0] selected_offset;
 reg [31:0] field_word=0;
 reg [5:0] d64_tracks=0;
 reg [7:0] id1=0,id2=0;
 reg [6:0] head_latched=0;
 reg [31:0] track_offset=0;
 reg [2:0] pack_count=0;
 reg [63:0] pack_word=0;
 reg [9:0] word_index=0;
 reg d64_start=0;
 wire d64_in_ready,d64_out_valid,d64_busy,d64_done,d64_error;
 wire [7:0] d64_out_data;
 wire [15:0] d64_length;
 wire [5:0] full_track=head_latched[6:1]+6'd1;
 wire d64_in_valid=state==BYTE && kind==D64_TRACK;
 wire d64_out_ready=busy && pause_request && paused && kind==D64_TRACK;
 pocket_d64_gcr converter(.clk(clk),.reset(reset || state==FAIL),.start(d64_start),
  .track(full_track),.disk_id1(id1),.disk_id2(id2),
  .in_valid(d64_in_valid),.in_data(current_byte),.in_ready(d64_in_ready),
  .out_valid(d64_out_valid),.out_data(d64_out_data),.out_ready(d64_out_ready),
  .busy(d64_busy),.done(d64_done),.error(d64_error),.track_length(d64_length));
 wire pack_valid=(state==BYTE && kind==G64_TRACK) ||
                 (d64_out_valid && d64_out_ready) || state==EMPTY;
 wire [7:0] pack_byte=state==EMPTY ? 8'b0:
                      (kind==D64_TRACK ? d64_out_data:current_byte);
 reg [63:0] pack_value;
 always @* begin
  pack_value=pack_word;pack_value[{pack_count,3'b0} +:8]=pack_byte;
 end
 wire [31:0] assembled_field={current_byte,field_word[23:0]};
 wire [7:0] table_entry=stream_pos[9:2];
 wire [31:0] g64_table_end=32'd12+({24'b0,g64_count}<<3);
 assign bind_request=state==TABLE_SIZE && !table_rom && table_data>=12;
 // Offset is captured during TRACK_SELECT, well before commit. Register
 // the end bound separately: avoid D64 multiply + two adders in one host tick.
 assign save_offset=track_offset;
 assign save_id1=id1;
 assign save_id2=id2;
 // Head is latched before TRACK_BEGIN/WAIT_PAUSE, so this registered
 // lookup is settled before TRACK_SELECT. Keep the table in M10K, not FFs.
 always @(posedge clk)begin
  selected_offset<=offsets[head_latched];
  if(state==BYTE && kind==G64_TABLE && stream_pos[1:0]==3 && table_entry<g64_count)
   offsets[table_entry[6:0]]<=assembled_field;
 end
 assign read_start=state==REQUEST && read_ready;
 assign buffer_addr=index[9:2];
 assign debug_state=state;
 function automatic [31:0] d64_offset(input [5:0] zero_track);
  reg [9:0] sector_offset;
  begin
   // Exact zoned geometry: avoid a wide multiply/add/mux path at 74.25 MHz.
   case(zero_track)
   6'd0:sector_offset=10'd0;
   6'd1:sector_offset=10'd21;
   6'd2:sector_offset=10'd42;
   6'd3:sector_offset=10'd63;
   6'd4:sector_offset=10'd84;
   6'd5:sector_offset=10'd105;
   6'd6:sector_offset=10'd126;
   6'd7:sector_offset=10'd147;
   6'd8:sector_offset=10'd168;
   6'd9:sector_offset=10'd189;
   6'd10:sector_offset=10'd210;
   6'd11:sector_offset=10'd231;
   6'd12:sector_offset=10'd252;
   6'd13:sector_offset=10'd273;
   6'd14:sector_offset=10'd294;
   6'd15:sector_offset=10'd315;
   6'd16:sector_offset=10'd336;
   6'd17:sector_offset=10'd357;
   6'd18:sector_offset=10'd376;
   6'd19:sector_offset=10'd395;
   6'd20:sector_offset=10'd414;
   6'd21:sector_offset=10'd433;
   6'd22:sector_offset=10'd452;
   6'd23:sector_offset=10'd471;
   6'd24:sector_offset=10'd490;
   6'd25:sector_offset=10'd508;
   6'd26:sector_offset=10'd526;
   6'd27:sector_offset=10'd544;
   6'd28:sector_offset=10'd562;
   6'd29:sector_offset=10'd580;
   6'd30:sector_offset=10'd598;
   6'd31:sector_offset=10'd615;
   6'd32:sector_offset=10'd632;
   6'd33:sector_offset=10'd649;
   6'd34:sector_offset=10'd666;
   6'd35:sector_offset=10'd683;
   6'd36:sector_offset=10'd700;
   6'd37:sector_offset=10'd717;
   6'd38:sector_offset=10'd734;
   6'd39:sector_offset=10'd751;
   6'd40:sector_offset=10'd768;
   6'd41:sector_offset=10'd785;
   6'd42:sector_offset=10'd802;
    default:sector_offset=0;
   endcase
   d64_offset={14'b0,sector_offset,8'b0};
  end
 endfunction
 function automatic [13:0] d64_input_size(input [5:0] one_track);
  if(one_track<=17)d64_input_size=5376;
  else if(one_track<=24)d64_input_size=4864;
  else if(one_track<=30)d64_input_size=4608;
  else d64_input_size=4352;
 endfunction

 always @(posedge clk)begin
  rom_we<=0;track_we<=0;d64_start<=0;
  if(reset)begin
   state<=IDLE;busy<=0;pause_request<=0;mounted<=0;rom_loaded<=0;
   pending<=0;boot_checked<=0;commit_toggle<=0;loaded_track<=0;error_code<=0;format<=0;
   pack_count<=0;pack_word<=0;word_index<=0;track_len<=0;table_addr<=0;save_limit<=0;
  end else begin
   if(events[EVENT_BIT])pending<=1;
   if(pack_valid)begin
    if(pack_count==7)begin
     track_we<=1;track_addr<=word_index;track_data<=pack_value;
     word_index<=word_index+1'b1;pack_count<=0;pack_word<=0;
    end else begin pack_count<=pack_count+1'b1;pack_word<=pack_value;end
   end
   case(state)
    IDLE:if(enable)begin
     if(!boot_checked || pending)begin
      busy<=1;mounted<=0;format<=0;error_code<=0;pending<=events[EVENT_BIT];
      table_index<=0;table_rom<=!rom_loaded;read_slot<=rom_loaded ? 16'(IMAGE_SLOT):16'(ROM_SLOT);
      head_latched<=head_track;state<=TABLE_REQ;
     end else if(mounted && rom_loaded && need_track)begin
      busy<=1;error_code<=0;head_latched<=head_track;state<=TRACK_BEGIN;
     end
    end
    TABLE_REQ:begin table_addr<={table_index,1'b0};state<=TABLE_WAIT;end
    TABLE_WAIT:state<=TABLE_ID;
    TABLE_ID:if(table_data[15:0]==read_slot)begin
     table_addr<={table_index,1'b1};state<=TABLE_SIZE_WAIT;
    end else if(table_index==31)begin
     if(table_rom)begin error_code<=2;state<=FAIL;end
     else begin mounted<=0;state<=RELEASE;end
    end else begin table_index<=table_index+1'b1;state<=TABLE_REQ;end
    TABLE_SIZE_WAIT:state<=TABLE_SIZE;
    TABLE_SIZE:begin
     index<=0;stream_pos<=0;read_offset<=0;
     if(table_rom)begin
      if(table_data!=16384)begin error_code<=2;state<=FAIL;end
      else begin kind<=ROM;bytes_left<=16384;read_length<=1024;state<=REQUEST;end
     end else if(table_data==0)begin mounted<=0;format<=0;state<=RELEASE;end
     else if(table_data<12)begin error_code<=3;state<=FAIL;end
     else if(!SESSION || image_ready)begin
      read_slot<=SESSION ? 16'(ALIAS_SLOT):16'(IMAGE_SLOT);
      file_size<=table_data;kind<=PROBE;bytes_left<=12;read_length<=12;
      magic<=0;g64_max<=0;state<=REQUEST;
     end
    end
    REQUEST:if(read_ready)state<=WAIT_READ;
    WAIT_READ:if(read_done)begin
     if(read_error)begin error_code<=1;state<=FAIL;end
     else begin index<=0;state<=FETCH;end
    end
    FETCH:state<=FETCH_WAIT;
    FETCH_WAIT:begin current_byte<=buffer_data >> {index[1:0],3'b0};state<=BYTE;end
    BYTE:begin
     if(kind!=D64_TRACK || d64_in_ready)begin
      state<=NEXT_BYTE;
      case(kind)
       ROM:begin rom_we<=1;rom_addr<=stream_pos[13:0];rom_data<=current_byte;end
       PROBE:begin
        if(stream_pos<8)magic<={magic[55:0],current_byte};
        else if(stream_pos==8)version<=current_byte;
        else if(stream_pos==9)g64_count<=current_byte;
        else if(stream_pos==10)g64_max[7:0]<=current_byte;
        else g64_max[15:8]<=current_byte;
       end
       G64_TABLE:begin
        field_word[{stream_pos[1:0],3'b0} +:8]<=current_byte;
        if(stream_pos[1:0]==3)begin
         if(table_entry<g64_count)begin
          if(assembled_field!=0 && (assembled_field<g64_table_end || assembled_field>file_size-2))begin error_code<=5;state<=FAIL;end
         end else if(assembled_field>3)begin error_code<=6;state<=FAIL;end
        end
       end
       D64_ERRORS:if(current_byte!=1)begin error_code<=8;state<=FAIL;end
       IDS:if(stream_pos==0)id1<=current_byte;else id2<=current_byte;
       G64_LENGTH:if(stream_pos==0)track_len[7:0]<=current_byte;else track_len[15:8]<=current_byte;
       default:begin end
      endcase
     end
    end
    NEXT_BYTE:begin
     stream_pos<=stream_pos+1'b1;
     if(index+1'b1==read_length)begin
      if(bytes_left=={21'b0,read_length})state<=STREAM_DONE;
      else begin
       bytes_left<=bytes_left-{21'b0,read_length};read_offset<=read_offset+{21'b0,read_length};
       read_length<=bytes_left-{21'b0,read_length}>1024 ? 11'd1024:11'(bytes_left-{21'b0,read_length});
       state<=REQUEST;
      end
     end else begin index<=index+1'b1;state<=FETCH;end
    end
    STREAM_DONE:case(kind)
     ROM:begin
      rom_loaded<=1;boot_checked<=1;table_rom<=0;table_index<=0;read_slot<=16'(IMAGE_SLOT);state<=TABLE_REQ;
     end
     PROBE:state<=CLASSIFY;
     G64_TABLE:state<=TRACK_BEGIN;
     D64_ERRORS:state<=D64_IDS;
     IDS:state<=TRACK_BEGIN;
     G64_LENGTH:state<=G64_LENGTH_CHECK;
     G64_TRACK:state<=FLUSH;
     D64_TRACK:state<=D64_WAIT;
    endcase
    CLASSIFY:begin
     if(magic=="GCR-1541")begin format<=2;state<=G64_VALIDATE;end
     else if(file_size==174848 || file_size==175531)begin d64_tracks<=35;d64_bytes<=174848;format<=1;state<=D64_IDS;end
     else if(file_size==196608 || file_size==197376)begin d64_tracks<=40;d64_bytes<=196608;format<=1;state<=D64_IDS;end
     else if(file_size==205312 || file_size==206114)begin d64_tracks<=42;d64_bytes<=205312;format<=1;state<=D64_IDS;end
     else begin error_code<=3;state<=FAIL;end
    end
    G64_VALIDATE:begin
     if(version!=0 || g64_count==0 || g64_count>84 || g64_max==0 || g64_max>8190 || g64_table_end>file_size)begin error_code<=4;state<=FAIL;end
     else begin
      kind<=G64_TABLE;read_offset<=12;bytes_left<={24'b0,g64_count}<<3;
      read_length<={3'b0,g64_count}<<3;stream_pos<=0;field_word<=0;state<=REQUEST;
     end
    end
    D64_IDS:begin
     if(file_size!=d64_bytes && kind!=D64_ERRORS)begin
      kind<=D64_ERRORS;read_offset<=d64_bytes;bytes_left<=file_size-d64_bytes;
      read_length<=11'(file_size-d64_bytes);stream_pos<=0;state<=REQUEST;
     end else begin
      kind<=IDS;read_offset<=91554;bytes_left<=2;read_length<=2;stream_pos<=0;state<=REQUEST;
     end
    end
    TRACK_BEGIN:begin pause_request<=1;state<=WAIT_PAUSE;end
    WAIT_PAUSE:if(paused)begin
     pack_count<=0;pack_word<=0;word_index<=0;track_len<=0;save_limit<=0;state<=TRACK_SELECT;
    end
    TRACK_SELECT:begin
     read_slot<=SESSION ? 16'(ALIAS_SLOT):16'(IMAGE_SLOT);stream_pos<=0;
     if(format==1)begin
      if(head_latched[0] || head_latched>={d64_tracks,1'b0})begin kind<=G64_TRACK;index<=0;state<=EMPTY;end
      else begin
       kind<=D64_TRACK;read_offset<=d64_offset(head_latched[6:1]);
       track_offset<=d64_offset(head_latched[6:1]);
       bytes_left<={18'b0,d64_input_size(full_track)};read_length<=1024;
       d64_start<=1;state<=REQUEST;
      end
     end else if(head_latched>=g64_count || selected_offset==0)begin kind<=G64_TRACK;index<=0;state<=EMPTY;end
     else begin
      track_offset<=selected_offset;read_offset<=selected_offset;
      kind<=G64_LENGTH;bytes_left<=2;read_length<=2;state<=REQUEST;
     end
    end
    G64_LENGTH_CHECK:begin
     save_limit<=track_len==0 ? track_offset:track_offset+{15'b0,({1'b0,track_len}+17'd2)};
     if(track_len>g64_max || track_len>8190 || (track_len!=0 && track_len<=6000))begin error_code<=7;state<=FAIL;end
     else if({16'b0,track_len}>file_size-track_offset-2)begin error_code<=5;state<=FAIL;end
     else if(track_len==0)begin kind<=G64_TRACK;index<=0;state<=EMPTY;end
     else begin
      kind<=G64_TRACK;read_offset<=track_offset;bytes_left<={16'b0,track_len}+2;
      read_length<=track_len+16'd2>1024 ? 11'd1024:11'(track_len+16'd2);
      stream_pos<=0;state<=REQUEST;
     end
    end
    D64_WAIT:begin
     if(d64_error)begin error_code<=9;state<=FAIL;end
     else if(d64_done || !d64_busy)begin
      track_len<=d64_length;save_limit<=track_offset+{18'b0,d64_input_size(full_track)};state<=FLUSH;
     end
    end
    EMPTY:begin track_offset<=0;save_limit<=0;if(index==1)state<=FLUSH;else index<=1;end
    FLUSH:begin
     if(pack_count!=0)begin track_we<=1;track_addr<=word_index;track_data<=pack_word;pack_count<=0;end
     state<=COMMIT_WAIT1;
    end
    COMMIT_WAIT1:state<=COMMIT_WAIT2;
    COMMIT_WAIT2:state<=COMMIT;
    COMMIT:begin
     // A slot replacement may arrive while an old APF transfer is in flight.
     // Finish that transfer under the ownership lock, but never mount its
     // possibly mixed contents. The queued replacement starts from metadata.
     if(pending || events[EVENT_BIT])mounted<=0;
     else begin commit_toggle<=~commit_toggle;loaded_track<=head_latched;mounted<=1;end
     state<=RELEASE;
    end
    RELEASE:begin busy<=0;pause_request<=0;boot_checked<=1;state<=IDLE;end
    FAIL:begin mounted<=0;busy<=0;pause_request<=0;boot_checked<=1;state<=IDLE;end
    default:begin error_code<=9;state<=FAIL;end
   endcase
  end
 end
endmodule
