// SPDX-License-Identifier: GPL-3.0-or-later
// EasyFlash type 32: 2x512 KiB AM29F040, 64 banks, mode register and IO2 RAM.
// ROM lives in the unused Pocket CellularRAM package, independently of REU.
// CPU/VIC addresses are prefetched as soon as they appear, before ramCE.
// Flash changes are volatile; this module does not write a CRT back to SD.
module pocket_easyflash #(
 parameter INIT_WORDS=524288,
 parameter FLASH_SECTOR_CYCLES=1000000
)(
 input wire clk,reset,active,prepare,
 input wire romL,romH,UMAXromH,IOE,IOF,mem_write,mem_ce,
 input wire [15:0] addr,input wire [7:0] data,main_data,ram_data,
 output wire exrom,game,ram_we,io_rd,
 output wire [7:0] cpu_data,io_data,
 input wire upload_start,input wire [19:0] upload_addr,input wire [7:0] upload_data,
 output wire upload_ready,output reg upload_ack=0,
 output wire [21:16] cram_a,inout wire [15:0] cram_dq,
 input wire cram_wait,
 output wire cram_clk,cram_adv_n,cram_cre,cram_ce0_n,cram_ce1_n,
 output wire cram_oe_n,cram_we_n,cram_ub_n,cram_lb_n
);
 reg [5:0] bank=0;
 reg [2:0] control=0;
 reg old_ioe=0,old_iof=0;
 wire high_chip=romH || UMAXromH;
 wire rom_select=romL || high_chip;
 wire [19:0] read_addr={high_chip,bank,addr[12:0]};
 always @(posedge clk)begin
  old_ioe<=IOE;old_iof<=IOF;
  if(!active)begin bank<=0;control<=0;end
  else if(IOE && !old_ioe && mem_write)begin
   if(addr[1])control<=data[2:0];else bank<=data[5:0];
  end
 end
 assign exrom=active ? !control[1]:1'b1;
 assign game=active ? (!control[0] && control[2]):1'b1;
 assign ram_we=active && IOF && !old_iof && mem_write;
 assign io_rd=active && IOF;
 assign io_data=ram_data;

 wire [7:0] flash0_data,flash1_data,flash0_out,flash1_out;
 wire flash0_oe,flash1_oe,req0,req1,we0,we1,ce0,ce1;
 wire [18:0] flash0_addr,flash1_addr;
 reg [7:0] flash0_in=8'hff,flash1_in=8'hff;
 wire grant0,grant1;
 am29f040 #(.MEM_READ_LATENCY(7),.SECTOR_ERASE_LAT_CYC(FLASH_SECTOR_CYCLES)) flash0(
  .clk(clk),.reset_n(active),.ce_n(!(active && mem_ce && rom_select && !high_chip)),
  .we_n(!mem_write),.addr({bank,addr[12:0]}),.dq_in(data),.dq_out(flash0_data),.dq_oe(flash0_oe),
  .mem_cycle(grant0),.mem_addr(flash0_addr),.mem_in(flash0_in),.mem_out(flash0_out),
  .mem_ce(ce0),.mem_we(we0),.mem_req(req0));
 am29f040 #(.MEM_READ_LATENCY(7),.SECTOR_ERASE_LAT_CYC(FLASH_SECTOR_CYCLES)) flash1(
  .clk(clk),.reset_n(active),.ce_n(!(active && mem_ce && rom_select && high_chip)),
  .we_n(!mem_write),.addr({bank,addr[12:0]}),.dq_in(data),.dq_out(flash1_data),.dq_oe(flash1_oe),
  .mem_cycle(grant1),.mem_addr(flash1_addr),.mem_in(flash1_in),.mem_out(flash1_out),
  .mem_ce(ce1),.mem_we(we1),.mem_req(req1));
 wire status_oe=high_chip ? flash1_oe:flash0_oe;
 wire [7:0] status_data=high_chip ? flash1_data:flash0_data;

 reg initialized=0;
 reg [18:0] init_word=0;
 reg inflight=0;
 localparam INIT=0,UPLOAD=1,PREFETCH=2,FLASH0=3,FLASH1=4;
 reg [2:0] operation=INIT;
 reg op_read=0;
 reg [19:0] op_addr=0;
 reg [18:0] cache_tag=0;
 reg [15:0] cache_word=16'hffff;
 reg cache_valid=0;
 reg [3:0] flash_gap=0;
 reg last_flash=1;
 wire physical_busy,read_avail;
 wire [15:0] physical_data;
 wire idle=!inflight && !physical_busy && !reset;
 wire want=active && rom_select && !mem_write && !status_oe;
 wire cache_hit=cache_valid && cache_tag==read_addr[19:1];
 wire miss=want && !cache_hit;
 wire init_issue=idle && prepare && !initialized;
 assign upload_ready=idle && initialized;
 wire upload_issue=upload_start && upload_ready;
 wire read_issue=idle && initialized && !prepare && miss;
 wire flash_slot=idle && initialized && !prepare && !miss && flash_gap==0;
 assign grant0=flash_slot && req0 && (!req1 || last_flash);
 assign grant1=flash_slot && req1 && (!req0 || !last_flash);
 wire issue=init_issue || upload_issue || read_issue || grant0 || grant1;
 wire physical_write=init_issue || upload_issue || (grant0 && we0) || (grant1 && we1);
 wire [19:0] address=init_issue ? {init_word,1'b0}:upload_issue ? upload_addr:
                        read_issue ? read_addr:grant0 ? {1'b0,flash0_addr}:{1'b1,flash1_addr};
 wire [7:0] write_data=init_issue ? 8'hff:upload_issue ? upload_data:grant0 ? flash0_out:flash1_out;
 wire [7:0] cached_byte=read_addr[0] ? cache_word[15:8]:cache_word[7:0];
 assign cpu_data=!active ? main_data:rom_select ? (status_oe ? status_data:cache_hit ? cached_byte:8'hff):main_data;
 psram #(.CLOCK_SPEED(31.527954)) memory(
  .clk(clk),.bank_sel(1'b0),.addr({3'b0,address[19:1]}),
  .write_en(issue && physical_write),.data_in({write_data,write_data}),
  .write_high_byte(init_issue || address[0]),.write_low_byte(init_issue || !address[0]),
  .read_en(issue && !physical_write),.read_avail(read_avail),.data_out(physical_data),.busy(physical_busy),
  .cram_a(cram_a),.cram_dq(cram_dq),.cram_wait(cram_wait),.cram_clk(cram_clk),
  .cram_adv_n(cram_adv_n),.cram_cre(cram_cre),.cram_ce0_n(cram_ce0_n),.cram_ce1_n(cram_ce1_n),
  .cram_oe_n(cram_oe_n),.cram_we_n(cram_we_n),.cram_ub_n(cram_ub_n),.cram_lb_n(cram_lb_n));
 always @(posedge clk)begin
  upload_ack<=0;
  if(flash_gap!=0)flash_gap<=flash_gap-1'b1;
  if(reset)begin
   initialized<=0;init_word<=0;inflight<=0;cache_valid<=0;flash_gap<=0;last_flash<=1;
  end else begin
   if(issue)begin
    inflight<=1;op_addr<=address;op_read<=!physical_write;
    operation<=init_issue ? INIT:upload_issue ? UPLOAD:read_issue ? PREFETCH:grant0 ? FLASH0:FLASH1;
    if(physical_write)cache_valid<=0;
    if(grant0 || grant1)begin flash_gap<=9;last_flash<=grant1;end
   end
   if(inflight && (op_read ? read_avail:!physical_busy))begin
    inflight<=0;
    case(operation)
     INIT:if(init_word==INIT_WORDS-1)initialized<=1;else init_word<=init_word+1'b1;
     UPLOAD:upload_ack<=1;
     PREFETCH:begin cache_tag<=op_addr[19:1];cache_word<=physical_data;cache_valid<=1;end
     FLASH0:if(op_read)flash0_in<=op_addr[0] ? physical_data[15:8]:physical_data[7:0];
     FLASH1:if(op_read)flash1_in<=op_addr[0] ? physical_data[15:8]:physical_data[7:0];
     default:;
    endcase
   end
  end
 end
endmodule
