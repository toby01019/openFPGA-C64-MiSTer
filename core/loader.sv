// SPDX-License-Identifier: MIT
// APF assets -> byte mailbox -> C64 RAM/ROM and optional CRT stream.
module pocket_loader #(parameter BOOT_CYCLES=222750000,KEY_CYCLES=3712500,ENABLE_CRT=0,ENABLE_PCM=0)(
 input wire clk,reset,input wire [7:0] events,input wire storage_hold,
 input wire restart,restart_safe,
 input wire cart_busy,cart_error,
 output wire storage_requested,
 output wire read_start,input wire read_ready,read_done,read_error,
 output reg [15:0] read_slot=0,output reg [31:0] read_offset=0,
 output reg [10:0] read_length=0,
 output wire [7:0] buffer_addr,input wire [31:0] buffer_data,
 output reg [5:0] table_addr=0,input wire [31:0] table_data,
 output wire write_valid,output wire [25:0] write_data,input wire write_done,
 output reg core_run=0,output reg pause_request=0,input wire paused,
 output reg [7:0] auto_keys=0,output reg [7:0] error_code=0,
 output wire [5:0] debug_state
);
 localparam CLEAR=0,CLEAR_GAP=1,ASSET=2,REQ=3,WAIT_FILE=4,
 FETCH=5,FETCH_WAIT=6,BYTE=7,WRITE=8,WRITE_GAP=9,NEXT_BYTE=10,
 BOOT=11,IDLE=12,TABLE_REQ=13,TABLE_WAIT=14,TABLE_ID=15,
 LENGTH_WAIT=16,LENGTH=17,RESET_WAIT=18,PAUSE_WAIT=19,
 POINTER=20,POINTER_GAP=21,KEYS=22,FAIL=23,START_CORE=24,CONTROL=25,CONTROL_GAP=26,CART_WAIT=27,AFTER_SAMPLE=28;
 reg [5:0] state=CLEAR;
 reg [15:0] clear_addr=0,start_addr=0,end_addr=0;
 reg [1:0] asset=0;
 reg prg=0,pending=0,crt=0,pending_crt=0,initial_crt=0;
 reg sample_bank=0;
 reg restart_pending=0,restart_clearing=0;
 reg [5:0] control_return=IDLE;
 reg [31:0] file_size=0,wait_count=0;
 reg [10:0] index=0;
 reg [7:0] current_byte=0;
 reg [5:0] table_index=0;
 reg [2:0] pointer_index=0,key_phase=0;
 reg [25:0] byte_command=0;
 wire [31:0] position=read_offset+index;
 wire [16:0] checked_end={1'b0,start_addr}+file_size-2;
 assign debug_state=state;
 assign storage_requested=pending || events[1] || (ENABLE_CRT && (pending_crt || events[3]));
 assign buffer_addr=index[9:2];
 assign read_start=state==REQ && read_ready;
 assign write_valid=(state==CLEAR)||(state==WRITE)||(state==POINTER)||(state==CONTROL);
 function automatic [15:0] ptr_addr(input [2:0] n);
 case(n)
 0:ptr_addr=16'h002d;1:ptr_addr=16'h002e;2:ptr_addr=16'h002f;
 3:ptr_addr=16'h0030;4:ptr_addr=16'h0031;5:ptr_addr=16'h0032;
 6:ptr_addr=16'h00ae;7:ptr_addr=16'h00af;
 endcase
 endfunction
 assign write_data=state==CLEAR ? {2'd0,clear_addr,8'd0} :
  state==POINTER ? {2'd0,ptr_addr(pointer_index),
   (pointer_index[0] ? end_addr[15:8]:end_addr[7:0])} : byte_command;
 always @(posedge clk) begin
  if(reset) begin
   state<=CLEAR;clear_addr<=0;asset<=0;prg<=0;pending<=0;crt<=0;pending_crt<=0;initial_crt<=0;
   core_run<=0;pause_request<=0;auto_keys<=0;error_code<=0;
   restart_pending<=0;restart_clearing<=0;
   sample_bank<=0;
  end else begin
   if(events[1]) pending<=1;
   if(ENABLE_CRT && events[3]) pending_crt<=1;
   if(restart)restart_pending<=1;
   // Finish outstanding transfers before reusing the byte mailbox. Keep the
   // selected disk and system ROMs; eject CRT and clear RAM for a cold BASIC boot.
   if(!storage_hold && restart_pending && restart_safe && read_ready &&
      (state==IDLE || (state==FAIL && (prg || crt))))begin
    restart_pending<=0;restart_clearing<=1;clear_addr<=0;
    prg<=0;crt<=0;pending<=0;pending_crt<=0;initial_crt<=0;
    core_run<=0;pause_request<=0;auto_keys<=0;error_code<=0;wait_count<=0;
    if(ENABLE_CRT)begin
     byte_command<={2'd3,2'b11,22'b0};control_return<=CLEAR;state<=CONTROL;
    end else state<=CLEAR;
   end else if(!storage_hold && ENABLE_CRT && crt && cart_error && state==NEXT_BYTE)begin
    // The mailbox is drained here. Stop feeding an already rejected image.
    error_code<=7;state<=FAIL;
   end else if(!storage_hold) case(state)
   CLEAR: if(write_done) state<=CLEAR_GAP;
   CLEAR_GAP: if(clear_addr==16'hffff)begin
     if(restart_clearing)begin restart_clearing<=0;wait_count<=0;state<=START_CORE;end
     else state<=ASSET;
    end
     else begin clear_addr<=clear_addr+1'b1;state<=CLEAR;end
   ASSET: begin
     read_offset<=0;index<=0;read_length<=1024;
     case(asset)
     0:begin read_slot<=200;file_size<=8192;end
     1:begin read_slot<=201;file_size<=4096;end
     2:begin read_slot<=202;file_size<=8192;end
     endcase
     table_index<=0;state<=TABLE_REQ;
   end
   REQ: if(read_ready) state<=WAIT_FILE;
   WAIT_FILE: if(read_done) begin
     if(read_error && sample_bank)begin
       byte_command<={4'b1111,1'b1,21'b0};control_return<=AFTER_SAMPLE;state<=CONTROL;
     end else if(read_error) begin error_code<=1;state<=FAIL;end
     else begin index<=0;state<=FETCH;end
   end
   FETCH:state<=FETCH_WAIT;
   FETCH_WAIT:begin current_byte<=buffer_data >> (index[1:0]*8);state<=BYTE;end
   BYTE: begin
     if(prg && position==0) begin start_addr[7:0]<=current_byte;state<=NEXT_BYTE;end
     else if(prg && position==1) begin start_addr[15:8]<=current_byte;state<=NEXT_BYTE;end
     else if(prg && checked_end>17'h10000) begin error_code<=3;state<=FAIL;end
     else begin
       if(sample_bank)byte_command<={4'b1100,1'b1,13'b0,current_byte};
       else if(crt) byte_command<={2'd3,2'b00,14'b0,current_byte};
       else if(prg) byte_command<={2'd0,16'(start_addr+position-2),current_byte};
       else byte_command<={(asset==1 ? 2'd2:2'd1),
         16'(position+(asset==2 ? 8192:0)),current_byte};
       state<=WRITE;
     end
   end
   WRITE:if(write_done) state<=WRITE_GAP;
   WRITE_GAP:state<=NEXT_BYTE;
   NEXT_BYTE:begin
     if(index+1==read_length) begin
       if(read_offset+read_length==file_size) begin
         if(sample_bank)begin
           byte_command<={4'b1110,1'b1,21'b0};control_return<=AFTER_SAMPLE;state<=CONTROL;
         end else if(crt) begin
           byte_command<={2'd3,2'b10,22'b0};control_return<=CART_WAIT;state<=CONTROL;
         end else if(prg) begin end_addr<=checked_end[15:0];pointer_index<=0;state<=POINTER;end
         else if(asset==2) begin
           pause_request<=0;wait_count<=0;
           if(ENABLE_PCM)begin sample_bank<=1;read_slot<=205;table_index<=0;state<=TABLE_REQ;end
           else if(ENABLE_CRT)begin crt<=1;initial_crt<=1;read_slot<=3;table_index<=0;state<=TABLE_REQ;end
           else state<=START_CORE;
         end else begin asset<=asset+1'b1;state<=ASSET;end
       end else begin
         read_offset<=read_offset+read_length;
         read_length<=(file_size-read_offset-read_length>1024) ? 1024 :
                       11'(file_size-read_offset-read_length);
         state<=REQ;
       end
     end else begin index<=index+1'b1;state<=FETCH;end
   end
   AFTER_SAMPLE:begin
     sample_bank<=0;read_offset<=0;index<=0;wait_count<=0;
     if(ENABLE_CRT)begin crt<=1;initial_crt<=1;read_slot<=3;table_index<=0;state<=TABLE_REQ;end
     else state<=START_CORE;
   end
   START_CORE:if(wait_count==2047) begin
     core_run<=1;wait_count<=0;state<=BOOT;
   end else wait_count<=wait_count+1'b1;
   BOOT:if(wait_count==BOOT_CYCLES-1) begin
     if(prg) begin pause_request<=1;state<=PAUSE_WAIT;end
     else state<=IDLE;
   end else wait_count<=wait_count+1'b1;
   IDLE:if(pending || (ENABLE_CRT && pending_crt)) begin
     initial_crt<=0;table_index<=0;table_addr<=0;error_code<=0;state<=TABLE_REQ;
     if(pending)begin pending<=events[1];prg<=1;crt<=0;read_slot<=1;end
     else begin pending_crt<=events[3];prg<=0;crt<=1;read_slot<=3;end
   end
   TABLE_REQ:begin table_addr<={table_index[4:0],1'b0};state<=TABLE_WAIT;end
   TABLE_WAIT:state<=TABLE_ID;
   TABLE_ID:if(table_data[15:0]==read_slot) begin
     table_addr<={table_index[4:0],1'b1};state<=LENGTH_WAIT;
   end else if(table_index==31) begin
     if(sample_bank)state<=AFTER_SAMPLE;
     else if(crt && initial_crt)begin crt<=0;initial_crt<=0;wait_count<=0;state<=START_CORE;end
     else begin error_code<=4;state<=FAIL;end
   end
   else begin table_index<=table_index+1'b1;state<=TABLE_REQ;end
   LENGTH_WAIT:state<=LENGTH;
   LENGTH:begin
     if(sample_bank)begin
       if(table_data<2 || table_data>1048576 || table_data[0])state<=AFTER_SAMPLE;
       else begin
         file_size<=table_data;read_offset<=0;index<=0;
         read_length<=table_data>1024 ? 1024:11'(table_data);
         byte_command<={4'b1101,1'b1,table_data[20:0]};control_return<=REQ;state<=CONTROL;
       end
     end else if(crt) begin
       if(table_data==0)begin
         crt<=0;initial_crt<=0;wait_count<=0;core_run<=0;pause_request<=0;
         byte_command<={2'd3,2'b11,22'b0};control_return<=START_CORE;state<=CONTROL;
       end else if(table_data<80 || table_data>32'h100840)begin error_code<=6;state<=FAIL;end
       else begin
         file_size<=table_data;read_offset<=0;index<=0;
         read_length<=table_data>1024 ? 1024:11'(table_data);
         core_run<=0;pause_request<=0;wait_count<=0;
         byte_command<={2'd3,2'b01,table_data[21:0]};control_return<=REQ;state<=CONTROL;
       end
     end else if(!prg) begin
       if(table_data!=file_size) begin error_code<=5;state<=FAIL;end
       else state<=REQ;
     end else if(table_data<3 || table_data>65538) begin error_code<=2;state<=FAIL;end
     else begin
       file_size<=table_data;
       core_run<=0;pause_request<=0;wait_count<=0;
       if(ENABLE_CRT)begin byte_command<={2'd3,2'b11,22'b0};control_return<=RESET_WAIT;state<=CONTROL;end
       else state<=RESET_WAIT;
     end
   end
   RESET_WAIT:if(wait_count==2047) begin
     core_run<=1;wait_count<=0;state<=BOOT;
   end else wait_count<=wait_count+1'b1;
   PAUSE_WAIT:if(paused) begin
     read_slot<=1;read_offset<=0;read_length<=file_size>1024 ? 1024:11'(file_size);
     state<=REQ;
   end
   POINTER:if(write_done) state<=POINTER_GAP;
   POINTER_GAP:if(pointer_index==7) begin
     pause_request<=0;key_phase<=0;wait_count<=0;state<=KEYS;
   end else begin pointer_index<=pointer_index+1'b1;state<=POINTER;end
   KEYS:begin
     case(key_phase)
     0:auto_keys<=8'h10;2:auto_keys<=8'h20;4:auto_keys<=8'h40;6:auto_keys<=8'h01;
     default:auto_keys<=0;
     endcase
     if(wait_count==KEY_CYCLES-1) begin
       wait_count<=0;
       if(key_phase==7) begin auto_keys<=0;state<=IDLE;end
       else key_phase<=key_phase+1'b1;
     end else wait_count<=wait_count+1'b1;
   end
   CONTROL:if(write_done)state<=CONTROL_GAP;
   CONTROL_GAP:begin wait_count<=0;state<=control_return;end
   CART_WAIT:begin
     // Allow return CDC status to settle after the finish-command acknowledgement.
     if(wait_count<8)wait_count<=wait_count+1'b1;
     else if(!cart_busy)begin
       if(cart_error)begin error_code<=7;state<=FAIL;end
       else begin crt<=0;initial_crt<=0;wait_count<=0;state<=START_CORE;end
     end
   end
   FAIL:begin
     auto_keys<=0;
     if(ENABLE_CRT && crt && read_ready)begin
       // A bad module must not leave the C64 reset/paused indefinitely.
       // Finish file ownership, detach over the acknowledged mailbox, then
       // clear RAM and boot BASIC with the already validated system ROMs.
       // Keep error_code until the next selection/reset for diagnostics.
       crt<=0;prg<=0;initial_crt<=0;restart_clearing<=1;clear_addr<=0;
       core_run<=0;pause_request<=0;wait_count<=0;
       byte_command<={2'd3,2'b11,22'b0};control_return<=CLEAR;state<=CONTROL;
     end else begin
     // Keep a failed, potentially partially injected program from executing.
     pause_request<=1;
     if((prg || crt) && (pending || (ENABLE_CRT && pending_crt)) && read_ready)begin
       initial_crt<=0;error_code<=0;table_index<=0;state<=TABLE_REQ;
       if(pending)begin pending<=events[1];prg<=1;crt<=0;read_slot<=1;end
       else begin pending_crt<=events[3];prg<=0;crt<=1;read_slot<=3;end
     end
     end
   end
   default:state<=FAIL;
   endcase
  end
 end
endmodule
