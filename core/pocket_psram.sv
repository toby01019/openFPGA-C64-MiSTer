// SPDX-License-Identifier: GPL-3.0-or-later
// Byte interface to one 16-MiB Pocket CellularRAM package (two 8-MiB dies).
// Reset discards handshake results but lets an active pin cycle finish safely.
// Memory contents, including the forbidden-last-word shadows, survive reset.
module pocket_psram #(parameter CLOCK_SPEED=31.527954)(
 input wire clk,reset,start,write,
 input wire [23:0] addr,
 input wire [7:0] wdata,
 output wire ready,
 output reg done=0,
 output reg [7:0] rdata=0,
 output wire [21:16] cram_a,
 inout wire [15:0] cram_dq,
 input wire cram_wait,
 output wire cram_clk,cram_adv_n,cram_cre,cram_ce0_n,cram_ce1_n,
 output wire cram_oe_n,cram_we_n,cram_ub_n,cram_lb_n
);
 localparam IDLE=0,LAUNCH=1,WAIT_ACCESS=2,DRAIN=3;
 reg [1:0] state=DRAIN;
 reg [23:0] saved_addr=0;
 reg [7:0] saved_data=0;
 reg saved_write=0,busy_seen=0;
 reg [15:0] last_word0=0,last_word1=0;
 wire physical_busy,read_avail;
 wire [15:0] physical_data;
 wire launch=state==LAUNCH && !reset;
 assign ready=!reset && state==IDLE && !physical_busy;
 psram #(.CLOCK_SPEED(CLOCK_SPEED)) physical(
  .clk(clk),.bank_sel(saved_addr[23]),.addr(saved_addr[22:1]),
  .write_en(launch && saved_write),.data_in({saved_data,saved_data}),
  .write_high_byte(saved_addr[0]),.write_low_byte(!saved_addr[0]),
  .read_en(launch && !saved_write),.read_avail(read_avail),.data_out(physical_data),.busy(physical_busy),
  .cram_a(cram_a),.cram_dq(cram_dq),.cram_wait(cram_wait),.cram_clk(cram_clk),
  .cram_adv_n(cram_adv_n),.cram_cre(cram_cre),.cram_ce0_n(cram_ce0_n),.cram_ce1_n(cram_ce1_n),
  .cram_oe_n(cram_oe_n),.cram_we_n(cram_we_n),.cram_ub_n(cram_ub_n),.cram_lb_n(cram_lb_n));
 always @(posedge clk) begin
  done<=0;
  if(reset) begin state<=DRAIN;busy_seen<=0;end
  else case(state)
   DRAIN:if(!physical_busy) state<=IDLE;
   IDLE:if(start && ready) begin
    // Never physically access a die's software-register/last-word address.
    if(addr[22:1]==22'h3fffff) begin
     if(write) begin
      if(addr[23]) begin
       if(addr[0])last_word1[15:8]<=wdata;else last_word1[7:0]<=wdata;
      end else begin
       if(addr[0])last_word0[15:8]<=wdata;else last_word0[7:0]<=wdata;
      end
     end else if(addr[23]) rdata<=addr[0] ? last_word1[15:8]:last_word1[7:0];
     else rdata<=addr[0] ? last_word0[15:8]:last_word0[7:0];
     done<=1;
    end else begin
     saved_addr<=addr;saved_data<=wdata;saved_write<=write;busy_seen<=0;state<=LAUNCH;
    end
   end
   LAUNCH:state<=WAIT_ACCESS;
   WAIT_ACCESS:begin
    if(physical_busy)busy_seen<=1;
    if((saved_write && busy_seen && !physical_busy) || (!saved_write && read_avail)) begin
     if(!saved_write)rdata<=saved_addr[0] ? physical_data[15:8]:physical_data[7:0];
     done<=1;state<=IDLE;
    end
   end
   default:state<=DRAIN;
  endcase
 end
endmodule
