// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer 1541 CPU/VIA and direct-GCR front end with one host-managed raw track.
// The host pauses the drive before replacing/readback of a track, then waits
// for the dual-port RAM pipeline to settle before releasing pause.
module pocket_1541 #(
 parameter integer CORE_HZ=31527954
)(
 input wire clk_core,reset,pause,
 input wire iec_atn_i,iec_data_i,iec_clk_i,
 output wire iec_data_o,iec_clk_o,
 input wire mounted,write_protect,
 input wire [1:0] drive_num,
 output reg [6:0] track=34,
 output wire led,motor,writing,
 output reg modified=0,
 input wire clear_modified,
 input wire clk74,rom_we,
 input wire [13:0] rom_addr,
 input wire [7:0] rom_data,
 input wire track_we,
 input wire [9:0] track_addr,
 input wire [63:0] track_data,
 output wire [63:0] track_q
);
 // A 1541 has its own 16 MHz oscillator even on a PAL C64. Fractional enable
 // retains 1 MHz CPU / 300 rpm instead of slowing the drive with PAL clk/2.
 reg [25:0] clock_fraction=0;
 reg [3:0] phase=0;
 wire ce16=!reset && !pause && clock_fraction >= CORE_HZ-16000000;
 wire ph2_r=ce16 && phase==0;
 wire ph2_f=ce16 && phase==8;
 always @(posedge clk_core) begin
  if(reset) begin clock_fraction<=0;phase<=0;end
  else if(!pause) begin
   if(ce16) begin clock_fraction<=clock_fraction-(CORE_HZ-16000000);phase<=phase+1'b1;end
   else clock_fraction<=clock_fraction+16000000;
  end
 end

 (* ramstyle="M10K" *) reg [7:0] drive_rom[0:16383];
 wire [14:0] cpu_rom_addr;
 reg [7:0] cpu_rom_data;
 always @(posedge clk74) if(rom_we) drive_rom[rom_addr]<=rom_data;
 always @(posedge clk_core) cpu_rom_data<=drive_rom[cpu_rom_addr[13:0]];

 wire data_out,clock_out;
 wire atn_in,data_in,clock_in;
 // Open-collector bus: 1 releases a line; reset always releases both outputs.
 assign iec_data_o=reset ? 1'b1:data_out;
 assign iec_clk_o=reset ? 1'b1:clock_out;
 iecdrv_sync atn_sync(.clk(clk_core),.in(iec_atn_i),.out(atn_in));
 iecdrv_sync data_sync(.clk(clk_core),.in(iec_data_i & iec_data_o),.out(data_in));
 iecdrv_sync clock_sync(.clk(clk_core),.in(iec_clk_i & iec_clk_o),.out(clock_in));
 wire [7:0] gcr_data,write_data;
 wire [1:0] step,density;
 wire read_mode,motor_on,activity,sync_n,byte_n,gcr_we;
 assign led=!reset && activity;
 assign motor=!reset && motor_on;
 // A host must wait for the write gate to close before pausing/readback.
 assign writing=!reset && motor_on && !read_mode && mounted;
 c1541_logic logic1541(
  .clk(clk_core),.reset(reset),.ce(ce16),.ph2_r(ph2_r),.ph2_f(ph2_f),
  .iec_clk_in(clock_in),.iec_data_in(data_in),.iec_atn_in(atn_in),
  .iec_clk_out(clock_out),.iec_data_out(data_out),
  .ext_en(1'b0),.rom_addr(cpu_rom_addr),.rom_data(cpu_rom_data),
  .par_data_in(8'hff),.par_stb_in(1'b1),.par_data_out(),.par_stb_out(),
  .ds(drive_num),.din(gcr_data),.dout(write_data),.mode(read_mode),
  .stp(step),.mtr(motor_on),.freq(density),.sync_n(sync_n),.byte_n(byte_n),
  .wps_n(~write_protect),.tr00_sense_n(|track),.act(activity));

 c1541_direct_gcr #(.POCKET_TRACK_CDC(1)) gcr(
  .clk(clk_core),.ce(ce16),.reset(reset),.drive_rpm(3'b0),.drive_wobble(1'b0),
  .dout(gcr_data),.din(write_data),.mode(read_mode),.mtr(motor_on),.freq(density),
  .wps_n(~write_protect && mounted),.sync_n(sync_n),.byte_n(byte_n),.disk_present(mounted),.we(gcr_we),
  .sd_clk(clk74),.sd_buff_addr({1'b0,track_addr,3'b0}),.sd_buff_dout(track_data),
  .sd_buff_din(track_q),.sd_buff_wr(track_we));

 reg [1:0] previous_step=0;
 wire [1:0] movement=step-previous_step;
 always @(posedge clk_core) begin
  if(reset) begin track<=34;previous_step<=step;modified<=0;end
  else begin
   if(gcr_we && mounted && !write_protect) modified<=1;
   else if(clear_modified) modified<=0;
   if(ce16) begin
    previous_step<=step;
    if(motor_on && movement[0]) begin
     if(!movement[1] && track<84) track<=track+1'b1;
     else if(movement[1] && track>0) track<=track-1'b1;
    end
   end
  end
 end
endmodule
