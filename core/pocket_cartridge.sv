// SPDX-License-Identifier: GPL-3.0-or-later
// Compact Pocket integration of the original MiSTer cartridge mapper.
// One-cycle synchronous ROM reads meet VIC/CPU timing without external RAM.
// ROM_BYTES is 64 KiB by default; 128 KiB is available for separate variants.
// Action Replay receives 8 KiB volatile RAM. Larger-RAM/flash carts are rejected.
module pocket_cartridge #(parameter integer ROM_BYTES=65536, parameter OCEAN_FF_TAIL=0,parameter EASYFLASH=0)(
 input wire clk,reset,c64_reset,load_start,input wire [31:0] file_size,
 input wire byte_valid,input wire [7:0] byte_data,output wire byte_ready,
 input wire finish,output wire busy,attached,error,output wire [3:0]error_code,
 input wire romL,romH,UMAXromH,IOE,IOF,mem_write,mem_ce,
 input wire [15:0]addr_in,input wire [7:0]data_in,main_ram_data,
 input wire freeze_key,mod_key,nmi_ack,
 output wire exrom,game,IO_rom,IO_rd,output wire[7:0]IO_data,data_out,
 output wire nmi,output wire[24:0]mem_addr,
 output wire mem_ce_out,mem_write_out,output wire[7:0]mem_data_out,
 output wire [21:16] cram_a,inout wire [15:0] cram_dq,input wire cram_wait,
 output wire cram_clk,cram_adv_n,cram_cre,cram_ce0_n,cram_ce1_n,cram_oe_n,cram_we_n,cram_ub_n,cram_lb_n
);
 // Normal, Action Replay, Final Cartridge III, Simons Basic, Ocean,
 // Super Games, C64GS, Dinamic, Zaxxon and Magic Desk; ROM size still bounded.
 localparam [127:0] TYPES=(128'b1<<0)|(128'b1<<1)|(128'b1<<3)|(128'b1<<4)|
  (128'b1<<5)|(128'b1<<8)|(128'b1<<15)|(128'b1<<17)|(128'b1<<18)|(128'b1<<19)|
  (EASYFLASH ? (128'b1<<32):128'b0);
 localparam ROM_AW=$clog2(ROM_BYTES);
 localparam BANK_AW=ROM_AW-13;
 wire [7:0]cart_id,bank_num,bank_page;
 wire cart_exrom,cart_game,bank_wr,bank_hi,bank_16k;
 wire upload_start;wire[23:0]upload_addr;wire[7:0]upload_data;
 reg upload_ack=0;
 wire ef_selected=EASYFLASH && cart_id==32;
 wire ef_ready,ef_ack,ef_exrom,ef_game,ef_ram_we,ef_io_rd;
 wire [7:0] ef_data,ef_io_data;
 pocket_crt #(.MAX_PAYLOAD_BYTES(ROM_BYTES),.ALLOW_OCEAN_FF_TAIL(OCEAN_FF_TAIL),.EASYFLASH(EASYFLASH),.ALLOWED_TYPES(TYPES)) parser(
  .clk(clk),.reset(reset),.load_start(load_start),.file_size(file_size),
  .byte_valid(byte_valid),.byte_data(byte_data),.byte_ready(byte_ready),.finish(finish),
  .busy(busy),.attached(attached),.error(error),.error_code(error_code),
  .cart_id(cart_id),.cart_exrom(cart_exrom),.cart_game(cart_game),
  .bank_wr(bank_wr),.bank_hi(bank_hi),.bank_16k(bank_16k),.bank_num(bank_num),.bank_page(bank_page),
  .ram_start(upload_start),.ram_ready(ef_selected ? ef_ready:1'b1),.ram_ack(ef_selected ? ef_ack:upload_ack),.ram_addr(upload_addr),.ram_wdata(upload_data));
 (* ramstyle="M10K" *) reg[7:0]rom[0:ROM_BYTES-1];
 (* ramstyle="M10K" *) reg[7:0]cart_ram[0:8191];
 reg[7:0]rom_q,ram_q;
 reg[1:0]read_kind=0;
 reg[24:0]loaded_end=25'h200000;
 wire mapper_reset_n=attached && !reset && !c64_reset && !load_start;
 wire [24:0] legacy_addr;
 wire in_rom=legacy_addr>=25'h200000 && legacy_addr<25'h200000+ROM_BYTES && legacy_addr<loaded_end;
 wire in_ram=cart_id==1 && legacy_addr>=25'h10000 && legacy_addr<25'h12000;
 wire mapper_ce,mapper_we,mapper_req;
 wire [7:0]mapper_out,mapper_data,mapper_io_data;
 wire mapper_exrom,mapper_game,mapper_io_rom,mapper_io_rd,mapper_nmi;
 wire [7:0]memory_in=read_kind==1 ? rom_q:read_kind==2 ? ram_q:read_kind==3 ? main_ram_data:8'hff;
 always @(posedge clk)begin
  upload_ack<=upload_start;
  if(load_start)loaded_end<=25'h200000;
  else if(upload_start && !ef_selected && {1'b0,upload_addr}+1'b1>loaded_end)loaded_end<={1'b0,upload_addr}+1'b1;
  if(upload_start && !ef_selected && upload_addr>=24'h200000 && upload_addr<24'h200000+ROM_BYTES)
   rom[upload_addr[ROM_AW-1:0]]<=upload_data;
  rom_q<=rom[legacy_addr[ROM_AW-1:0]];
  ram_q<=cart_ram[ef_selected ? {5'b0,addr_in[7:0]}:legacy_addr[12:0]];
  read_kind<=mapper_reset_n && !ef_selected ? (in_rom ? 1:in_ram ? 2:legacy_addr<25'h10000 ? 3:0):0;
  if(ef_selected && ef_ram_we)cart_ram[{5'b0,addr_in[7:0]}]<=data_in;
  else if(mapper_reset_n && in_ram && mapper_ce && mapper_we)cart_ram[legacy_addr[12:0]]<=mapper_out;
 end
 generate if(EASYFLASH)begin:easyflash_port
  pocket_easyflash ef(.clk(clk),.reset(reset || load_start),.active(mapper_reset_n && ef_selected),.prepare(busy && ef_selected),
   .romL(romL),.romH(romH),.UMAXromH(UMAXromH),.IOE(IOE),.IOF(IOF),.mem_write(mem_write),.mem_ce(mem_ce),
   .addr(addr_in),.data(data_in),.main_data(main_ram_data),.ram_data(ram_q),
   .exrom(ef_exrom),.game(ef_game),.ram_we(ef_ram_we),.io_rd(ef_io_rd),.cpu_data(ef_data),.io_data(ef_io_data),
   .upload_start(upload_start && ef_selected),.upload_addr(upload_addr[19:0]),.upload_data(upload_data),.upload_ready(ef_ready),.upload_ack(ef_ack),
   .cram_a(cram_a),.cram_dq(cram_dq),.cram_wait(cram_wait),.cram_clk(cram_clk),.cram_adv_n(cram_adv_n),.cram_cre(cram_cre),
   .cram_ce0_n(cram_ce0_n),.cram_ce1_n(cram_ce1_n),.cram_oe_n(cram_oe_n),.cram_we_n(cram_we_n),.cram_ub_n(cram_ub_n),.cram_lb_n(cram_lb_n));
 end else begin:no_easyflash
  assign ef_ready=0;assign ef_ack=0;assign ef_exrom=1;assign ef_game=1;assign ef_ram_we=0;assign ef_io_rd=0;
  assign ef_data=8'hff;assign ef_io_data=8'hff;
  assign cram_a=0;assign cram_dq=16'hzzzz;assign cram_clk=0;assign cram_adv_n=1;assign cram_cre=0;
  assign cram_ce0_n=1;assign cram_ce1_n=1;assign cram_oe_n=1;assign cram_we_n=1;assign cram_ub_n=1;assign cram_lb_n=1;
 end endgenerate
 cartridge mapper(
  // Every accepted type fits in five bits. Make that bound structural so
  // synthesis removes unreachable EasyFlash/GeoRAM/large-cartridge logic.
  // The parser rejects all other IDs before attached can become true.
  .clk32(clk),.reset_n(mapper_reset_n && !ef_selected),.cart_loading(busy && !ef_selected),.cart_id({3'b000,cart_id[4:0]}),
  .cart_exrom(cart_exrom),.cart_game(cart_game),.cart_bank_hi(bank_hi),.cart_bank_16k(bank_16k),
  .cart_bank_num(bank_num),.cart_bank_addr({{(8-BANK_AW){1'b0}},bank_page[BANK_AW-1:0]}),.cart_bank_wr(bank_wr && !ef_selected),.cart_boot(1'b0),
  .exrom(mapper_exrom),.game(mapper_game),.romL(romL),.romH(romH),.UMAXromH(UMAXromH),
  .IOE(IOE),.IOF(IOF),.mem_write(mem_write),.mem_ce(mem_ce),.mem_ce_out(mapper_ce),
  .mem_write_out(mapper_we),.mem_in(memory_in),.mem_out(mapper_out),.mem_addr(legacy_addr),
  .mem_req(mapper_req),.mem_cycle(1'b0),.IO_rom(mapper_io_rom),.IO_rd(mapper_io_rd),.IO_data(mapper_io_data),
  .addr_in(addr_in),.data_in(data_in),.data_out(mapper_data),
  .freeze_key(freeze_key),.mod_key(mod_key),.nmi(mapper_nmi),.nmi_ack(nmi_ack));
 assign exrom=ef_selected ? ef_exrom:mapper_reset_n ? mapper_exrom:1'b1;
 assign game=ef_selected ? ef_game:mapper_reset_n ? mapper_game:1'b1;
 assign IO_rom=mapper_reset_n && !ef_selected && mapper_io_rom;
 assign IO_rd=ef_selected ? ef_io_rd:mapper_reset_n && mapper_io_rd;
 assign IO_data=ef_selected ? ef_io_data:mapper_reset_n ? mapper_io_data:8'hff;
 assign data_out=ef_selected ? ef_data:mapper_reset_n ? mapper_data:8'hff;
 assign nmi=mapper_reset_n && !ef_selected && mapper_nmi;
 assign mem_ce_out=mapper_reset_n && (ef_selected ? mem_ce:mapper_ce);
 assign mem_write_out=mapper_reset_n && (ef_selected ? mem_write && !((romL || romH) && ef_exrom && !ef_game):mapper_we);
 assign mem_data_out=ef_selected ? data_in:mapper_out;
 assign mem_addr=ef_selected ? {9'b0,addr_in}:legacy_addr;
endmodule
