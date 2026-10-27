// SPDX-License-Identifier: MIT
// Dedicated D81 buffer at 0x70000800. Metadata mirror observes APF slot table.
module pocket_d81_storage(
 input wire clk,reset,enable,input wire [31:0] bridge_addr,bridge_data,input wire bridge_wr,
 output wire [31:0] bridge_q,input wire [7:0] events,input wire write_protect,
 input wire [31:0] sd_lba,input wire sd_rd,sd_wr,output wire sd_ack,
 output wire [8:0] sd_buff_addr,output wire [7:0] sd_buff_dout,
 input wire [7:0] sd_buff_din,output wire sd_buff_wr,
 output wire rom_we,output wire [14:0] rom_addr,output wire [7:0] rom_data,
 output wire busy,mounted,rom_loaded,dirty,output wire [7:0] error_code,
 output wire io_start,input wire io_ready,io_done,io_error,
 output wire [2:0] io_operation,output wire [15:0] io_slot,
 output wire [31:0] io_offset,output wire [10:0] io_length
);
 (* ramstyle="M10K" *) reg [15:0] ids[0:31];
 (* ramstyle="M10K" *) reg [31:0] sizes[0:31];
 reg [15:0] scan_id=0;reg [31:0] scan_size=0;
 reg [31:0] rom_size=0,image_size=0;
 reg [4:0] scan=0;
 reg [5:0] scan_count=0;
 reg event_pending=0;
 wire table_write=bridge_wr && bridge_addr[31:8]==24'hf80020;
 integer i;
 initial for(i=0;i<32;i=i+1)begin ids[i]=0;sizes[i]=0;end
 always @(posedge clk)begin
  scan_id<=ids[scan];scan_size<=sizes[scan];
  if(table_write)begin
   if(!bridge_addr[2])ids[bridge_addr[7:3]]<=bridge_data[15:0];
   else sizes[bridge_addr[7:3]]<=bridge_data;
  end
  if(reset)begin scan<=0;scan_count<=0;rom_size<=0;image_size<=0;event_pending<=0;end
  else begin
   scan<=scan+1'b1;
   if(scan_count<33)scan_count<=scan_count+1'b1;
   if(scan_count==0)begin rom_size<=0;image_size<=0;end
   if(scan_id==204)rom_size<=scan_size;
   if(scan_id==4)image_size<=scan_size;
   if(events[4])begin event_pending<=1;scan_count<=0;end
   else if(scan_count==33)event_pending<=0;
  end
 end
 wire [7:0] ba;wire [31:0] bq,bd,host_q;wire bw;
 assign bridge_q={host_q[7:0],host_q[15:8],host_q[23:16],host_q[31:24]};
 bram_block_dp #(.DATA(32),.ADDR(8)) file_buffer(
  .a_clk(clk),.a_wr(bridge_wr && bridge_addr[31:10]==22'h1c0002),.a_addr(bridge_addr[9:2]),
  .a_din({bridge_data[7:0],bridge_data[15:8],bridge_data[23:16],bridge_data[31:24]}),.a_dout(host_q),
  .b_clk(clk),.b_wr(bw),.b_addr(ba),.b_din(bd),.b_dout(bq));
 pocket_d81 frontend(.clk(clk),.reset(reset),.enable(enable && scan_count==33),.grant(1'b1),
  .mount_event(event_pending && scan_count==33),.rom_size(rom_size),.image_size(image_size),.write_protect(write_protect),
  .sd_lba(sd_lba),.sd_rd(sd_rd),.sd_wr(sd_wr),.sd_ack(sd_ack),
  .sd_buff_addr(sd_buff_addr),.sd_buff_dout(sd_buff_dout),.sd_buff_din(sd_buff_din),.sd_buff_wr(sd_buff_wr),
  .rom_we(rom_we),.rom_addr(rom_addr),.rom_data(rom_data),.busy(busy),.mounted(mounted),.rom_loaded(rom_loaded),.dirty(dirty),.error_code(error_code),
  .io_start(io_start),.io_ready(io_ready),.io_done(io_done),.io_error(io_error),.io_operation(io_operation),
  .io_slot(io_slot),.io_offset(io_offset),.io_length(io_length),.buffer_addr(ba),.buffer_q(bq),.buffer_we(bw),.buffer_data(bd));
endmodule
