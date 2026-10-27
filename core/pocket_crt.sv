// SPDX-License-Identifier: GPL-3.0-or-later
// Streaming C64 CRT v1.0 reader. Format: VICE manual, CRT cartridge format.
// Metadata is provisional while busy; attach only after attached=1 at clean EOF.
// Payload pages match MiSTer's cartridge ROM window at 0x200000.
module pocket_crt #(parameter integer MAX_PAYLOAD_BYTES=2097152,
 parameter ALLOW_OCEAN_FF_TAIL=0,parameter EASYFLASH=0,
 parameter [127:0] ALLOWED_TYPES={128{1'b1}})(
 input wire clk,reset,load_start,
 input wire [31:0] file_size,
 input wire byte_valid,input wire [7:0] byte_data,output wire byte_ready,
 input wire finish,
 output reg busy,attached,error,output reg [3:0] error_code,
 output reg [7:0] cart_id,output reg cart_exrom,cart_game,
 output reg bank_wr,bank_hi,bank_16k,
 output reg [7:0] bank_num,bank_page,
 output reg ram_start,input wire ram_ready,ram_ack,
 output reg [23:0] ram_addr,output reg [7:0] ram_wdata
);
 initial begin busy=0;attached=0;error=0;error_code=0;cart_id=0;cart_exrom=1;cart_game=1;bank_wr=0;bank_hi=0;bank_16k=0;bank_num=0;bank_page=0;ram_start=0;ram_addr=0;ram_wdata=0;end
 localparam IDLE=0,HEADER=1,CHECK_HEADER=2,CHIP=3,CHECK_CHIP=4,
  PAYLOAD=5,WAIT_WRITE=6,MIRROR=7,WAIT_MIRROR=8,COMPLETE_CHIP=9,FAILED=10;
 reg[3:0]state=IDLE;
 reg[7:0]header[0:63],chip[0:15];
 reg[5:0]index=0;
 reg[31:0]expected=0,received=0;
 reg eof_seen=0;
 reg[8:0]pages=0,chip_count=0;
 reg[15:0]payload_pos=0,payload_length=0;
 reg mirror=0;
 reg[1:0]chip_pages=0;
 reg[127:0]seen=0;
 wire[31:0]header_length={header[16],header[17],header[18],header[19]};
 wire[15:0]version={header[20],header[21]},kind={header[22],header[23]};
 wire[31:0]packet_length={chip[4],chip[5],chip[6],chip[7]};
 wire[15:0]chip_type={chip[8],chip[9]},chip_bank={chip[10],chip[11]};
 wire[15:0]load_address={chip[12],chip[13]},image_length={chip[14],chip[15]};
 wire high_chip=load_address!=16'h8000;
 // A full 512 KiB Ocean image may have erased trailing banks. Validate
 // every omitted byte as FF, preserving all 64 bank declarations so the
 // mapper retains the original 8 KiB /GAME configuration. This is only
 // legal for consecutive ROML banks; other excess payload still fails.
 wire erased_ocean_tail=ALLOW_OCEAN_FF_TAIL && cart_id==5 &&
  pages>=(MAX_PAYLOAD_BYTES/8192) && pages<64 && chip_bank==pages &&
  load_address==16'h8000 && image_length==8192 && chip_type==0;
 wire[6:0]map_index={chip_bank[5:0],high_chip};
 localparam [127:0] SIGNATURE="C64 CARTRIDGE   ";
 function supported(input[15:0]id);
 begin case(id)
  0,1,3,4,5,7,8,9,10,13,15,17,18,19,20,21,22,28,32,33,36,43,54,57,60,83,85,99:supported=1;
  default:supported=0;
 endcase end endfunction
 assign byte_ready=busy && !eof_seen && received<expected &&
  (state==HEADER || state==CHIP || (state==PAYLOAD && ram_ready));
 task fail(input[3:0]code);
 begin error<=1;error_code<=code;attached<=0;busy<=0;state<=FAILED;end endtask
 always @(posedge clk) begin
  ram_start<=0;bank_wr<=0;
  if(reset)begin state<=IDLE;busy<=0;attached<=0;error<=0;error_code<=0;eof_seen<=0;end
  else if(load_start)begin
   state<=HEADER;busy<=1;attached<=0;error<=0;error_code<=0;
   expected<=file_size;received<=0;index<=0;eof_seen<=0;pages<=0;chip_count<=0;seen<=0;
   cart_id<=0;cart_exrom<=1;cart_game<=1;
   if(file_size<80 || file_size>32'h210040)fail(1);
  end else if(busy)begin
   if(finish)eof_seen<=1;
   if(byte_valid && byte_ready)received<=received+1'b1;
   if(byte_valid && received>=expected) fail(1);
   else case(state)
    HEADER:begin
     if(eof_seen)fail(7);
     else if(byte_valid && byte_ready)begin
      header[index]<=byte_data;
      if(index<16 && byte_data!=(SIGNATURE >> ((15-index)*8) & 8'hff))fail(2);
      else if(index==63)begin state<=CHECK_HEADER;index<=0;end
      else index<=index+1'b1;
     end
    end
    CHECK_HEADER:begin
     if(header_length!=64 || version!=16'h0100)fail(3);
     else if(!supported(kind) || kind>127 || !ALLOWED_TYPES[kind[6:0]])fail(4);
     else if(header[24]>1 || header[25]>1)fail(3);
     else begin cart_id<=kind[7:0];cart_exrom<=header[24][0];cart_game<=header[25][0];state<=CHIP;end
    end
    CHIP:begin
     if(eof_seen)begin
      if(received==expected && index==0 && chip_count!=0)begin
       if(cart_id==0 && ((!cart_exrom && !seen[0]) || (!cart_game && !seen[1]) || (cart_exrom && cart_game)))fail(6);
       else if(cart_id==18 && pages!=3)fail(6);
       else begin attached<=1;busy<=0;state<=IDLE;end
      end
      else fail(7);
     end else if(byte_valid && byte_ready)begin
      chip[index]<=byte_data;
      if(index==15)begin state<=CHECK_CHIP;index<=0;end else index<=index+1'b1;
     end
    end
    CHECK_CHIP:begin
     if({chip[0],chip[1],chip[2],chip[3]}!=32'h43484950)fail(5);
     else if(packet_length!={16'b0,image_length}+32'd16 || image_length>expected-received)fail(6);
     else if(chip_type!=0 && chip_type!=2)fail(6);
     else if(chip_type==2 && cart_id!=32 && cart_id!=33)fail(6);
     else if((cart_id==0 && chip_bank!=0) || chip_bank>63 || (load_address!=16'h8000 && load_address!=16'ha000 && load_address!=16'he000))fail(6);
     else if(image_length!=8192 && image_length!=16384 && !(cart_id==18 && image_length==4096 && load_address==16'h8000 && pages==0 && chip_bank==0))fail(6);
     else if(image_length==16384 && load_address!=16'h8000)fail(6);
     else if((pages+(image_length==16384 ? 2:1)>((EASYFLASH && cart_id==32) ? 128:(MAX_PAYLOAD_BYTES/8192)) && !erased_ocean_tail) || chip_count==255)fail(8);
     else if((cart_id==32 || cart_id==33) && (chip_bank>=64 || pages+(image_length==16384 ? 2:1)>128))fail(8);
     else if(seen[map_index] || (image_length==16384 && seen[map_index+1'b1]))fail(9);
     else begin
      payload_length<=image_length;payload_pos<=0;mirror<=image_length==4096;chip_pages<=image_length==16384 ? 2:1;
      bank_hi<=high_chip;bank_16k<=image_length==16384;bank_num<=chip_bank[7:0];bank_page<=pages[7:0];
      seen[map_index]<=1;if(image_length==16384)seen[map_index+1'b1]<=1;
      state<=PAYLOAD;
     end
    end
    PAYLOAD:begin
     if(eof_seen)fail(7);
     else if(byte_valid && byte_ready)begin
      if(erased_ocean_tail)begin
       if(byte_data!=8'hff)fail(8);
       else state<=COMPLETE_CHIP;
      end else begin
       if(EASYFLASH && cart_id==32)
        ram_addr<=24'h200000+{4'b0,(high_chip || (image_length==16384 && payload_pos[13])),chip_bank[5:0],payload_pos[12:0]};
       else ram_addr<=24'h200000+{pages,13'b0}+payload_pos;
       ram_wdata<=byte_data;ram_start<=1;state<=WAIT_WRITE;
      end
     end
    end
    WAIT_WRITE:if(ram_ack)state<=mirror ? MIRROR:COMPLETE_CHIP;
    MIRROR:if(ram_ready)begin ram_addr<=ram_addr+24'd4096;ram_start<=1;state<=WAIT_MIRROR;end
    WAIT_MIRROR:if(ram_ack)state<=COMPLETE_CHIP;
    COMPLETE_CHIP:if(payload_pos+1'b1==payload_length)begin
     bank_wr<=1;pages<=pages+chip_pages;chip_count<=chip_count+1'b1;index<=0;state<=CHIP;
    end else begin payload_pos<=payload_pos+1'b1;state<=PAYLOAD;end
    default:fail(10);
   endcase
  end
 end
endmodule
