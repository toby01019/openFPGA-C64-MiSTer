// SPDX-License-Identifier: MIT
// Shared REU/PCM RAM and acknowledged APF sample-bank preload protocol.
module pocket_sample_memory(
 input wire clk,reset,c64_reset,enabled,paused,
 input wire [25:0] command,input wire command_valid,output wire command_ready,
 input wire reu_start,reu_write,input wire [23:0] reu_addr,input wire [7:0] reu_out,
 output wire reu_ready,reu_done,output wire [7:0] reu_in,
 input wire io_select,io_write,input wire [7:0] io_addr,io_data,
 output wire io_claim,output wire [7:0] io_q,
 input wire signed [17:0] sid_left,sid_right,output wire signed [17:0] left,right,
 output reg bank_valid=0,output reg [20:0] bank_size=0,
 output wire underrun,
 output wire [21:16] cram_a,inout wire [15:0] cram_dq,input wire cram_wait,
 output wire cram_clk,cram_adv_n,cram_cre,cram_ce0_n,cram_ce1_n,
 output wire cram_oe_n,cram_we_n,cram_ub_n,cram_lb_n
);
 reg uploading=0;reg[20:0] received=0;
 wire audio_command=command[25:24]==3 && command[21];
 wire [1:0] operation=command[23:22];
 wire [2:0] ready,done;wire[7:0]ram_data;
 wire pcm_start;wire[23:0]pcm_addr;
 wire physical_start,physical_write,physical_ready,physical_done,idle;
 wire [23:0] physical_addr;wire[7:0]physical_out,physical_in;
 assign command_ready=!audio_command ? 1'b1:
  operation==0 ? (!uploading || received>=bank_size || ready[2]):idle;
 wire accept=command_valid && command_ready && audio_command;
 wire host_start=accept && operation==0 && uploading && received<bank_size;
 always @(posedge clk)begin
  if(reset)begin bank_valid<=0;bank_size<=0;received<=0;uploading<=0;end
  else if(accept)case(operation)
   1:begin bank_valid<=0;received<=0;bank_size<=command[20:0];
    uploading<=command[20:0]>=2 && command[20:0]<=1048576 && !command[0];end
   0:if(host_start)received<=received+1'b1;else begin uploading<=0;bank_valid<=0;end
   2:begin bank_valid<=uploading && received==bank_size;uploading<=0;end
   3:begin bank_valid<=0;uploading<=0;end
  endcase
 end
 pocket_pcm pcm(.clk(clk),.reset(c64_reset),.enabled(enabled),.paused(paused),
  .bank_valid(bank_valid),.bank_size(bank_size),.io_select(io_select),.io_write(io_write),.io_addr(io_addr),.io_data(io_data),
  .io_claim(io_claim),.io_q(io_q),.ram_start(pcm_start),.ram_addr(pcm_addr),.ram_ready(ready[1]),.ram_done(done[1]),.ram_data(ram_data),
  .sid_left(sid_left),.sid_right(sid_right),.left(left),.right(right),.underrun(underrun));
 pocket_ram_arbiter arbiter(.clk(clk),.reset(reset),.start({host_start,pcm_start,reu_start}),.write({1'b1,1'b0,reu_write}),
  .addr({3'b0,received,pcm_addr,reu_addr}),.wdata({command[7:0],8'b0,reu_out}),.ready(ready),.done(done),.rdata(ram_data),
  .memory_start(physical_start),.memory_write(physical_write),.memory_addr(physical_addr),.memory_wdata(physical_out),
  .memory_ready(physical_ready),.memory_done(physical_done),.memory_rdata(physical_in),.idle(idle));
 assign reu_ready=ready[0];assign reu_done=done[0];assign reu_in=ram_data;
 pocket_psram memory(.clk(clk),.reset(reset),.start(physical_start),.write(physical_write),
  .addr(physical_addr),.wdata(physical_out),.ready(physical_ready),.done(physical_done),.rdata(physical_in),
  .cram_a(cram_a),.cram_dq(cram_dq),.cram_wait(cram_wait),.cram_clk(cram_clk),.cram_adv_n(cram_adv_n),.cram_cre(cram_cre),
  .cram_ce0_n(cram_ce0_n),.cram_ce1_n(cram_ce1_n),.cram_oe_n(cram_oe_n),.cram_we_n(cram_we_n),.cram_ub_n(cram_ub_n),.cram_lb_n(cram_lb_n));
endmodule
