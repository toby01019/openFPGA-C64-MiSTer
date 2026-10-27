// SPDX-License-Identifier: MIT
// Host-clock 1581 frontend. Own reader AND file-buffer from busy/grant until
// busy falls. Buffer and sd_buff_din are synchronous, one-cycle read ports.
// Failed write/flush retains dirty and ack: never report false disk success.
// Metadata inputs must be stable before enable/mount_event (slots 204 and 4).
module pocket_d81(
 input wire clk,reset,enable,grant,mount_event,
 input wire [31:0] rom_size,image_size,input wire write_protect,
 input wire [31:0] sd_lba,input wire sd_rd,sd_wr,output reg sd_ack=0,
 output wire [8:0] sd_buff_addr,output reg [7:0] sd_buff_dout=0,
 input wire [7:0] sd_buff_din,output reg sd_buff_wr=0,
 output reg rom_we=0,output reg [14:0] rom_addr=0,output reg [7:0] rom_data=0,
 output reg busy=0,output reg mounted=0,output reg rom_loaded=0,output reg dirty=0,
 output reg [7:0] error_code=0,output wire [7:0] debug_state,
 output wire io_start,input wire io_ready,io_done,io_error,
 output reg [2:0] io_operation=0,output reg [15:0] io_slot=0,
 output reg [31:0] io_offset=0,output reg [10:0] io_length=0,
 output wire [7:0] buffer_addr,input wire [31:0] buffer_q,
 output wire buffer_we,output wire [31:0] buffer_data
);
 localparam IDLE=0,WAIT_GRANT=1,BEGIN_OP=2,REQUEST=3,IO_WAIT=4,
  COPY_ADDR=5,COPY_WAIT=6,COPY_BYTE=7,COPY_NEXT=8,
  WRITE_ADDR=9,WRITE_WAIT=10,WRITE_BYTE=11,WRITE_WORD=12,WRITE_NEXT=13,
  ZERO_FLAGS=14,ZERO_SIZE=15,OPEN_GAP=16,ACK_END=17,ACK_WAIT=18,RELEASE=19,FAIL=20;
 localparam ROM=0,MOUNT=1,READ=2,WRITE=3,OPEN=4,FLUSH=5;
 reg [7:0] state=IDLE;
 reg [2:0] kind=ROM;
 reg boot_checked=0,pending=0,alias_valid=0;
 reg [31:0] size_hold=0,lba_hold=0;
 reg protect_hold=1;
 reg [15:0] rom_position=0;
 reg [10:0] index=0;
 reg [31:0] pack=0;
 assign sd_buff_addr=index[8:0];
 assign buffer_addr=state==ZERO_FLAGS ? 8'd64:state==ZERO_SIZE ? 8'd65:index[9:2];
 assign buffer_we=grant && (state==ZERO_FLAGS || state==ZERO_SIZE || state==WRITE_WORD);
 assign buffer_data=state==WRITE_WORD ? pack:32'b0;
 assign io_start=state==REQUEST && grant && io_ready;
 assign debug_state=state;
 always @(posedge clk)begin
  sd_buff_wr<=0;rom_we<=0;
  if(reset)begin
   state<=IDLE;busy<=0;mounted<=0;rom_loaded<=0;dirty<=0;sd_ack<=0;
   boot_checked<=0;pending<=0;alias_valid<=0;error_code<=0;rom_position<=0;
  end else begin
   if(mount_event)pending<=1;
   case(state)
    IDLE:if(enable)begin
     if(!boot_checked)begin
      boot_checked<=1;
      if(rom_size==32768)begin kind<=ROM;rom_position<=0;busy<=1;state<=WAIT_GRANT;end
      else begin error_code<=rom_size==0 ? 0:8'h01;end
     end else if(rom_loaded && mounted && (sd_rd || sd_wr))begin
      // An already staged write belongs to the OLD alias even if slot4 changed.
      kind<=sd_wr ? WRITE:READ;lba_hold<=sd_lba;protect_hold<=write_protect;
      busy<=1;state<=WAIT_GRANT;
     end else if(rom_loaded && pending)begin
      pending<=mount_event;size_hold<=image_size;kind<=MOUNT;busy<=1;state<=WAIT_GRANT;
     end
    end
    WAIT_GRANT:if(grant)state<=BEGIN_OP;
    BEGIN_OP:begin
     error_code<=0;index<=0;
     case(kind)
      ROM:begin io_operation<=0;io_slot<=204;io_offset<=0;io_length<=1024;state<=REQUEST;end
      MOUNT:begin
       mounted<=0;alias_valid<=0;
       if(size_hold==0)state<=RELEASE;
       else if(size_hold!=819200)begin error_code<=2;state<=RELEASE;end
       else begin io_operation<=3;io_slot<=4;io_offset<=0;io_length<=0;state<=REQUEST;end
      end
      READ,WRITE:begin
       sd_ack<=1;
       if(!alias_valid || lba_hold>=1600)begin error_code<=3;state<=FAIL;end
       else if(kind==WRITE && protect_hold)begin error_code<=4;state<=FAIL;end
       else begin
        io_slot<=7;io_offset<={lba_hold[22:0],9'b0};io_length<=512;
        if(kind==WRITE)begin dirty<=1;pack<=0;state<=WRITE_ADDR;end
        else begin io_operation<=0;state<=REQUEST;end
       end
      end
      default:begin error_code<=9;state<=FAIL;end
     endcase
    end
    REQUEST:if(grant && io_ready)state<=IO_WAIT;
    IO_WAIT:if(io_done)begin
     if(io_error)begin
      error_code<=8'h10+{5'b0,kind};
      if(kind==ROM || kind==MOUNT || kind==OPEN)begin mounted<=0;state<=RELEASE;end
      else state<=FAIL;
     end else case(kind)
      ROM,READ:begin index<=0;state<=COPY_ADDR;end
      MOUNT:state<=ZERO_FLAGS;
      OPEN:begin alias_valid<=1;mounted<=!pending && !mount_event;state<=RELEASE;end
      WRITE:begin kind<=FLUSH;io_operation<=2;io_offset<=0;io_length<=0;state<=REQUEST;end
      FLUSH:begin dirty<=0;state<=ACK_END;end
      default:begin error_code<=9;state<=FAIL;end
     endcase
    end
    COPY_ADDR:state<=COPY_WAIT;
    COPY_WAIT:state<=COPY_BYTE;
    COPY_BYTE:begin
     if(kind==ROM)begin rom_we<=1;rom_addr<=rom_position[14:0]+index[9:0];rom_data<=buffer_q >> {index[1:0],3'b0};end
     else begin sd_buff_wr<=1;sd_buff_dout<=buffer_q >> {index[1:0],3'b0};end
     state<=COPY_NEXT;
    end
    COPY_NEXT:if(index==io_length-1'b1)begin
     if(kind==READ)state<=ACK_END;
     else if(rom_position==31744)begin rom_loaded<=1;pending<=1;state<=RELEASE;end
     else begin rom_position<=rom_position+1024;io_offset<=io_offset+1024;state<=REQUEST;end
    end else begin index<=index+1'b1;state<=COPY_ADDR;end
    WRITE_ADDR:state<=WRITE_WAIT;
    WRITE_WAIT:state<=WRITE_BYTE;
    WRITE_BYTE:begin
     pack[{index[1:0],3'b0} +:8]<=sd_buff_din;
     state<=index[1:0]==3 ? WRITE_WORD:WRITE_NEXT;
    end
    WRITE_WORD:state<=WRITE_NEXT;
    WRITE_NEXT:if(index==511)begin io_operation<=1;state<=REQUEST;end
     else begin index<=index+1'b1;state<=WRITE_ADDR;end
    ZERO_FLAGS:state<=ZERO_SIZE;
    ZERO_SIZE:state<=OPEN_GAP;
    OPEN_GAP:begin kind<=OPEN;io_operation<=4;io_slot<=7;io_length<=0;state<=REQUEST;end
    ACK_END:begin sd_ack<=0;state<=ACK_WAIT;end
    ACK_WAIT:if(!sd_rd && !sd_wr)state<=RELEASE;
    RELEASE:begin busy<=0;state<=IDLE;end
    // Retain buffer ownership, old alias, staging and dirty on failure.
    FAIL:begin end
    default:begin error_code<=9;state<=FAIL;end
   endcase
  end
 end
endmodule

