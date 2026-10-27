//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

    //
    // physical connections
    //

    ///////////////////////////////////////////////////
    // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

    input wire clk_74a,  // mainclk1
    input wire clk_74b,  // mainclk1
`ifdef __VERILATOR__
    input wire clk_32mhz,
`endif
    output wire debug_iec_atn,
    output wire debug_iec_data,
    output wire debug_iec_clock,
    output wire debug_1mhz_ph1_en,
    output wire debug_1mhz_ph2_en,

    output wire debug_c64_cpu_valid,
    output wire debug_c64_cpu_sync,
    output wire [15:0] debug_c64_cpu_addr,
    output wire [7:0] debug_c64_cpu_data,
    output wire [63:0]debug_c64_cpu_regs,

    output wire debug_c1541_cpu_valid,
    output wire debug_c1541_cpu_sync,
    output wire [15:0] debug_c1541_cpu_addr,
    output wire [7:0] debug_c1541_cpu_data,
    output wire [63:0]debug_c1541_cpu_regs,

    ///////////////////////////////////////////////////
    // cartridge interface
    // switches between 3.3v and 5v mechanically
    // output enable for multibit translators controlled by pic32

    // GBA AD[15:8]
    inout  wire [7:0] cart_tran_bank2,
    output wire       cart_tran_bank2_dir,

    // GBA AD[7:0]
    inout  wire [7:0] cart_tran_bank3,
    output wire       cart_tran_bank3_dir,

    // GBA A[23:16]
    inout  wire [7:0] cart_tran_bank1,
    output wire       cart_tran_bank1_dir,

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    inout  wire [7:4] cart_tran_bank0,
    output wire       cart_tran_bank0_dir,

    // GBA CS2#/RES#
    inout  wire cart_tran_pin30,
    output wire cart_tran_pin30_dir,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output wire cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    inout  wire cart_tran_pin31,
    output wire cart_tran_pin31_dir,

    // infrared
    input  wire port_ir_rx,
    output wire port_ir_tx,
    output wire port_ir_rx_disable,

    // GBA link port
    inout  wire port_tran_si,
    output wire port_tran_si_dir,
    inout  wire port_tran_so,
    output wire port_tran_so_dir,
    inout  wire port_tran_sck,
    output wire port_tran_sck_dir,
    inout  wire port_tran_sd,
    output wire port_tran_sd_dir,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

    output wire [21:16] cram0_a,
    inout  wire [ 15:0] cram0_dq,
    input  wire         cram0_wait,
    output wire         cram0_clk,
    output wire         cram0_adv_n,
    output wire         cram0_cre,
    output wire         cram0_ce0_n,
    output wire         cram0_ce1_n,
    output wire         cram0_oe_n,
    output wire         cram0_we_n,
    output wire         cram0_ub_n,
    output wire         cram0_lb_n,

    output wire [21:16] cram1_a,
    inout  wire [ 15:0] cram1_dq,
    input  wire         cram1_wait,
    output wire         cram1_clk,
    output wire         cram1_adv_n,
    output wire         cram1_cre,
    output wire         cram1_ce0_n,
    output wire         cram1_ce1_n,
    output wire         cram1_oe_n,
    output wire         cram1_we_n,
    output wire         cram1_ub_n,
    output wire         cram1_lb_n,

    ///////////////////////////////////////////////////
    // sdram, 512mbit 16bit

    output wire [12:0] dram_a,
    output wire [ 1:0] dram_ba,
    inout  wire [15:0] dram_dq,
    output wire [ 1:0] dram_dqm,
    output wire        dram_clk,
    output wire        dram_cke,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,

    ///////////////////////////////////////////////////
    // sram, 1mbit 16bit

    output wire [16:0] sram_a,
    inout  wire [15:0] sram_dq,
    output wire        sram_oe_n,
    output wire        sram_we_n,
    output wire        sram_ub_n,
    output wire        sram_lb_n,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input wire vblank,

    ///////////////////////////////////////////////////
    // i/o to 6515D breakout usb uart

    output wire dbg_tx,
    input  wire dbg_rx,

    ///////////////////////////////////////////////////
    // i/o pads near jtag connector user can solder to

    output wire user1,
    input  wire user2,

    ///////////////////////////////////////////////////
    // RFU internal i2c bus

    inout  wire aux_sda,
    output wire aux_scl,

    ///////////////////////////////////////////////////
    // RFU, do not use
    output wire vpll_feed,


    //
    // logical connections
    //

    ///////////////////////////////////////////////////
    // video, audio output to scaler
    output wire [23:0] video_rgb,
    output wire        video_rgb_clock,
    output wire        video_rgb_clock_90,
    output wire        video_de,
    output wire        video_skip,
    output wire        video_vs,
    output wire        video_hs,

    output wire audio_mclk,
    input  wire audio_adc,
    output wire audio_dac,
    output wire audio_lrck,

    ///////////////////////////////////////////////////
    // bridge bus connection
    // synchronous to clk_74a
    output wire        bridge_endian_little,
    input  wire [31:0] bridge_addr,
    input  wire        bridge_rd,
    output reg  [31:0] bridge_rd_data,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    ///////////////////////////////////////////////////
    // controller data
    //
    // key bitmap:
    //   [0]    dpad_up
    //   [1]    dpad_down
    //   [2]    dpad_left
    //   [3]    dpad_right
    //   [4]    face_a
    //   [5]    face_b
    //   [6]    face_x
    //   [7]    face_y
    //   [8]    trig_l1
    //   [9]    trig_r1
    //   [10]   trig_l2
    //   [11]   trig_r2
    //   [12]   trig_l3
    //   [13]   trig_r3
    //   [14]   face_select
    //   [15]   face_start
    // joy values - unsigned
    //   [ 7: 0] lstick_x
    //   [15: 8] lstick_y
    //   [23:16] rstick_x
    //   [31:24] rstick_y
    // trigger values - unsigned
    //   [ 7: 0] ltrig
    //   [15: 8] rtrig
    //
    input wire cont_update,
    input wire [31:0] cont1_key,
    input wire [31:0] cont2_key,
    input wire [31:0] cont3_key,
    input wire [31:0] cont4_key,
    input wire [31:0] cont1_joy,
    input wire [31:0] cont2_joy,
    input wire [31:0] cont3_joy,
    input wire [31:0] cont4_joy,
    input wire [15:0] cont1_trig,
    input wire [15:0] cont2_trig,
    input wire [15:0] cont3_trig,
    input wire [15:0] cont4_trig

);

  // not using the IR port, so turn off both the LED, and
  // disable the receive circuit to save power
  assign port_ir_tx              = 0;
  assign port_ir_rx_disable      = 1;

  // bridge endianness
  assign bridge_endian_little    = 0;

  // cart is unused, so set all level translators accordingly
  // directions are 0:IN, 1:OUT
  assign cart_tran_bank3         = 8'hzz;
  assign cart_tran_bank3_dir     = 1'b0;
  assign cart_tran_bank2         = 8'hzz;
  assign cart_tran_bank2_dir     = 1'b0;
  assign cart_tran_bank1         = 8'hzz;
  assign cart_tran_bank1_dir     = 1'b0;
  assign cart_tran_bank0         = 4'hf;
  assign cart_tran_bank0_dir     = 1'b1;
  assign cart_tran_pin30         = 1'b0;  // reset or cs2, we let the hw control it by itself
  assign cart_tran_pin30_dir     = 1'bz;
  assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
  assign cart_tran_pin31         = 1'bz;  // input
  assign cart_tran_pin31_dir     = 1'b0;  // input

  // link port is input only
  assign port_tran_so            = 1'bz;
  assign port_tran_so_dir        = 1'b0;  // SO is output only
  assign port_tran_si            = 1'bz;
  assign port_tran_si_dir        = 1'b0;  // SI is input only
  assign port_tran_sck           = 1'bz;
  assign port_tran_sck_dir       = 1'b0;  // clock direction can change
  assign port_tran_sd            = 1'bz;
  assign port_tran_sd_dir        = 1'b0;  // SD is input and not used

  // tie off the rest of the pins we are not using
  // CellularRAM1 backs EasyFlash; CellularRAM0 remains dedicated to REU.

  assign dram_a                  = 'h0;
  assign dram_ba                 = 'h0;
  assign dram_dq                 = {16{1'bZ}};
  assign dram_dqm                = 'h0;
  assign dram_clk                = 'h0;
  assign dram_cke                = 'h0;
  assign dram_ras_n              = 'h1;
  assign dram_cas_n              = 'h1;
  assign dram_we_n               = 'h1;

  assign sram_a                  = 'h0;
  assign sram_dq                 = {16{1'bZ}};
  assign sram_oe_n               = 1;
  assign sram_we_n               = 1;
  assign sram_ub_n               = 1;
  assign sram_lb_n               = 1;

  assign dbg_tx                  = 1'bZ;
  assign user1                   = 1'bZ;
  assign aux_scl                 = 1'bZ;
  assign vpll_feed               = 1'bZ;


 wire clk_core,clk_video,clk_video90,pll_locked;
 wire reset_n;
`ifndef __VERILATOR__
 reg [4:0] pll_reset_count=31;
 reg [17:0] pll_watchdog=0;
 always @(posedge clk_74a) begin
   if(pll_reset_count!=0) begin pll_reset_count<=pll_reset_count-1'b1;pll_watchdog<=0;end
   else if(pll_locked) pll_watchdog<=0;
   else if(&pll_watchdog) begin pll_reset_count<=31;pll_watchdog<=0;end
   else pll_watchdog<=pll_watchdog+1'b1;
 end
 mf_pllbase mp1(.refclk(clk_74a),.rst(pll_reset_count!=0),.outclk_0(clk_video),
 .outclk_1(clk_video90),.outclk_2(clk_core),.locked(pll_locked));
`else
 assign clk_core=clk_32mhz;assign pll_locked=1;
 reg [1:0] sim_video_div=0;
 // Pixel clock samples halfway between core rising edges, like the PLL.
 always @(negedge clk_32mhz) sim_video_div<=sim_video_div+1'b1;
 assign clk_video=sim_video_div[1];assign clk_video90=clk_video;
`endif
 (* async_reg="true" *) reg lock_meta=0,lock_sync=0;
 always @(posedge clk_74a) begin lock_meta<=pll_locked;lock_sync<=lock_meta;end
 wire cpu_req,cpu_ack;
 wire [31:0] cpu_addr,cpu_data,cpu_rdata,cmd_rdata;
 wire [3:0] cpu_wstrb;
 wire os_menu;
 core_bridge_cmd icb(.clk(clk_74a),.reset_n(reset_n),
 .bridge_endian_little(bridge_endian_little),.bridge_addr(bridge_addr),
 .bridge_rd(bridge_rd),.bridge_rd_data(cmd_rdata),.bridge_wr(bridge_wr),
 .bridge_wr_data(bridge_wr_data),.status_boot_done(lock_sync),
 .status_setup_done(lock_sync),.status_running(reset_n),.osnotify_inmenu(os_menu),
 .i_cpu_clk(clk_74a),.i_cpu_req(cpu_req),.o_cpu_ack_pulse(cpu_ack),
 .i_cpu_addr(cpu_addr),.i_cpu_wdata(cpu_data),.i_cpu_wstrb(cpu_wstrb),.o_cpu_rdata(cpu_rdata));
 wire reader_ready,reader_start,reader_done,reader_error;
 wire [7:0] slot_events;
 wire [15:0] file_slot;
 wire [31:0] file_offset;
 wire [10:0] file_length;
 wire [7:0] buffer_addr;
 wire [31:0] buffer_data,table_data,table_bridge_data,buffer_bridge_data;
 wire [5:0] table_addr;
 wire host_write,host_done,core_run,pause_request;
 wire loader_storage_requested;
 wire [25:0] host_data;
 wire [7:0] auto_keys,error_code;
 wire [5:0] load_state;
 wire c64_paused;
 wire disk_busy,disk_pause,disk_mounted,disk_rom_loaded;
 wire drive_rom_we,drive_track_we,disk_commit;
 wire [13:0] drive_rom_addr;
 wire [7:0] drive_rom_data,disk_error,disk_state;
 wire [9:0] drive_track_addr;
 wire [63:0] drive_track_data,drive_track_q;
 wire [6:0] disk_loaded_track,drive_track;
 wire [1:0] disk_format;
 wire [15:0] disk_track_len;
 wire drive_led,drive_motor,drive_modified,drive_writing;
 reg disk_write_protect=1;
 wire disk_write_ready,disk_save_pause,disk_clear_modified;
 wire [9:0] disk_track_read_addr;
 (* async_reg="true" *) reg dirty_meta=0,dirty_sync=0,writing_meta=0,writing_sync=0;
 (* async_reg="true" *) reg protect_meta=1,protect_sync=1,clear_meta=0,clear_sync=0;
 wire drive_data_out,drive_clock_out;
 (* async_reg="true" *) reg [6:0] head_meta=34,head_sync=34;
 (* async_reg="true" *) reg need_meta=0,need_sync=0;
 wire need_track_core;
 (* async_reg="true" *) reg paused_meta=0,paused_sync=0;
 always @(posedge clk_74a) begin paused_meta<=c64_paused;paused_sync<=paused_meta;end
 always @(posedge clk_74a) begin
  head_meta<=drive_track;head_sync<=head_meta;need_meta<=need_track_core;need_sync<=need_meta;
  dirty_meta<=drive_modified;dirty_sync<=dirty_meta;
  writing_meta<=drive_writing;writing_sync<=writing_meta;
 end
 wire [2:0] file_start_all,file_ready_all,file_done_all,file_error_all;
 wire [8:0] file_operation_all;wire [47:0] file_slot_all;wire [95:0] file_offset_all;wire [32:0] file_length_all;
 wire [31:0] buffer9_q,buffer81_q;
 wire disk9_pause,drive9_data_out,drive9_clock_out;wire [7:0] disk9_error;wire [1:0] drive9_active;
 wire drive9_reset_safe;
 wire restart_core=bridge_wr && bridge_addr==32'ha0000014 && bridge_wr_data[0];
 reg [1:0] drive9_mode=0;
 pocket_file_arbiter file_arbiter(.clk(clk_74a),.reset(!reset_n),.start(file_start_all),.ready(file_ready_all),
 .done(file_done_all),.error(file_error_all),.operation(file_operation_all),.slot(file_slot_all),.offset(file_offset_all),.length(file_length_all),
 .events(slot_events),.cpu_req(cpu_req),.cpu_addr(cpu_addr),.cpu_data(cpu_data),.cpu_wstrb(cpu_wstrb),.cpu_ack(cpu_ack),.cpu_rdata(cpu_rdata));
 pocket_storage #(.EXTERNAL_IO(1)) storage(.clk(clk_74a),.reset(!reset_n),.bridge_addr(bridge_addr),
 .bridge_wr_data(bridge_wr_data),.bridge_wr(bridge_wr),.table_bridge_data(table_bridge_data),.buffer_bridge_data(buffer_bridge_data),
 .ext_start(file_start_all[0]),.ext_ready(file_ready_all[0]),.ext_done(file_done_all[0]),.ext_error(file_error_all[0]),.ext_events(slot_events),
 .ext_operation(file_operation_all[2:0]),.ext_slot(file_slot_all[15:0]),.ext_offset(file_offset_all[31:0]),.ext_length(file_length_all[10:0]),
 .loader_idle(load_state==12 && !loader_storage_requested),.loader_start(reader_start),.loader_ready(reader_ready),
 .loader_done(reader_done),.loader_error(reader_error),.loader_slot(file_slot),.loader_offset(file_offset),.loader_length(file_length),
 .loader_buffer_addr(buffer_addr),.loader_buffer_data(buffer_data),.loader_table_addr(table_addr),.loader_table_data(table_data),
 .head_track(head_sync),.need_track(need_sync && head_meta==head_sync),.paused(paused_sync),
 .disk_busy(disk_busy),.disk_pause(disk_pause),.mounted(disk_mounted),.rom_loaded(disk_rom_loaded),
 .rom_we(drive_rom_we),.rom_addr(drive_rom_addr),.rom_data(drive_rom_data),
 .track_we(drive_track_we),.track_addr(drive_track_addr),.track_data(drive_track_data),
 .commit_toggle(disk_commit),.loaded_track(disk_loaded_track),.disk_error(disk_error),.disk_state(disk_state),
 .disk_format(disk_format),.track_len(disk_track_len),
 .dirty(dirty_sync),.writing(writing_sync),.write_protect(disk_write_protect),.write_enable(1'b1),
 .save_pause(disk_save_pause),.clear_modified(disk_clear_modified),.write_ready(disk_write_ready),
 .track_read_addr(disk_track_read_addr),.track_read_q(drive_track_q));
 wire cart_busy,cart_error,cart_attached;
 (* async_reg="true" *) reg cart_busy_meta=0,cart_busy_sync=0,cart_error_meta=0,cart_error_sync=0;
 always @(posedge clk_74a)begin
  cart_busy_meta<=cart_busy;cart_busy_sync<=cart_busy_meta;
  cart_error_meta<=cart_error;cart_error_sync<=cart_error_meta;
 end
 pocket_loader #(.ENABLE_CRT(1),.ENABLE_PCM(1)) loader(.clk(clk_74a),.reset(!reset_n),.events(slot_events),
 .restart(restart_core),.restart_safe(!dirty_sync && !writing_sync && drive9_reset_safe),
 .cart_busy(cart_busy_sync),.cart_error(cart_error_sync),
 .storage_hold(disk_busy),.storage_requested(loader_storage_requested),
 .read_start(reader_start),.read_ready(reader_ready),.read_done(reader_done),.read_error(reader_error),
 .read_slot(file_slot),.read_offset(file_offset),.read_length(file_length),
 .buffer_addr(buffer_addr),.buffer_data(buffer_data),.table_addr(table_addr),.table_data(table_data),
 .write_valid(host_write),.write_data(host_data),.write_done(host_done),.core_run(core_run),
 .pause_request(pause_request),.paused(paused_sync),.auto_keys(auto_keys),
 .error_code(error_code),.debug_state(load_state));
 reg joystick_port1=0;
 reg [1:0] keyboard_transparency=0;
 wire keyboard_transparency_toggle;
 (* async_reg="true" *) reg transparency_toggle_meta=0,transparency_toggle_sync=0;
 reg transparency_toggle_seen=0;
 always @(posedge clk_74a)begin
  transparency_toggle_meta<=keyboard_transparency_toggle;
  transparency_toggle_sync<=transparency_toggle_meta;
  if(!reset_n)transparency_toggle_seen<=transparency_toggle_sync;
  else if(transparency_toggle_seen!=transparency_toggle_sync)
   transparency_toggle_seen<=transparency_toggle_sync;
 end
 reg [1:0] reu_config=0;
 reg [2:0] palette_config=0;
 reg pcm_enabled=0;
 reg [1:0] dock_keyboard_mode=1;
 reg sid_model=1; // Preserve the existing 8580 sound as the default.
 always @(posedge clk_74a) if(bridge_wr && bridge_addr==32'ha0000000) joystick_port1<=bridge_wr_data[0];
 always @(posedge clk_74a)begin
  if(bridge_wr && bridge_addr==32'ha0000004)
   keyboard_transparency<=bridge_wr_data[1:0]==3 ? 2'b0:bridge_wr_data[1:0];
  else if(reset_n && transparency_toggle_seen!=transparency_toggle_sync)
   keyboard_transparency<=keyboard_transparency==2 ? 2'b0:keyboard_transparency+1'b1;
 end
 always @(posedge clk_74a) if(bridge_wr && bridge_addr==32'ha0000008)
  disk_write_protect<=bridge_wr_data[0];
 always @(posedge clk_74a) if(bridge_wr && bridge_addr==32'ha0000010)
  drive9_mode<=bridge_wr_data[1:0]>=2 ? 2'b0:bridge_wr_data[1:0];
 always @(posedge clk_74a) if(bridge_wr && bridge_addr==32'ha000000c)
  reu_config<=bridge_wr_data[1:0];
 always @(posedge clk_74a) if(bridge_wr && bridge_addr==32'ha0000018)
  palette_config<=bridge_wr_data[2:0];
 always @(posedge clk_74a) if(bridge_wr && bridge_addr==32'ha0000020)pcm_enabled<=bridge_wr_data[0];
 always @(posedge clk_74a) if(bridge_wr && bridge_addr==32'ha0000024)
  dock_keyboard_mode<=bridge_wr_data[1:0]==3 ? 2'b0:bridge_wr_data[1:0];
 always @(posedge clk_74a) if(bridge_wr && bridge_addr==32'ha000001c)
  sid_model<=bridge_wr_data[0];
 always @* begin
  if(bridge_addr[31:8]==24'hf80020) bridge_rd_data=table_bridge_data;
  else if(bridge_addr[31:10]==22'h1c0000) bridge_rd_data=buffer_bridge_data;
  else if(bridge_addr[31:10]==22'h1c0001) bridge_rd_data=buffer9_q;
  else if(bridge_addr[31:10]==22'h1c0002) bridge_rd_data=buffer81_q;
  else if(bridge_addr==32'ha0000100) bridge_rd_data={18'b0,load_state,error_code};
  else if(bridge_addr==32'ha0000104) bridge_rd_data={3'b0,disk_format,disk_rom_loaded,disk_mounted,drive_motor,drive_led,head_sync,disk_error,disk_state};
  else if(bridge_addr==32'ha0000004) bridge_rd_data={30'b0,keyboard_transparency};
  else if(bridge_addr==32'ha0000008) bridge_rd_data={31'b0,disk_write_protect};
  else if(bridge_addr==32'ha000000c) bridge_rd_data={30'b0,reu_config};
  else if(bridge_addr==32'ha0000010) bridge_rd_data={30'b0,drive9_mode};
  else if(bridge_addr==32'ha0000014) bridge_rd_data=0;
  else if(bridge_addr==32'ha0000018) bridge_rd_data={29'b0,palette_config};
  else if(bridge_addr==32'ha000001c) bridge_rd_data={31'b0,sid_model};
  else if(bridge_addr==32'ha0000020) bridge_rd_data={31'b0,pcm_enabled};
  else if(bridge_addr==32'ha0000024) bridge_rd_data={30'b0,dock_keyboard_mode};
  else if(bridge_addr==32'ha0000108) bridge_rd_data={22'b0,drive9_active,disk9_error};
  else bridge_rd_data=cmd_rdata;
 end
 (* async_reg="true" *) reg reset_meta=0,reset_sync=0,run_meta=0,run_sync=0;
 (* async_reg="true" *) reg pause_meta=1,pause_sync=1,menu_meta=0,menu_sync=0;
 (* async_reg="true" *) reg port_meta=0,port_sync=0;
 (* async_reg="true" *) reg [31:0] key_meta=0,key_sync=0;
 (* async_reg="true" *) reg [7:0] auto_meta=0,auto_sync=0;
 (* async_reg="true" *) reg keyboard_ready_meta=0,keyboard_ready_sync=0;
 (* async_reg="true" *) reg [1:0] transparency_meta=0,transparency_sync=0;
 (* async_reg="true" *) reg [1:0] reu_config_meta=0,reu_config_sync=0;
 (* async_reg="true" *) reg [2:0] palette_meta=0,palette_sync=0;
 (* async_reg="true" *) reg sid_model_meta=1,sid_model_sync=1;
 (* async_reg="true" *)reg pcm_meta=0,pcm_sync=0;
 (* async_reg="true" *)reg [1:0] dock_mode_meta=1,dock_mode_sync=1;
 (* async_reg="true" *) reg disk_mounted_meta=0,disk_mounted_sync=0,rom_ready_meta=0,rom_ready_sync=0;
 (* async_reg="true" *) reg commit_meta=0,commit_sync=0;
 reg commit_seen=0,cached_valid=0;
 reg [6:0] cached_track=34;
 always @(posedge clk_core) begin
  reset_meta<=reset_n;reset_sync<=reset_meta;run_meta<=core_run;run_sync<=run_meta;
  pause_meta<=pause_request || disk_pause || disk9_pause;pause_sync<=pause_meta;menu_meta<=os_menu;menu_sync<=menu_meta;
  port_meta<=joystick_port1;port_sync<=port_meta;key_meta<=cont1_key;key_sync<=key_meta;
  auto_meta<=auto_keys;auto_sync<=auto_meta;
  keyboard_ready_meta<=load_state==12;keyboard_ready_sync<=keyboard_ready_meta;
  transparency_meta<=keyboard_transparency;transparency_sync<=transparency_meta;
  reu_config_meta<=reu_config;reu_config_sync<=reu_config_meta;
  palette_meta<=palette_config;palette_sync<=palette_meta;
  sid_model_meta<=sid_model;sid_model_sync<=sid_model_meta;
  pcm_meta<=pcm_enabled;pcm_sync<=pcm_meta;
  dock_mode_meta<=dock_keyboard_mode;dock_mode_sync<=dock_mode_meta;
  disk_mounted_meta<=disk_mounted;disk_mounted_sync<=disk_mounted_meta;
  rom_ready_meta<=disk_rom_loaded;rom_ready_sync<=rom_ready_meta;
  commit_meta<=disk_commit;commit_sync<=commit_meta;
  protect_meta<=disk_write_protect || !disk_write_ready;protect_sync<=protect_meta;
  clear_meta<=disk_clear_modified;clear_sync<=clear_meta;
  if(!reset_sync || !run_sync) begin cached_valid<=0;commit_seen<=commit_sync;end
  else if(commit_sync!=commit_seen) begin
   commit_seen<=commit_sync;cached_valid<=1;cached_track<=disk_loaded_track;
  end
 end
 assign need_track_core=disk_mounted_sync && (!cached_valid || cached_track!=drive_track);
 wire core_reset=!reset_sync || !run_sync;
 wire command_valid,command_ready;
 wire [25:0] command_data;
 wire cart_byte_ready,pcm_command_ready;
 wire pcm_command=command_data[25:24]==3 && command_data[21];
 assign command_ready=(!run_sync || c64_paused) &&
  (pcm_command ? pcm_command_ready:(command_data[25:22]!=4'b1100 || cart_byte_ready || cart_error || !cart_busy));
 pocket_mailbox memory_commands(.src_clk(clk_74a),.src_reset(!reset_n),
 .src_valid(host_write),.src_data(host_data),.src_done(host_done),
 .dst_clk(clk_core),.dst_reset(!reset_sync),.dst_valid(command_valid),
 .dst_data(command_data),.dst_ready(command_ready));
 wire command_fire=command_valid && command_ready;
 wire [15:0] c64_addr;
 wire [7:0] c64_data_out;
 wire [7:0] c64_data_in;
 reg [7:0] main_ram_q;
 wire [24:0] cart_mem_addr;
 wire [7:0] cart_data,cart_io_data,cart_mem_data;
 wire cart_ce,cart_we,cart_io_rom,cart_io_rd,cart_nmi,cart_game,cart_exrom;
 wire c64_roml,c64_romh,c64_umax,c64_ioe,c64_nmi_ack,c64_mod;
 wire [15:0] main_addr=cart_attached ? cart_mem_addr[15:0]:c64_addr;
 wire main_ce=cart_attached ? cart_ce:ram_ce;
 wire main_we=cart_attached ? cart_we && cart_mem_addr<25'h10000:ram_we;
 assign c64_data_in=cart_attached ? cart_data:main_ram_q;
 wire ram_ce,ram_we;
 (* ramstyle="M10K" *) reg [7:0] main_ram[0:65535];
 always @(posedge clk_core) begin
  if(command_fire && command_data[25:24]==0)
    main_ram[command_data[23:8]]<=command_data[7:0];
  else if(main_ce && main_we && !core_reset) main_ram[main_addr]<=cart_attached ? cart_mem_data:c64_data_out;
  if(main_ce) main_ram_q<=main_ram[main_addr];
 end
 wire [10:0] ps2_key;
 wire keyboard_visible,keyboard_restore,keyboard_macro,keyboard_capture;
 wire [3:0] keyboard_row,keyboard_col;
 wire [63:0] virtual_keys,keyboard_sticky;
 wire [63:0] dock_keys;
 wire dock_restore,dock_keyboard_connected;
 pocket_dock_keyboard dock_keyboard(.host_clk(clk_74a),.host_reset(!reset_n),.link_reset(!reset_sync),
  .report_valid(cont_update),.report_key(cont3_key),.report_joy(cont3_joy),.report_trig(cont3_trig),
  .clk(clk_core),.reset(core_reset),.blocked(menu_sync || !keyboard_ready_sync),.mode(dock_mode_sync),
  .matrix(dock_keys),.restore(dock_restore),.connected(dock_keyboard_connected));
 wire [63:0] combined_keys=virtual_keys|dock_keys;
 wire combined_restore=keyboard_restore|dock_restore;
 wire restore_signal;
 reg cart_start_pulse=0,cart_finish_pulse=0,cart_eject_pulse=0;
 reg [31:0] cart_selected_size=0;
 always @(posedge clk_core)begin
  cart_start_pulse<=command_fire && !pcm_command && command_data[25:22]==4'b1101;
  cart_finish_pulse<=command_fire && !pcm_command && command_data[25:22]==4'b1110;
  cart_eject_pulse<=command_fire && !pcm_command && command_data[25:22]==4'b1111;
  if(command_fire && !pcm_command && command_data[25:22]==4'b1101)cart_selected_size<={10'b0,command_data[21:0]};
 end
 pocket_cartridge #(.ROM_BYTES(73728),.OCEAN_FF_TAIL(1),.EASYFLASH(1)) cartridge_port(.clk(clk_core),
 .reset(!reset_sync || cart_eject_pulse),.c64_reset(core_reset),
 .load_start(cart_start_pulse),.file_size(cart_selected_size),
 .byte_valid(command_fire && !pcm_command && command_data[25:22]==4'b1100),.byte_data(command_data[7:0]),.byte_ready(cart_byte_ready),
 .finish(cart_finish_pulse),.busy(cart_busy),.attached(cart_attached),.error(cart_error),
 .romL(c64_roml),.romH(c64_romh),.UMAXromH(c64_umax),.IOE(c64_ioe),.IOF(c64_iof),
 .mem_write(ram_we),.mem_ce(ram_ce),.addr_in(c64_addr),.data_in(c64_data_out),.main_ram_data(main_ram_q),
 .freeze_key(restore_signal),.mod_key(c64_mod),.nmi_ack(c64_nmi_ack),
 .exrom(cart_exrom),.game(cart_game),.IO_rom(cart_io_rom),.IO_rd(cart_io_rd),.IO_data(cart_io_data),
 .data_out(cart_data),.nmi(cart_nmi),.mem_addr(cart_mem_addr),.mem_ce_out(cart_ce),.mem_write_out(cart_we),.mem_data_out(cart_mem_data),
 .cram_a(cram1_a),.cram_dq(cram1_dq),.cram_wait(cram1_wait),.cram_clk(cram1_clk),.cram_adv_n(cram1_adv_n),.cram_cre(cram1_cre),
 .cram_ce0_n(cram1_ce0_n),.cram_ce1_n(cram1_ce1_n),.cram_oe_n(cram1_oe_n),.cram_we_n(cram1_we_n),.cram_ub_n(cram1_ub_n),.cram_lb_n(cram1_lb_n));
 pocket_keyboard virtual_keyboard(.clk(clk_core),.reset(core_reset),.blocked(menu_sync || !keyboard_ready_sync),
 .buttons(key_sync[15:0]),.visible(keyboard_visible),.selected_row(keyboard_row),.selected_col(keyboard_col),
 .sticky(keyboard_sticky),.matrix(virtual_keys),.restore(keyboard_restore),.macro_busy(keyboard_macro),.capture(keyboard_capture),
 .transparency_toggle(keyboard_transparency_toggle));
 wire [7:0] physical_keys={key_sync[6],3'b0,key_sync[8],key_sync[9],key_sync[14],key_sync[15]};
 pocket_keys keyboard(.clk(clk_core),.reset(core_reset),
 .desired(auto_sync | ((menu_sync || keyboard_capture) ? 8'b0:physical_keys)),.ps2_key(ps2_key));
 wire [6:0] joy=(menu_sync || keyboard_capture) ? 7'b0:{2'b0,key_sync[4:0]};
 wire [17:0] audio_left,audio_right,mixed_left,mixed_right;
 wire pcm_io;wire [7:0]pcm_io_data;
 wire [7:0] red,green,blue;
 wire raw_hs,raw_vs;
 wire iec_atn,iec_data,iec_clk;
 wire c64_iof,reu_dma_req,reu_dma_cycle,reu_dma_we,reu_ext_cycle,reu_irq;
 wire [15:0] reu_dma_addr;
 wire [7:0] reu_dma_out,reu_dma_in,reu_cpu_data;
 wire reu_ram_start,reu_ram_ready,reu_ram_done,reu_ram_write;
 wire [23:0] reu_ram_addr;
 wire [7:0] reu_ram_out,reu_ram_in;
 wire reu_io=c64_iof && |reu_config_sync && !cart_io_rd && !pcm_io;
 pocket_reu reu(.clk(clk_core),.reset(core_reset),.enable(!c64_paused),
  .cfg(reu_config_sync),.wrap(1'b0),.dma_req(reu_dma_req),.dma_cycle(reu_dma_cycle),
  .dma_addr(reu_dma_addr),.dma_dout(reu_dma_out),.dma_din(reu_dma_in),.dma_we(reu_dma_we),
  .ram_cycle(reu_ext_cycle),.ram_ready(reu_ram_ready),.ram_ack(reu_ram_done),.ram_start(reu_ram_start),
  .ram_addr(reu_ram_addr),.ram_dout(reu_ram_out),.ram_din(reu_ram_in),.ram_we(reu_ram_write),
  .cpu_addr(c64_addr),.cpu_dout(c64_data_out),.cpu_din(reu_cpu_data),.cpu_we(ram_we),.cpu_cs(c64_iof && !cart_io_rd && !pcm_io),.irq(reu_irq));
 pocket_sample_memory reu_memory(.clk(clk_core),.reset(!reset_sync),.c64_reset(core_reset),.enabled(pcm_sync),.paused(c64_paused),
  .command(command_data),.command_valid(command_fire && pcm_command),.command_ready(pcm_command_ready),
  .reu_start(reu_ram_start),.reu_write(reu_ram_write),.reu_addr(reu_ram_addr),.reu_out(reu_ram_out),
  .reu_ready(reu_ram_ready),.reu_done(reu_ram_done),.reu_in(reu_ram_in),
  .io_select(c64_iof && !cart_io_rd),.io_write(ram_we),.io_addr(c64_addr[7:0]),.io_data(c64_data_out),
  .io_claim(pcm_io),.io_q(pcm_io_data),.sid_left(audio_left),.sid_right(audio_right),.left(mixed_left),.right(mixed_right),
  .bank_valid(),.bank_size(),.underrun(),
  .cram_a(cram0_a),.cram_dq(cram0_dq),.cram_wait(cram0_wait),.cram_clk(cram0_clk),
  .cram_adv_n(cram0_adv_n),.cram_cre(cram0_cre),.cram_ce0_n(cram0_ce0_n),.cram_ce1_n(cram0_ce1_n),
  .cram_oe_n(cram0_oe_n),.cram_we_n(cram0_we_n),.cram_ub_n(cram0_ub_n),.cram_lb_n(cram0_lb_n));
 wire iec_bus_data=iec_data & drive_data_out & drive9_data_out;
 wire iec_bus_clock=iec_clk & drive_clock_out & drive9_clock_out;
 pocket_1541 drive8(.clk_core(clk_core),.reset(core_reset || !rom_ready_sync),.pause(c64_paused),
 .iec_atn_i(iec_atn),.iec_data_i(iec_bus_data),.iec_clk_i(iec_bus_clock),
 .iec_data_o(drive_data_out),.iec_clk_o(drive_clock_out),.mounted(disk_mounted_sync),.write_protect(protect_sync),
 .drive_num(2'd0),.track(drive_track),.led(drive_led),.motor(drive_motor),.writing(drive_writing),
 .modified(drive_modified),.clear_modified(clear_sync),
 .clk74(clk_74a),.rom_we(drive_rom_we),.rom_addr(drive_rom_addr),.rom_data(drive_rom_data),
 .track_we(drive_track_we),.track_addr(disk_save_pause ? disk_track_read_addr:drive_track_addr),.track_data(drive_track_data),.track_q(drive_track_q));
 pocket_drive9 #(.ENABLE_D81(0)) drive9(.clk74(clk_74a),.clk_core(clk_core),.reset_host(!reset_n),.reset_core(core_reset),.pause_core(c64_paused),.paused_host(paused_sync),
 .reset_safe(drive9_reset_safe),
 .requested_mode(drive9_mode),.write_protect(disk_write_protect),.host_enable(load_state==12),
 .bridge_addr(bridge_addr),.bridge_data(bridge_wr_data),.bridge_wr(bridge_wr),.events(slot_events),
 .buffer1541_q(buffer9_q),.buffer1581_q(buffer81_q),.iec_atn(iec_atn),.iec_data(iec_bus_data),.iec_clock(iec_bus_clock),
 .data_o(drive9_data_out),.clock_o(drive9_clock_out),.pause_request(disk9_pause),.active_mode(drive9_active),.error_code(disk9_error),
 .io_start(file_start_all[2:1]),.io_ready(file_ready_all[2:1]),.io_done(file_done_all[2:1]),.io_error(file_error_all[2:1]),
 .io_operation(file_operation_all[8:3]),.io_slot(file_slot_all[47:16]),.io_offset(file_offset_all[95:32]),.io_length(file_length_all[32:11]));
 fpga64_sid_iec c64(
.clk32(clk_core),
.reset_n(!core_reset),
.bios(2'b00),
.pause(pause_sync),
.pause_out(c64_paused),
.ps2_key(ps2_key),
.virtual_keys(combined_keys),
.virtual_restore(combined_restore),
.kbd_reset(core_reset),
.shift_mod(2'b11),
.ramAddr(c64_addr),
.ramDin(c64_data_in),
.ramDout(c64_data_out),
.ramCE(ram_ce),
.ramWE(ram_we),
.io_cycle(),
.ext_cycle(reu_ext_cycle),
.refresh(),
.cia_mode(1'b0),
.turbo_mode(2'b00),
.turbo_speed(2'b00),
.vic_variant(2'b00),
.ntscMode(1'b0),
.hsync(raw_hs),
.vsync(raw_vs),
.palette(palette_sync),
.r(red),
.g(green),
.b(blue),
.game(cart_game),
.exrom(cart_exrom),
.io_rom(cart_io_rom),
.io_ext(cart_io_rd | pcm_io | reu_io),
.io_data(cart_io_rd ? cart_io_data:pcm_io ? pcm_io_data:reu_cpu_data),
.irq_n(1'b1),
.nmi_n(~(restore_signal | cart_nmi)),
.nmi_ack(c64_nmi_ack),
.romL(c64_roml),
.romH(c64_romh),
.UMAXromH(c64_umax),
.IOE(c64_ioe),
.IOF(c64_iof),
.freeze_key(restore_signal),
.mod_key(c64_mod),
.tape_play(),
.tape_rew(),
.tape_stop(),
.tape_ff(),
.tape_reset_counter(),
.dma_req(reu_dma_req),
.dma_cycle(reu_dma_cycle),
.dma_addr(reu_dma_addr),
.dma_dout(reu_dma_out),
.dma_din(reu_dma_in),
.dma_we(reu_dma_we),
.irq_ext_n(~reu_irq),
.joyA(port_sync ? joy:7'b0),
.joyB(port_sync ? 7'b0:joy),
.pot1(8'hff),
.pot2(8'hff),
.pot3(8'hff),
.pot4(8'hff),
.audio_l(audio_left),
.audio_r(audio_right),
.sid_filter(2'b11),
.sid_ver({2{sid_model_sync}}),
.sid_mode(3'b000),
.sid_cfg(4'b0),
.sid_fc_off_l(13'b0),
.sid_fc_off_r(13'b0),
.sid_ld_clk(clk_core),
.sid_ld_addr(12'b0),
.sid_ld_data(16'b0),
.sid_ld_wr(1'b0),
.sid_digifix(1'b1),
.pb_i(8'hff),
.pb_o(),
.pa2_i(1'b1),
.pa2_o(),
.pc2_n_o(),
.flag2_n_i(1'b1),
.sp2_i(1'b1),
.sp2_o(),
.sp1_i(1'b1),
.sp1_o(),
.cnt2_i(1'b1),
.cnt2_o(),
.cnt1_i(1'b1),
.cnt1_o(),
.iec_data_o(iec_data),
.iec_data_i(iec_bus_data),
.iec_clk_o(iec_clk),
.iec_clk_i(iec_bus_clock),
.iec_atn_o(iec_atn),
.c64rom_addr(command_data[21:8]),
.c64rom_data(command_data[7:0]),
.c64rom_wr(command_fire && command_data[25:24]==1),
.c64char_wr(command_fire && command_data[25:24]==2),
.cass_motor(),
.cass_write(),
.cass_sense(1'b1),
.cass_read(1'b1)
);
 wire hb,vb,blanker_hs,blanker_vs;
 video_sync blanker(.clk32(clk_core),.pause(c64_paused),.hsync(raw_hs),.vsync(raw_vs),
 .ntsc(1'b0),.wide(1'b0),.hsync_out(blanker_hs),.vsync_out(blanker_vs),.hblank(hb),.vblank(vb));
 assign video_rgb_clock=clk_video;
 assign video_rgb_clock_90=clk_video90;
 wire [23:0] keyboard_rgb;
 pocket_keyboard_video #(.PIPELINED(1)) keyboard_overlay(.clk(clk_core),.pause(c64_paused),
 .vsync(blanker_vs),.active(!hb && !vb),.visible(keyboard_visible && !menu_sync),
 .rgb({red,green,blue}),.selected_row(keyboard_row),.selected_col(keyboard_col),
 .sticky(keyboard_sticky),.held(combined_keys),.macro_busy(keyboard_macro),
 .transparency(transparency_sync),.mixed_rgb(keyboard_rgb));
 // One physical pixel per clock: 7.88 MHz, no scaler SKIP pulses.
 // The PLL clocks are related; STA must time the core-to-video paths.
 // Pixel phase is half a core cycle late (15.859 ns), providing setup and
 // hold margin on both sides instead of capturing on a coincident edge.
 // Finish the renderer in its own domain before the 4:1 transfer. Register
 // blanking and sync alongside RGB so border pixels cannot be displaced.
 // Keep the complete renderer before this clock-domain boundary. Retiming
 // overlay logic beyond it leaves only half a core cycle for that logic.
 (* preserve, dont_retime *) reg [23:0] video_stage_rgb=0;
 (* preserve, dont_retime *) reg [4:0] video_stage_control=5'b00011;
 reg [4:0] overlay_control[0:3];
 integer overlay_index,overlay_shift;
 initial for(overlay_index=0;overlay_index<4;overlay_index=overlay_index+1)overlay_control[overlay_index]=5'b00011;
 always @(posedge clk_core) begin
  overlay_control[0]<={run_sync && !c64_paused,blanker_hs,blanker_vs,hb,vb};
  for(overlay_shift=1;overlay_shift<4;overlay_shift=overlay_shift+1)overlay_control[overlay_shift]<=overlay_control[overlay_shift-1];
  video_stage_rgb<=keyboard_rgb;
  video_stage_control<=overlay_control[3];
 end
 // 382 source pixels plus two repeated right-border pixels = 384 on wire.
 // Keep this in agreement with video.json; overlay coordinates stay 382 wide.
 pocket_video #(.NATIVE_PIXEL_CLOCK(1),.RIGHT_PAD(2)) video_adapter(.clk(clk_video),.enable(video_stage_control[4]),
 .hsync(video_stage_control[3]),.vsync(video_stage_control[2]),
 .hblank(video_stage_control[1]),.vblank(video_stage_control[0]),.rgb(video_stage_rgb),
 .video_hs(video_hs),.video_vs(video_vs),.video_de(video_de),
 .video_skip(video_skip),.video_rgb(video_rgb));
 pocket_audio audio(.clk74(clk_74a),.reset74(!reset_n),.core_clk(clk_core),
 .core_reset(!reset_sync),.left(mixed_left),.right(mixed_right),
 .mclk(audio_mclk),.lrck(audio_lrck),.dac(audio_dac));
 assign debug_iec_atn=iec_atn;assign debug_iec_data=iec_bus_data;assign debug_iec_clock=iec_bus_clock;
 assign debug_1mhz_ph1_en=0;assign debug_1mhz_ph2_en=0;
 assign debug_c64_cpu_valid=0;assign debug_c64_cpu_sync=0;
 assign debug_c64_cpu_addr=c64_addr;assign debug_c64_cpu_data=c64_data_out;assign debug_c64_cpu_regs=0;
 assign debug_c1541_cpu_valid=0;assign debug_c1541_cpu_sync=0;
 assign debug_c1541_cpu_addr=0;assign debug_c1541_cpu_data=0;assign debug_c1541_cpu_regs=0;
endmodule

