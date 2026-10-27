// SPDX-License-Identifier: MIT
// Conservative BASIC V2 disk autostart. Read-only opcode observation; no RAM
// injection, drive resets, altered IEC timing, or writes to the selected disk.
module pocket_autostart #(
 parameter CLK_HZ=31527954, SETTLE_MS=250, KEY_MS=60,
 parameter ARM_MS=8000, LOAD_MS=120000
)(
 input wire clk,reset,enabled,paused,menu,available,mounted,cancel,
 input wire cpu_valid,input wire [15:0] cpu_addr,input wire [7:0] cpu_data,
 output wire [63:0] matrix,output wire typing,output wire waiting,
 output wire prompt_ready
);
 localparam DIV=CLK_HZ/1000, DIV_BITS=$clog2(DIV+1);
 reg [DIV_BITS-1:0] divider=0;
 wire tick=divider==DIV-1;
 localparam IDLE=0,ARM=1,PRESS=2,GAP=3,LOAD=4;
 reg [2:0] state=IDLE;
 reg [16:0] elapsed=0;
 reg [7:0] stable=0;
 reg wait_seen=0,basic_line=0,line_dirty=0,ever_prompt=0;
 reg mounted_d=0,load_called=0,load_ok=0,returned=0;
 reg [4:0] position=0;
 wire basic_entry=cpu_valid && cpu_addr==16'ha483 && cpu_data==8'h20;
 wire line_done=cpu_valid && cpu_addr==16'ha486 && cpu_data==8'h86;
 wire key_wait=cpu_valid && cpu_addr==16'he5cd && cpu_data==8'ha5;
 wire error_exit=cpu_valid && (cpu_addr==16'ha437 || cpu_addr==16'he1d1);
 assign prompt_ready=basic_line && !line_dirty && stable>=SETTLE_MS;
 assign typing=state==PRESS || state==GAP;
 assign waiting=state==LOAD;
 // LOAD"*",8,1<RETURN>, then RUN<RETURN>. Contacts match pocket_keyboard.
 function automatic [63:0] contact(input [4:0] n);
  case(n)
   0:contact=64'b1<<42;1:contact=64'b1<<38;2:contact=64'b1<<10;3:contact=64'b1<<18;
   4,6:contact=(64'b1<<59)|(64'b1<<15);5:contact=64'b1<<49;
   7,9:contact=64'b1<<47;8:contact=64'b1<<27;10:contact=64'b1<<56;
   11,15:contact=64'b1<<1;
   12:contact=64'b1<<17;13:contact=64'b1<<30;14:contact=64'b1<<39;
   default:contact=0;
  endcase
 endfunction
 // Lead with Shift for a full scan before introducing a quote key.
 assign matrix=state==PRESS && !menu && !cancel && enabled && !reset ?
  (((position==4 || position==6) && elapsed<20) ? (64'b1<<15):contact(position)):64'b0;
 always @(posedge clk) begin
  mounted_d<=mounted;
  if(reset)begin
   divider<=0;stable<=0;wait_seen<=0;basic_line<=0;line_dirty<=0;ever_prompt<=0;
   state<=IDLE;elapsed<=0;position<=0;load_called<=0;load_ok<=0;returned<=0;
  end else begin
   // Timers freeze with the emulated CPU. Pocket menu never advances a key.
   if(!paused && !menu)begin
    divider<=tick ? 0:divider+1'b1;
    if(key_wait)wait_seen<=1;
    if(tick)begin
     wait_seen<=key_wait;
     if(!wait_seen || !basic_line)stable<=0;
     else if(stable<SETTLE_MS)stable<=stable+1'b1;
    end
   end
   if(basic_entry)begin basic_line<=1;line_dirty<=0;stable<=0;ever_prompt<=1;end
   if(line_done)begin basic_line<=0;stable<=0;end
   if(cancel)line_dirty<=1;
   // Disabling or touching a keyboard cancels, never queues a surprise RUN.
   if(!enabled || cancel || !available || error_exit)begin
    state<=IDLE;elapsed<=0;load_called<=0;load_ok<=0;returned<=0;
   end else if(mounted && !mounted_d)begin
    // Mid-game swaps are insert-only. A disk selected during boot may wait
    // for the first READY prompt; later selections require an idle prompt.
    state<=(!ever_prompt || prompt_ready) ? ARM:IDLE;
    elapsed<=0;load_called<=0;load_ok<=0;returned<=0;
   end else if(!mounted)begin state<=IDLE;elapsed<=0;end
   else begin
    if(typing || waiting)begin
     if(cpu_valid && cpu_addr==16'he175 && cpu_data==8'h20)load_called<=1;
     if(load_called && cpu_valid && cpu_addr==16'he1a7 && cpu_data==8'h86)load_ok<=1;
     if(load_ok && basic_entry)returned<=1;
    end
    // Opening the Pocket menu during typing safely aborts the incomplete
    // command; do not release/re-press a character and accidentally double it.
    if(menu && typing)begin state<=IDLE;line_dirty<=1;end
    else if(!paused && !menu && tick)begin
     if(state!=IDLE && elapsed<LOAD_MS)elapsed<=elapsed+1'b1;
     case(state)
      ARM:if(elapsed>=ARM_MS)state<=IDLE;
       else if(prompt_ready)begin state<=PRESS;position<=0;elapsed<=0;end
      PRESS:if(elapsed>=KEY_MS+20)begin state<=GAP;elapsed<=0;end
      GAP:if(elapsed>=KEY_MS)begin
       elapsed<=0;
       if(position==11)state<=LOAD;
       else if(position==15)state<=IDLE;
       else begin position<=position+1'b1;state<=PRESS;end
      end
      LOAD:if(elapsed>=LOAD_MS)state<=IDLE;
       else if(returned && prompt_ready)begin state<=PRESS;position<=12;elapsed<=0;end
      default:elapsed<=0;
     endcase
    end
   end
  end
 end
endmodule
