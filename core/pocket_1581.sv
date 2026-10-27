// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer 1581 with uploaded ROM and a clock-safe 512-byte host-sector staging RAM.
// Host protocol (clk74): sd_rd/sd_wr and LBA remain valid until sd_ack rises.
// Keep sd_ack high while transferring the 512 bytes; falling sd_ack completes
// the transaction. On writes, data is already staged before sd_wr is asserted.
module pocket_1581 #(parameter integer CORE_HZ=31527954)(
 input wire clk_core,reset,pause,
 input wire iec_atn_i,iec_data_i,iec_clk_i,iec_fclk_i,
 output wire iec_data_o,iec_clk_o,iec_fclk_o,
 input wire [1:0] drive_num,
 input wire mounted,write_protect,
 input wire [31:0] img_size,
 output wire led,power,
 output wire [7:0] track,
 output wire we,output wire transfer_busy,
 input wire clk74,rom_we,
 input wire [14:0] rom_addr,
 input wire [7:0] rom_data,
 output reg [31:0] sd_lba,
 output reg sd_rd,sd_wr,
 input wire sd_ack,
 input wire [8:0] sd_buff_addr,
 input wire [7:0] sd_buff_dout,
 output wire [7:0] sd_buff_din,
 input wire sd_buff_wr
);
 initial begin sd_lba=0;sd_rd=0;sd_wr=0;end
 reg [25:0] clock_fraction=0;
 reg [2:0] phase=0;
 wire ce16=!reset && !pause && clock_fraction>=CORE_HZ-16000000;
 wire ph2_r=ce16 && phase==0;
 wire ph2_f=ce16 && phase==4;
 wire wd_ce=ce16 && !phase[0];
 always @(posedge clk_core) begin
  if(reset) begin clock_fraction<=0;phase<=0;end
  else if(!pause) begin
   if(ce16) begin clock_fraction<=clock_fraction-(CORE_HZ-16000000);phase<=phase+1'b1;end
   else clock_fraction<=clock_fraction+16000000;
  end
 end
 (* ramstyle="M10K" *) reg [7:0] drive_rom[0:32767];
 wire [14:0] cpu_rom_addr;
 reg [7:0] cpu_rom_data;
 always @(posedge clk74) if(rom_we) drive_rom[rom_addr]<=rom_data;
 always @(posedge clk_core) cpu_rom_data<=drive_rom[cpu_rom_addr];

 wire atn_in,data_in,clock_in,fast_in,data_out,clock_out,fast_out;
 wire activity,power_on;
 assign iec_data_o=reset ? 1'b1:data_out;
 assign iec_clk_o=reset ? 1'b1:clock_out;
 assign iec_fclk_o=reset ? 1'b1:fast_out;
 assign led=!reset && activity;
 assign power=!reset && power_on;
 iecdrv_sync atn_sync(.clk(clk_core),.in(iec_atn_i),.out(atn_in));
 iecdrv_sync data_sync(.clk(clk_core),.in(iec_data_i & iec_data_o),.out(data_in));
 iecdrv_sync clock_sync(.clk(clk_core),.in(iec_clk_i & iec_clk_o),.out(clock_in));
 iecdrv_sync fast_sync(.clk(clk_core),.in(iec_fclk_i & iec_fclk_o),.out(fast_in));
 reg mounted_previous=0,mount_event=0;
 always @(posedge clk_core) begin
  if(reset) begin mounted_previous<=0;mount_event<=0;end
  else begin mount_event<=mounted!=mounted_previous;mounted_previous<=mounted;end
 end

 wire [31:0] fdc_lba;
 wire fdc_rd,fdc_wr;
 reg fdc_ack=0;
 wire [7:0] fdc_data;
 reg [8:0] copy_index=0;
 wire [7:0] staging_data;
 wire fdc_buffer_write;
 c1581_drv #(.LIVE_WRITE_PROTECT(1)) drive(
  .clk(clk_core),.reset(reset),.ce(ce16),.wd_ce(wd_ce),.ph2_r(ph2_r),.ph2_f(ph2_f),
  .img_mounted(mount_event),.img_readonly(write_protect),.img_size(mounted ? img_size:32'b0),
  .drive_num(drive_num),.act_led(activity),.pwr_led(power_on),.track(track),.we(we),
  .iec_atn_i(atn_in),.iec_data_i(data_in),.iec_clk_i(clock_in),.iec_fclk_i(fast_in),
  .iec_data_o(data_out),.iec_clk_o(clock_out),.iec_fclk_o(fast_out),
  .par_data_i(8'hff),.par_stb_i(1'b1),.par_data_o(),.par_stb_o(),
  .rom_addr(cpu_rom_addr),.rom_data(cpu_rom_data),.clk_sys(clk_core),
  .sd_lba(fdc_lba),.sd_rd(fdc_rd),.sd_wr(fdc_wr),.sd_ack(fdc_ack),
  .sd_buff_addr(copy_index),.sd_buff_dout(staging_data),.sd_buff_din(fdc_data),.sd_buff_wr(fdc_buffer_write));

 // Bundled-data request/ack toggles. LBA and direction stay fixed until done.
 reg request_toggle=0,request_write=0;
 reg [31:0] request_lba=0;
 reg done_toggle=0;
 (* async_reg="true" *) reg request_meta=0,request_sync=0,done_meta=0,done_sync=0;
 reg [1:0] host_state=0;
 always @(posedge clk74) begin
  request_meta<=request_toggle;request_sync<=request_meta;
  if(reset) begin request_meta<=0;request_sync<=0;host_state<=0;done_toggle<=0;sd_rd<=0;sd_wr<=0;sd_lba<=0;end
  else case(host_state)
   0:if(request_sync!=done_toggle) begin
    sd_lba<=request_lba;sd_rd<=!request_write;sd_wr<=request_write;host_state<=1;
   end
   1:if(sd_ack) begin sd_rd<=0;sd_wr<=0;host_state<=2;end
   2:if(!sd_ack) begin done_toggle<=request_sync;host_state<=0;end
   default:host_state<=0;
  endcase
 end
 always @(posedge clk_core) begin
  if(reset) begin done_meta<=0;done_sync<=0;end
  else begin done_meta<=done_toggle;done_sync<=done_meta;end
 end

 localparam IDLE=0,WRITE_WAIT1=1,WRITE_WAIT2=2,WRITE_CAPTURE=3,ISSUE_WRITE=4,
  WAIT_HOST=5,READ_WAIT=6,READ_COPY=7,READ_HOLD=8,READ_NEXT=9,ACK_HOLD=10,COOLDOWN=11;
 reg [3:0] transfer_state=IDLE;
 assign transfer_busy=transfer_state!=IDLE;
 reg [3:0] delay_count=0;
 assign fdc_buffer_write=transfer_state==READ_COPY;
 pocket_sector_ram staging_ram(.host_clk(clk74),.host_addr(sd_buff_addr),.host_we(sd_buff_wr),
  .host_data(sd_buff_dout),.host_q(sd_buff_din),.core_clk(clk_core),.core_addr(copy_index),
  .core_we(transfer_state==WRITE_CAPTURE),.core_data(fdc_data),.core_q(staging_data));
 // Transfer FSM deliberately continues while the drive CPU/FDC CE is paused.
 always @(posedge clk_core) begin
  if(reset) begin
   transfer_state<=IDLE;request_toggle<=0;request_write<=0;request_lba<=0;
   fdc_ack<=0;copy_index<=0;delay_count<=0;
  end else case(transfer_state)
   IDLE:if(fdc_rd) begin
    request_write<=0;request_lba<=fdc_lba;request_toggle<=~request_toggle;transfer_state<=WAIT_HOST;
   end else if(fdc_wr) begin
    if(write_protect || !mounted) begin fdc_ack<=1;delay_count<=0;transfer_state<=ACK_HOLD;end
    else begin request_write<=1;request_lba<=fdc_lba;copy_index<=0;transfer_state<=WRITE_WAIT1;end
   end
   WRITE_WAIT1:transfer_state<=WRITE_WAIT2;
   WRITE_WAIT2:transfer_state<=WRITE_CAPTURE;
   WRITE_CAPTURE:if(copy_index==511) transfer_state<=ISSUE_WRITE;
    else begin copy_index<=copy_index+1'b1;transfer_state<=WRITE_WAIT1;end
   ISSUE_WRITE:begin request_toggle<=~request_toggle;transfer_state<=WAIT_HOST;end
   WAIT_HOST:if(done_sync==request_toggle) begin
    fdc_ack<=1;copy_index<=0;delay_count<=0;
    transfer_state<=request_write ? ACK_HOLD:READ_WAIT;
   end
   READ_WAIT:transfer_state<=READ_COPY;
   READ_COPY:transfer_state<=READ_HOLD;
   READ_HOLD:transfer_state<=READ_NEXT;
   READ_NEXT:if(copy_index==511) begin delay_count<=0;transfer_state<=ACK_HOLD;end
    else begin copy_index<=copy_index+1'b1;transfer_state<=READ_WAIT;end
   ACK_HOLD:if(delay_count==3) begin fdc_ack<=0;delay_count<=0;transfer_state<=COOLDOWN;end
    else delay_count<=delay_count+1'b1;
   COOLDOWN:if(delay_count==7) transfer_state<=IDLE;else delay_count<=delay_count+1'b1;
   default:transfer_state<=IDLE;
  endcase
 end
endmodule

// Symmetric true dual-port sector RAM, one read cycle on each clock.
// Explicit primitive avoids Quartus rejecting inferred dual-clock write ports.
module pocket_sector_ram(
 input wire host_clk,core_clk,input wire [8:0] host_addr,core_addr,
 input wire host_we,core_we,input wire [7:0] host_data,core_data,
 output wire [7:0] host_q,core_q
);
`ifdef POCKET_ALTERA_RAM
 wire clock_a=host_clk,clock_b=core_clk,write_a=host_we,write_b=core_we;
 altsyncram #(
  .operation_mode("BIDIR_DUAL_PORT"),.intended_device_family("Cyclone V"),.ram_block_type("M10K"),
  .width_a(8),.widthad_a(9),.numwords_a(512),.width_b(8),.widthad_b(9),.numwords_b(512),
  .outdata_reg_a("UNREGISTERED"),.outdata_reg_b("UNREGISTERED"),
  .address_reg_b("CLOCK1"),.indata_reg_b("CLOCK1"),.wrcontrol_wraddress_reg_b("CLOCK1"),
  .clock_enable_input_a("BYPASS"),.clock_enable_input_b("BYPASS"),
  .clock_enable_output_a("BYPASS"),.clock_enable_output_b("BYPASS"),
  .read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),.read_during_write_mode_port_b("NEW_DATA_NO_NBE_READ"),
  .read_during_write_mode_mixed_ports("DONT_CARE"),.power_up_uninitialized("TRUE")
 ) memory(.clock0(clock_a),.clock1(clock_b),.clocken0(1'b1),.clocken1(1'b1),.clocken2(1'b1),.clocken3(1'b1),
  .aclr0(1'b0),.aclr1(1'b0),.addressstall_a(1'b0),.addressstall_b(1'b0),
  .address_a(host_addr),.data_a(host_data),.wren_a(write_a),.byteena_a(1'b1),.rden_a(1'b1),.q_a(host_q),
  .address_b(core_addr),.data_b(core_data),.wren_b(write_b),.byteena_b(1'b1),.rden_b(1'b1),.q_b(core_q),.eccstatus());
`else
 reg [7:0] memory[0:511];reg [7:0] hq,cq;
 assign host_q=hq;assign core_q=cq;
 always @(posedge host_clk)begin
  if(host_we)begin memory[host_addr]<=host_data;hq<=host_data;end else hq<=memory[host_addr];
 end
 always @(posedge core_clk)begin
  if(core_we)begin memory[core_addr]<=core_data;cq<=core_data;end else cq<=memory[core_addr];
 end
`endif
endmodule
