// SPDX-License-Identifier: MIT
// Convert MiSTer PAL blanking to the Analogue Pocket video protocol.
// NATIVE_PIXEL_CLOCK=1 uses the 7.88 MHz pixel clock, with SKIP disabled.
// Legacy mode uses 31.53 MHz transport and accepts one in four samples.
// https://www.analogue.co/developer/docs/openfpga/bus-communication
module pocket_video #(parameter NATIVE_PIXEL_CLOCK=0, parameter RIGHT_PAD=0)(
 input wire clk,enable,
 input wire hsync,vsync,hblank,vblank,
 input wire [23:0] rgb,
 output reg video_hs=0,output reg video_vs=0,
 output reg video_de=0,output reg video_skip=0,
 output reg [23:0] video_rgb=0
);
 reg previous_hs=0,previous_vs=0;
 reg [3:0] hs_delay=0;
 reg [1:0] pixel_phase=0;
 // Complete a 384-pixel transport row without changing the 382-pixel
 // MiSTer viewport or the keyboard coordinates. Repeat the last border
 // pixel; do not sample RGB from blanking or discard any source pixels.
 // RIGHT_PAD is in native output clocks and is only used in native mode.
 reg [1:0] pad_remaining=0;
 reg [23:0] last_rgb=0;
 wire active=enable && !hblank && !vblank;
 wire padding=NATIVE_PIXEL_CLOCK && enable && !vblank && pad_remaining!=0;
 always @(posedge clk) begin
  previous_hs<=hsync;
  previous_vs<=vsync;
  // VS and HS rise together in video_sync. Delay HS by four output
  // clocks: Pocket requires a single-cycle VS, then at least three clocks
  // before HS. The horizontal porch has ample room for this delay.
  hs_delay<={hs_delay[2:0],hsync && !previous_hs};
  video_vs<=enable && vsync && !previous_vs;
  video_hs<=enable && hs_delay[3];
  if(active) begin
   last_rgb<=rgb;
   pad_remaining<=NATIVE_PIXEL_CLOCK ? RIGHT_PAD:0;
  end else if(!enable || vblank) pad_remaining<=0;
  else if(pad_remaining!=0) pad_remaining<=pad_remaining-1'b1;
  video_de<=active || padding;
  video_rgb<=active ? rgb:padding ? last_rgb:24'b0;
  // Select the third transport sample of each VIC pixel, after its data
  // has settled. DE remains high continuously; SKIP is legal only in DE.
  video_skip<=!NATIVE_PIXEL_CLOCK && active && pixel_phase!=2;
  if(active) pixel_phase<=pixel_phase+1'b1;
  else pixel_phase<=0;
 end
endmodule
