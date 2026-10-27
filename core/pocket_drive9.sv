// SPDX-License-Identifier: MIT
// Optional IEC device9. Mode changes wait for old writes/flushes to finish.
module pocket_drive9 #(parameter ENABLE_D81=1)(
 input wire clk74,clk_core,reset_host,reset_core,pause_core,paused_host,
 input wire [1:0] requested_mode,input wire write_protect,input wire host_enable,
 input wire [31:0] bridge_addr,bridge_data,input wire bridge_wr,input wire [7:0] events,
 output wire [31:0] buffer1541_q,buffer1581_q,
 input wire iec_atn,iec_data,iec_clock,output wire data_o,clock_o,
 output wire activity_led,output wire pause_request,output wire reset_safe,output wire [1:0] active_mode,output wire [7:0] error_code,
 output wire [1:0] io_start,input wire [1:0] io_ready,io_done,io_error,
 output wire [5:0] io_operation,output wire [31:0] io_slot,
 output wire [63:0] io_offset,output wire [21:0] io_length
);
 reg [1:0] mode=0;
 wire b1541,b1581,d81dirty,dirty,writing,writing81,transfer81;
 (* async_reg="true" *) reg writing81_meta=0,writing81_sync=0,transfer81_meta=0,transfer81_sync=0;
 reg [5:0] switch_quiet=0;
 wire [1:0] allowed_mode=(requested_mode==3 || (!ENABLE_D81 && requested_mode==2)) ? 2'b0:requested_mode;
 wire switching=mode!=allowed_mode;
 (* async_reg="true" *) reg dirty_meta=0,dirty_sync=0,write_meta=0,write_sync=0;
 always @(posedge clk74)begin
  dirty_meta<=dirty;dirty_sync<=dirty_meta;write_meta<=writing;write_sync<=write_meta;
  writing81_meta<=writing81;writing81_sync<=writing81_meta;transfer81_meta<=transfer81;transfer81_sync<=transfer81_meta;
  if(reset_host || !switching || write_sync || writing81_sync || transfer81_sync || !paused_host)switch_quiet<=0;
  else if(switch_quiet!=63)switch_quiet<=switch_quiet+1'b1;
  if(reset_host)mode<=0;
  else if((mode==0 || switch_quiet==63) && !b1541 && !b1581 && !dirty_sync && !write_sync && !writing81_sync && !transfer81_sync && !d81dirty)
   mode<=allowed_mode;
 end
 assign active_mode=mode;
 assign reset_safe=!b1541 && !b1581 && !dirty_sync && !write_sync && !writing81_sync && !transfer81_sync && !d81dirty && !switching;
 wire r1541=reset_host || mode!=1;
 wire r1581=reset_host || mode!=2;
 (* async_reg="true" *) reg [1:0] mode_meta=0,mode_sync=0;
 wire mounted,rom_ready,commit,clear,canwrite,savepause,pause1541;
 wire [6:0] loaded,head;
 wire [9:0] wa,readaddr;wire [63:0] wd,rq;wire track_we,romwe;
 wire [13:0] roma;wire [7:0] romd,err1541,err1581;
 (* async_reg="true" *) reg mount_meta=0,mount_sync=0,rom_meta=0,rom_sync=0;
 (* async_reg="true" *) reg commit_meta=0,commit_sync=0,clear_meta=0,clear_sync=0,protect_meta=1,protect_sync=1;
 (* async_reg="true" *) reg [6:0] head_meta=34,head_sync=34;
 (* async_reg="true" *) reg need_meta=0,need_sync=0;
 reg cached_valid=0,commit_seen=0;reg [6:0] cached_track=34;
 wire need=mount_sync && (!cached_valid || cached_track!=head);
 always @(posedge clk74)begin head_meta<=head;head_sync<=head_meta;need_meta<=need;need_sync<=need_meta;end
 always @(posedge clk_core)begin
  mode_meta<=mode;mode_sync<=mode_meta;mount_meta<=mounted;mount_sync<=mount_meta;
  rom_meta<=rom_ready;rom_sync<=rom_meta;commit_meta<=commit;commit_sync<=commit_meta;
  clear_meta<=clear;clear_sync<=clear_meta;protect_meta<=write_protect || !canwrite;protect_sync<=protect_meta;
  if(reset_core || mode_sync!=1)begin cached_valid<=0;commit_seen<=commit_sync;end
  else if(commit_sync!=commit_seen)begin cached_valid<=1;cached_track<=loaded;commit_seen<=commit_sync;end
 end
 pocket_storage #(.EXTERNAL_IO(1),.IMAGE_SLOT(4),.EVENT_BIT(4),.ALIAS_SLOT(7),.ROM_SLOT(203),.BUFFER_BASE(32'h70000400)) storage1541(
  .clk(clk74),.reset(r1541),.bridge_addr(bridge_addr),.bridge_wr_data(bridge_data),.bridge_wr(bridge_wr),.buffer_bridge_data(buffer1541_q),
  .ext_start(io_start[0]),.ext_ready(io_ready[0]),.ext_done(io_done[0]),.ext_error(io_error[0]),.ext_events(events),
  .ext_operation(io_operation[2:0]),.ext_slot(io_slot[15:0]),.ext_offset(io_offset[31:0]),.ext_length(io_length[10:0]),
  .loader_idle(host_enable && mode==1),.loader_start(1'b0),.loader_slot(16'b0),.loader_offset(32'b0),.loader_length(11'b0),
  .loader_buffer_addr(8'b0),.loader_table_addr(6'b0),.head_track(head_sync),.need_track(need_sync && head_meta==head_sync),.paused(paused_host),
  .dirty(dirty_sync),.writing(write_sync),.write_protect(write_protect),.write_enable(1'b1),
  .save_pause(savepause),.clear_modified(clear),.write_ready(canwrite),.track_read_addr(readaddr),.track_read_q(rq),
  .disk_busy(b1541),.disk_pause(pause1541),.mounted(mounted),.rom_loaded(rom_ready),
  .rom_we(romwe),.rom_addr(roma),.rom_data(romd),.track_we(track_we),.track_addr(wa),.track_data(wd),
  .commit_toggle(commit),.loaded_track(loaded),.disk_error(err1541));
 wire data1541,clock1541;
 pocket_1541 drive1541(.clk_core(clk_core),.reset(reset_core || mode_sync!=1 || !rom_sync),.pause(pause_core),
  .iec_atn_i(iec_atn),.iec_data_i(iec_data),.iec_clk_i(iec_clock),.iec_data_o(data1541),.iec_clk_o(clock1541),
  .mounted(mount_sync),.write_protect(protect_sync),.drive_num(2'd1),.track(head),.led(activity_led),.writing(writing),.modified(dirty),.clear_modified(clear_sync),
  .clk74(clk74),.rom_we(romwe),.rom_addr(roma),.rom_data(romd),.track_we(track_we),
  .track_addr(savepause ? readaddr:wa),.track_data(wd),.track_q(rq));
 wire [31:0] lba;wire rd,wr,ack,sdwe;wire [8:0] sda;wire [7:0] sdo,sdi;
 wire d81mounted,d81rom,romwe81;wire [14:0] roma81;wire [7:0] romd81;
 wire data1581,clock1581;
 generate if(ENABLE_D81)begin:with_d81
 pocket_d81_storage storage1581(.clk(clk74),.reset(r1581),.enable(host_enable && mode==2),
  .bridge_addr(bridge_addr),.bridge_data(bridge_data),.bridge_wr(bridge_wr),.bridge_q(buffer1581_q),.events(events),.write_protect(write_protect),
  .sd_lba(lba),.sd_rd(rd),.sd_wr(wr),.sd_ack(ack),.sd_buff_addr(sda),.sd_buff_dout(sdo),.sd_buff_din(sdi),.sd_buff_wr(sdwe),
  .rom_we(romwe81),.rom_addr(roma81),.rom_data(romd81),.busy(b1581),.mounted(d81mounted),.rom_loaded(d81rom),.dirty(d81dirty),.error_code(err1581),
  .io_start(io_start[1]),.io_ready(io_ready[1]),.io_done(io_done[1]),.io_error(io_error[1]),
  .io_operation(io_operation[5:3]),.io_slot(io_slot[31:16]),.io_offset(io_offset[63:32]),.io_length(io_length[21:11]));
 (* async_reg="true" *) reg mount81_meta=0,mount81_sync=0,rom81_meta=0,rom81_sync=0,wp81_meta=1,wp81_sync=1;
 always @(posedge clk_core)begin
  mount81_meta<=d81mounted;mount81_sync<=mount81_meta;rom81_meta<=d81rom;rom81_sync<=rom81_meta;
  wp81_meta<=write_protect;wp81_sync<=wp81_meta;
 end
 pocket_1581 drive1581(.clk_core(clk_core),.reset(reset_core || mode_sync!=2 || !rom81_sync),.pause(pause_core),
  .iec_atn_i(iec_atn),.iec_data_i(iec_data),.iec_clk_i(iec_clock),.iec_fclk_i(1'b1),
  .iec_data_o(data1581),.iec_clk_o(clock1581),.drive_num(2'd1),.mounted(mount81_sync),.write_protect(wp81_sync),.img_size(32'd819200),.we(writing81),.transfer_busy(transfer81),
  .clk74(clk74),.rom_we(romwe81),.rom_addr(roma81),.rom_data(romd81),
  .sd_lba(lba),.sd_rd(rd),.sd_wr(wr),.sd_ack(ack),.sd_buff_addr(sda),.sd_buff_dout(sdo),.sd_buff_din(sdi),.sd_buff_wr(sdwe));
 end else begin:without_d81
  assign data1581=1;assign clock1581=1;
  assign b1581=0;assign d81dirty=0;assign writing81=0;assign transfer81=0;
  assign err1581=0;assign buffer1581_q=0;
  assign io_start[1]=0;assign io_operation[5:3]=0;assign io_slot[31:16]=0;
  assign io_offset[63:32]=0;assign io_length[21:11]=0;
 end endgenerate
 assign data_o=data1541 & data1581;
 assign clock_o=clock1541 & clock1581;
 assign pause_request=(mode==1 && pause1541) || (switching && mode!=0 && !write_sync && !writing81_sync && !transfer81_sync);
 assign error_code=mode==1 ? err1541:mode==2 ? err1581:8'b0;
endmodule

