// SPDX-License-Identifier: MIT
// Serialize PRG/ROM loading and track refills, including their buffer lifetime.
module pocket_storage #(parameter AUTOSAVE_CYCLES=742500, parameter IMAGE_SLOT=2, EVENT_BIT=2, ALIAS_SLOT=6, ROM_SLOT=203, parameter EXTERNAL_IO=0, parameter [31:0] BUFFER_BASE=32'h70000000)(
 input wire ext_ready,ext_done,ext_error,input wire [7:0] ext_events,
 output wire ext_start,output wire [2:0] ext_operation,output wire [15:0] ext_slot,
 output wire [31:0] ext_offset,output wire [10:0] ext_length,
 input wire clk,reset,input wire [31:0] bridge_addr,bridge_wr_data,input wire bridge_wr,
 output wire [31:0] table_bridge_data,buffer_bridge_data,
 output wire cpu_req,output wire [31:0] cpu_addr,cpu_data,output wire [3:0] cpu_wstrb,
 input wire cpu_ack,input wire [31:0] cpu_rdata,
 input wire loader_idle,loader_start,output wire loader_ready,loader_done,loader_error,
 input wire [15:0] loader_slot,input wire [31:0] loader_offset,input wire [10:0] loader_length,
 input wire [7:0] loader_buffer_addr,output wire [31:0] loader_buffer_data,
 input wire [5:0] loader_table_addr,output wire [31:0] loader_table_data,
 output wire [7:0] events,
 input wire [6:0] head_track,input wire need_track,paused,
 input wire dirty,writing,write_protect,write_enable,
 output wire save_pause,output reg clear_modified=0,output wire write_ready,
 output wire [9:0] track_read_addr,input wire [63:0] track_read_q,
 output wire disk_busy,disk_pause,mounted,rom_loaded,
 output wire rom_we,output wire [13:0] rom_addr,output wire [7:0] rom_data,
 output wire track_we,output wire [9:0] track_addr,output wire [63:0] track_data,
 output wire commit_toggle,output wire [6:0] loaded_track,
 output wire [7:0] disk_error,disk_state,output wire [1:0] disk_format,output wire [15:0] track_len
);
 localparam S_IDLE=0,S_PAUSE=1,S_SAVE_START=2,S_SAVE_WAIT=3,S_CLEAR=4,
  S_RELOAD=5,S_GET=6,S_GET_WAIT=7,S_ZERO1=8,S_ZERO2=9,S_GAP=10,S_OPEN=11,S_OPEN_WAIT=12,S_FAIL=13;
 reg [3:0] session_state=S_IDLE;
 localparam AUTO_BITS=$clog2(AUTOSAVE_CYCLES+1);
 reg [AUTO_BITS-1:0] idle_count=0;
 reg [4:0] quiet_count=0;
 wire quiet=quiet_count==5'd16;
 wire autosave_due=dirty && idle_count>=AUTOSAVE_CYCLES;
 always @(posedge clk)begin
  if(reset || writing)quiet_count<=0;
  else if(!quiet)quiet_count<=quiet_count+1'b1;
  if(reset || !dirty || writing)idle_count<=0;
  else if(idle_count<AUTOSAVE_CYCLES)idle_count<=idle_count+1'b1;
 end
 reg pending_mount=0,alias_valid=0,cache_valid=0,commit_seen=0;
 // A failed filename/alias command must not leave a clean disk paused forever.
 // Read directly from the selected slot instead, with writes disabled: unlike
 // an alias, that slot cannot preserve the old file across a user replacement.
 reg direct_read_only=0;
 reg [7:0] session_error=0,front_events=0;
 reg [1:0] cached_format=0;
 reg [6:0] cached_head=0;
 reg [15:0] cached_length=0;
 reg [31:0] cached_offset=0,cached_limit=0;
 reg [7:0] cached_id1=0,cached_id2=0;
 wire front_busy,front_pause,bind_request;
 wire [31:0] front_offset,front_limit;
 wire [7:0] front_id1,front_id2,front_error;
 wire session_lock=session_state!=S_IDLE;
 wire session_io=session_state==S_GET || session_state==S_GET_WAIT || session_state==S_OPEN || session_state==S_OPEN_WAIT;
 wire save_busy,save_done,save_error,save_start,save_io_start,save_buffer_we;
 wire [7:0] save_error_code,save_buffer_addr;
 wire [31:0] save_buffer_data,save_io_offset;
 wire [15:0] save_io_slot;
 wire [10:0] save_io_length;
 wire [2:0] save_io_operation;
 wire save_owns=session_state==S_SAVE_START || session_state==S_SAVE_WAIT;
 wire safe_front=!front_busy || bind_request || disk_state==8'd17;
 wire mount_request=pending_mount || events[EVENT_BIT];
 assign disk_busy=front_busy || session_lock || (mount_request && loader_idle);
 assign save_pause=quiet && !writing && (session_lock || mount_request || (dirty && need_track) || autosave_due);
 assign disk_pause=(front_pause && quiet && !writing) || save_pause;
 assign write_ready=alias_valid && cache_valid && mounted && write_enable && !write_protect;
 assign disk_error=session_error!=0 ? session_error:front_error;
 assign save_start=session_state==S_SAVE_START;
 always @(posedge clk)begin
  front_events<=0;
  if(reset)begin
   session_state<=S_IDLE;pending_mount<=0;alias_valid<=0;cache_valid<=0;direct_read_only<=0;
   clear_modified<=0;commit_seen<=0;session_error<=0;
  end else begin
   if(events[EVENT_BIT])pending_mount<=1;
   if(commit_toggle!=commit_seen)begin
    commit_seen<=commit_toggle;cached_format<=disk_format;cached_head<=loaded_track;
    cached_length<=track_len;cached_offset<=front_offset;cached_limit<=front_limit;
    cached_id1<=front_id1;cached_id2<=front_id2;cache_valid<=front_limit>front_offset;
   end
   case(session_state)
    S_IDLE:if((loader_idle || front_busy) && safe_front)begin
     if(mount_request || (dirty && need_track) || autosave_due)begin session_error<=0;session_state<=S_PAUSE;end
     else if(bind_request && !alias_valid && !direct_read_only)begin
      session_error<=0;
      // The default protected mount needs no second file handle. Reserve
      // aliases for writable disks, where dirty old tracks must survive swaps.
      if(write_protect)direct_read_only<=1;
      else session_state<=S_GET;
     end
    end
    S_PAUSE:if(paused && !writing && quiet)begin
     if(dirty)begin
      if(!alias_valid || !cache_valid || !write_enable || write_protect)begin session_error<=8'h41;session_state<=S_FAIL;end
      else session_state<=S_SAVE_START;
     end else if(mount_request)session_state<=S_RELOAD;
     else session_state<=S_IDLE;
    end
    S_SAVE_START:session_state<=S_SAVE_WAIT;
    S_SAVE_WAIT:if(save_done)begin clear_modified<=1;session_state<=S_CLEAR;end
     else if(save_error && !save_busy)begin session_error<=8'h80|save_error_code;session_state<=S_FAIL;end
    S_CLEAR:if(!dirty)begin clear_modified<=0;session_state<=mount_request ? S_RELOAD:S_IDLE;end
    S_RELOAD:begin
     alias_valid<=0;cache_valid<=0;direct_read_only<=0;front_events<=8'(1<<EVENT_BIT);
     pending_mount<=events[EVENT_BIT];session_state<=S_IDLE;
    end
    S_GET:if(reader_ready)session_state<=S_GET_WAIT;
    S_GET_WAIT:if(reader_done)begin
     if(reader_error)begin session_error<=8'h42;direct_read_only<=1;session_state<=S_IDLE;end
     else session_state<=S_ZERO1;
    end
    S_ZERO1:session_state<=S_ZERO2;
    S_ZERO2:session_state<=S_GAP;
    S_GAP:session_state<=S_OPEN;
    S_OPEN:if(reader_ready)session_state<=S_OPEN_WAIT;
    S_OPEN_WAIT:if(reader_done)begin
     if(reader_error)begin session_error<=8'h43;direct_read_only<=1;session_state<=S_IDLE;end
     else begin alias_valid<=1;session_state<=S_IDLE;end
    end
    // Fail closed: retain RAM and old alias. Reset is the explicit recovery.
    S_FAIL:begin end
    default:begin session_error<=8'h44;session_state<=S_FAIL;end
   endcase
  end
 end
 wire disk_start,disk_ready,disk_done,reader_ready,reader_start,reader_done,reader_error;
 wire [15:0] disk_slot;
 wire [31:0] disk_offset;
 wire [10:0] disk_length;
 wire [7:0] disk_buffer_addr;
 wire [5:0] disk_table_addr;
 wire [31:0] buffer_data,table_data,buffer_host_q;
 reg [1:0] reader_owner=0;
 wire [1:0] owner=session_lock ? 2'd2:(front_busy ? 2'd1:2'd0);
 assign reader_start=session_lock ? (save_owns ? save_io_start:
                     ((session_state==S_GET || session_state==S_OPEN) && reader_ready)):
                     (front_busy ? disk_start:loader_start);
 assign loader_ready=reader_ready && !disk_busy;
 assign disk_ready=reader_ready && front_busy && !session_lock;
 assign loader_done=reader_done && reader_owner==0;
 assign loader_error=reader_error && reader_owner==0;
 assign disk_done=reader_done && reader_owner==1;
 assign loader_buffer_data=buffer_data;
 assign loader_table_data=table_data;
 assign buffer_bridge_data={buffer_host_q[7:0],buffer_host_q[15:8],buffer_host_q[23:16],buffer_host_q[31:24]};
 always @(posedge clk) begin
  if(reset) reader_owner<=0;
  else if(reader_start && reader_ready) reader_owner<=owner;
 end
 pocket_track_save saver(.clk(clk),.reset(reset),.start(save_start),.format(cached_format),
  .half_track(cached_head),.raw_length(cached_length),.file_offset(cached_offset),.write_limit(cached_limit),
  .disk_id1(cached_id1),.disk_id2(cached_id2),.slot(16'(ALIAS_SLOT)),.busy(save_busy),.done(save_done),
  .error(save_error),.error_code(save_error_code),.track_addr(track_read_addr),.track_q(track_read_q),
  .buffer_we(save_buffer_we),.buffer_addr(save_buffer_addr),.buffer_data(save_buffer_data),
  .io_start(save_io_start),.io_ready(reader_ready && save_owns),
  .io_done(reader_done && reader_owner==2),.io_error(reader_error),.io_operation(save_io_operation),
  .io_slot(save_io_slot),.io_offset(save_io_offset),.io_length(save_io_length));
 assign ext_start=reader_start;
 assign ext_operation=session_lock ? (save_owns ? save_io_operation:(session_state==S_GET ? 3'd3:3'd4)):3'd0;
 assign ext_slot=session_lock ? (save_owns ? save_io_slot:(session_state==S_GET ? 16'(IMAGE_SLOT):16'(ALIAS_SLOT))):(front_busy ? ((direct_read_only && disk_slot==16'(ALIAS_SLOT)) ? 16'(IMAGE_SLOT):disk_slot):loader_slot);
 assign ext_offset=save_owns ? save_io_offset:(front_busy ? disk_offset:loader_offset);
 assign ext_length=save_owns ? save_io_length:(front_busy ? disk_length:loader_length);
 generate if(EXTERNAL_IO)begin:external_io
  assign reader_ready=ext_ready;assign reader_done=ext_done;assign reader_error=ext_error;assign events=ext_events;
  assign cpu_req=0;assign cpu_addr=0;assign cpu_data=0;assign cpu_wstrb=0;
 end else begin:internal_io
 pocket_file_reader reader(.clk(clk),.reset(reset),.start(reader_start),
  .operation(ext_operation),.slot(ext_slot),.offset(ext_offset),.length(ext_length),
  .ready(reader_ready),.done(reader_done),.error(reader_error),.events(events),.cpu_req(cpu_req),
  .cpu_addr(cpu_addr),.cpu_data(cpu_data),.cpu_wstrb(cpu_wstrb),.cpu_ack(cpu_ack),.cpu_rdata(cpu_rdata));
 end endgenerate
 bram_block_dp #(.DATA(32),.ADDR(8)) file_buffer(
  .a_clk(clk),.a_wr(bridge_wr && bridge_addr[31:10]==BUFFER_BASE[31:10]),.a_addr(bridge_addr[9:2]),
  .a_din({bridge_wr_data[7:0],bridge_wr_data[15:8],bridge_wr_data[23:16],bridge_wr_data[31:24]}),.a_dout(buffer_host_q),
  .b_clk(clk),.b_wr(save_owns ? save_buffer_we:(session_state==S_ZERO1 || session_state==S_ZERO2)),
  .b_addr(save_owns ? save_buffer_addr:(session_state==S_ZERO1 ? 8'd64:(session_state==S_ZERO2 ? 8'd65:(front_busy ? disk_buffer_addr:loader_buffer_addr)))),
  .b_din(save_owns ? save_buffer_data:32'b0),.b_dout(buffer_data));
 bram_block_dp #(.DATA(32),.ADDR(6)) slot_table(
  .a_clk(clk),.a_wr(bridge_wr && bridge_addr[31:8]==24'hf80020),.a_addr(bridge_addr[7:2]),
  .a_din(bridge_wr_data),.a_dout(table_bridge_data),.b_clk(clk),.b_wr(1'b0),
  .b_addr(disk_busy ? disk_table_addr:loader_table_addr),.b_din(32'b0),.b_dout(table_data));
 pocket_disk #(.SESSION(1),.IMAGE_SLOT(IMAGE_SLOT),.EVENT_BIT(EVENT_BIT),.ALIAS_SLOT(ALIAS_SLOT),.ROM_SLOT(ROM_SLOT)) disk(.clk(clk),.reset(reset),
  .enable(loader_idle && !session_lock && !mount_request),.events(front_events),
  .image_ready((alias_valid || direct_read_only) && !mount_request && !session_lock),.bind_request(bind_request),
  .save_offset(front_offset),.save_limit(front_limit),.save_id1(front_id1),.save_id2(front_id2),
  // An in-flight D64 converter must drain before the queued mount can own
  // the buffer. Gating its output with mount_request deadlocks both FSMs.
  .head_track(head_track),.need_track(need_track),.busy(front_busy),.pause_request(front_pause),.paused(paused && !dirty && !session_lock),
  .mounted(mounted),.rom_loaded(rom_loaded),.rom_we(rom_we),.rom_addr(rom_addr),.rom_data(rom_data),
  .track_we(track_we),.track_addr(track_addr),.track_data(track_data),
  .commit_toggle(commit_toggle),.loaded_track(loaded_track),
  .read_start(disk_start),.read_ready(disk_ready),.read_done(disk_done),.read_error(reader_error),
  .read_slot(disk_slot),.read_offset(disk_offset),.read_length(disk_length),
  .buffer_addr(disk_buffer_addr),.buffer_data(buffer_data),.table_addr(disk_table_addr),.table_data(table_data),
  .error_code(front_error),.debug_state(disk_state),.format(disk_format),.track_len(track_len));
endmodule
