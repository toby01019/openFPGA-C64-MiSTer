// SPDX-License-Identifier: MIT
// Fair byte-port arbitration: REU DMA, PCM reads and boot-time sample upload.
// Grants rotate even when idle: clients may assert start only after ready.
// Soft C64 resets must not reset this arbiter: outstanding writes must drain.
module pocket_ram_arbiter(
 input wire clk,reset,
 input wire [2:0] start,write,
 input wire [71:0] addr,input wire [23:0] wdata,
 output wire [2:0] ready,done,output wire [7:0] rdata,
 output wire memory_start,memory_write,output wire [23:0] memory_addr,
 output wire [7:0] memory_wdata,
 input wire memory_ready,memory_done,input wire [7:0] memory_rdata,
 output wire idle
);
 reg busy=0,grant_delay=0;reg [1:0] ticket=0,owner=0;
 assign idle=!busy && memory_ready;
 // The MiSTer REU registers start one cycle AFTER seeing ready. Reserve
 // that ticket for a second cycle, with ready low, to receive its pulse.
 assign ready=idle && !reset && !grant_delay ? (3'b001<<ticket):3'b0;
 assign done=busy && memory_done && !reset ? (3'b001<<owner):3'b0;
 assign rdata=memory_rdata;
 assign memory_start=idle && !reset && start[ticket];
 assign memory_write=write[ticket];
 assign memory_addr=addr[ticket*24+:24];
 assign memory_wdata=wdata[ticket*8+:8];
 always @(posedge clk)begin
  if(reset)begin busy<=0;ticket<=0;owner<=0;grant_delay<=0;end
  else if(busy)begin if(memory_done)begin busy<=0;ticket<=owner==2 ? 0:owner+1'b1;grant_delay<=0;end end
  else if(memory_start)begin owner<=ticket;busy<=1;grant_delay<=0;end
  else if(!grant_delay)grant_delay<=1;
  else begin ticket<=ticket==2 ? 0:ticket+1'b1;grant_delay<=0;end
 end
endmodule
