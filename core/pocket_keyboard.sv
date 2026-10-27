// SPDX-License-Identifier: MIT
// Full C64 contacts; UI input never leaks to the game while the panel is open.
module pocket_keyboard #(
 parameter REPEAT_DELAY=10509318,REPEAT_RATE=2627330,MACRO_CYCLES=1576398
)(input wire clk,reset,blocked,input wire [15:0] buttons,
 output reg visible=0,output reg [3:0] selected_row=1,output reg [3:0] selected_col=1,
 output reg [63:0] sticky=0,output reg [63:0] matrix,
 output wire restore,output wire macro_busy,output wire capture,
 // Toggle encoding preserves a UI event across the host clock boundary.
 // Keep its phase across C64 resets; only real button presses change it.
 output reg transparency_toggle=0);
 `include "keyboard_layout.vh"
 reg [15:0] previous=0;
 wire [15:0] pressed=buttons & ~previous;
 wire [6:0] selection=layout_key(selected_row,selected_col);
 reg [31:0] repeat_count=0,macro_count=0;
 reg [1:0] macro_kind=0;
 reg [4:0] macro_phase=0;
 reg release_guard=0;
 reg [75:0] sticky_latches=0;
 integer latch_index;
 reg navigate;
 reg [63:0] macro_mask;
 wire modifier=selection==60 || selection==61 || selection==62 || selection==70 || selection==71;
 assign macro_busy=macro_kind!=0;
 assign capture=visible || release_guard;
 assign restore=visible && !blocked && !reset && selection==65 && buttons[4];
 always @* begin
  sticky=0;
  for(latch_index=0;latch_index<76;latch_index=latch_index+1)
   if(sticky_latches[latch_index]) sticky=sticky|key_mask(latch_index);
 end
 always @* begin
  macro_mask=0;
  if(!macro_phase[0]) begin
   if(macro_kind==1) case(macro_phase[4:1])
    0:macro_mask=64'h1<<17;1:macro_mask=64'h1<<30;
    2:macro_mask=64'h1<<39;3:macro_mask=64'h1<<1;
    default:macro_mask=0;
   endcase
   else if(macro_kind==2) case(macro_phase[4:1])
    0:macro_mask=64'h1<<42;1:macro_mask=64'h1<<33;
    2:macro_mask=64'h1<<13;3:macro_mask=64'h1<<22;4:macro_mask=64'h1<<1;
    default:macro_mask=0;
   endcase
   else if(macro_kind==3) case(macro_phase[4:1])
    // LOAD"*",8,1 + Return. Quotes use the real C64 Shift+2 chord.
    0:macro_mask=64'h1<<42; // L
    1:macro_mask=64'h1<<38; // O
    2:macro_mask=64'h1<<10; // A
    3:macro_mask=64'h1<<18; // D
    4,6:macro_mask=(64'h1<<59)|(64'h1<<15); // "
    5:macro_mask=64'h1<<49; // *
    7,9:macro_mask=64'h1<<47; // ,
    8:macro_mask=64'h1<<27; // 8
    10:macro_mask=64'h1<<56; // 1
    11:macro_mask=64'h1<<1; // Return; RUN remains a separate action.
    default:macro_mask=0;
   endcase
  end
  matrix=0;
  if(visible && !blocked && !reset) begin
   matrix=sticky|macro_mask;
   if(!macro_busy) begin
    if(buttons[4] && !modifier) matrix=matrix|key_mask(selection);
    if(buttons[8]) matrix[15]=1; // L: temporary Shift.
    if(buttons[9]) matrix[61]=1; // R: temporary Commodore.
    if(buttons[15]) matrix[1]=1;
    if(buttons[14]) matrix[60]=1;
   end
  end
 end
 always @(posedge clk) begin
  previous<=buttons;
  navigate=0;
  if(reset || blocked) begin
   visible<=0;sticky_latches<=0;repeat_count<=0;macro_kind<=0;macro_count<=0;macro_phase<=0;
   release_guard<=1;
  end else if(!visible) begin
   sticky_latches<=0;macro_kind<=0;repeat_count<=0;
   if(buttons==0) release_guard<=0;
   if(pressed[7] && !release_guard) visible<=1;
  end else if(pressed[5]) begin
   visible<=0;sticky_latches<=0;macro_kind<=0;release_guard<=1;
  end else begin
   if(!macro_busy && pressed[4] && selection==76)
    transparency_toggle<=~transparency_toggle;
   if(macro_busy) begin
    if(macro_count==MACRO_CYCLES-1) begin
     macro_count<=0;
     if((macro_kind==1 && macro_phase==7)||(macro_kind==2 && macro_phase==9)||
        (macro_kind==3 && macro_phase==23)) begin
      macro_kind<=0;macro_phase<=0;
     end else macro_phase<=macro_phase+1'b1;
    end else macro_count<=macro_count+1'b1;
   end
   if(pressed[7]) sticky_latches<=0;
   else if(!macro_busy && key_mask(selection)!=0 && (pressed[6] || (pressed[4] && modifier)))
    sticky_latches[selection]<=~sticky_latches[selection];
   if(!macro_busy && pressed[4] && (selection==74 || selection==75 || selection==77)) begin
    macro_kind<=selection==74 ? 1:selection==75 ? 2:3;
    macro_count<=0;macro_phase<=0;sticky_latches<=0;
   end
   if(buttons[3:0]==0 || buttons[4] || macro_busy) repeat_count<=0;
   else if(buttons[3:0]!=previous[3:0]) begin navigate=1;repeat_count<=REPEAT_DELAY;end
   else if(repeat_count==0) begin navigate=1;repeat_count<=REPEAT_RATE;end
   else repeat_count<=repeat_count-1'b1;
   if(navigate) begin
    if(buttons[0]) {selected_row,selected_col}<=layout_neighbor(selection,0);
    else if(buttons[1]) {selected_row,selected_col}<=layout_neighbor(selection,1);
    else if(buttons[2]) {selected_row,selected_col}<=layout_neighbor(selection,2);
    else if(buttons[3]) {selected_row,selected_col}<=layout_neighbor(selection,3);
   end
  end
 end
endmodule
