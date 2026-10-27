`timescale 1ns/1ps
module tb;
`include "keyboard_layout.vh"
reg clk=0;always #5 clk=~clk;
reg reset=1,blocked=0;reg [15:0] buttons=0;
wire visible,busy;wire [3:0] row,col;wire [63:0] sticky,matrix;
pocket_keyboard #(.MACRO_CYCLES(4)) keyboard(.clk(clk),.reset(reset),.blocked(blocked),.buttons(buttons),
 .visible(visible),.selected_row(row),.selected_col(col),.sticky(sticky),.matrix(matrix),.macro_busy(busy));
wire [23:0] pixel;
pocket_keyboard_video #(.PIPELINED(1)) ui(.clk(clk),.pause(1'b0),.vsync(1'b0),.active(1'b0),.visible(visible),
 .rgb(24'h3636a8),.selected_row(row),.selected_col(col),.sticky(sticky),.held(matrix),.macro_busy(busy),.transparency(2'b0),.mixed_rgb(pixel));
task tick;begin @(negedge clk);end endtask
task tap(input integer b);begin buttons=16'b1<<b;tick;buttons=0;tick;end endtask
task select_key(input integer id);
reg [7:0] target;integer guard;
begin
 target=layout_cell(id);guard=0;
 while((row<4 ? row:row==4 ? col:row-1)!=(target[7:4]<4 ? target[7:4]:target[7:4]==4 ? target[3:0]:target[7:4]-1))begin
  tap(1);guard=guard+1;if(guard>6)$fatal(1,"vertical navigation");end
 guard=0;
 while({row,col}!=target)begin tap(3);guard=guard+1;if(guard>17)$fatal(1,"horizontal navigation");end
end endtask
task labels(input reg shifted);
begin
 if(ui.shift_labels!==shifted)$fatal(1,"Shift state mismatch");
 if(ui.key_display_label(13,ui.shift_labels)!==(shifted ? "$     ":"4     "))$fatal(1,"dollar label");
 if(ui.key_display_label(11,ui.shift_labels)!==(shifted ? "\"     ":"2     "))$fatal(1,"quote label");
 if(ui.key_display_label(15,ui.shift_labels)!==(shifted ? "&     ":"6     "))$fatal(1,"C64 six is ampersand");
 if(ui.key_display_label(18,ui.shift_labels)!==(shifted ? ")     ":"9     "))$fatal(1,"C64 nine is close paren");
 if(ui.key_display_label(19,ui.shift_labels)!=="0     ")$fatal(1,"zero must stay zero");
 if(ui.key_display_label(56,ui.shift_labels)!==(shifted ? "[     ":":     "))$fatal(1,"bracket label");
 if(ui.key_display_label(0,ui.shift_labels)!==(shifted ? "F2    ":"F1    "))$fatal(1,"function label");
 if(ui.key_display_label(8,ui.shift_labels)!==(shifted ? "CLR   ":"HOME  "))$fatal(1,"HOME/CLR label");
 if(ui.key_display_length(8,ui.shift_labels)!==(shifted ? 3'd3:3'd4))$fatal(1,"HOME/CLR centering");
 if(ui.key_display_label(77,ui.shift_labels)!=="LOAD* ")$fatal(1,"shortcut renamed");
end endtask
integer i;
initial begin
 repeat(3)tick;reset=0;tick;tap(7);labels(0);
 select_key(60);tap(4);labels(1); // Latched left Shift.
 select_key(13);buttons=16'h10;tick;
 if(matrix!==((64'h1<<15)|(64'h1<<11)))$fatal(1,"dollar key contacts changed");
 buttons=0;tick;tap(7);labels(0);
 select_key(70);tap(4);labels(1);tap(4);labels(0); // Right Shift.
 select_key(71);tap(4);labels(1);tap(7);labels(0); // Shift Lock.
 buttons=16'h100;tick;labels(1);buttons=0;tick;labels(0); // Temporary L.
 buttons=16'h200;tick;labels(0);buttons=0;tick; // Commodore is not Shift.
 select_key(77);tap(4);i=0;
 while(busy)begin labels(0);tick;i=i+1;if(i>110)$fatal(1,"LOAD timeout");end
 labels(0); // LOAD quote chords must not flicker labels or leave Shift on.
 select_key(60);tap(4);labels(1);blocked=1;tick;labels(0);
 blocked=0;tick;tap(7);select_key(70);tap(4);labels(1);reset=1;tick;labels(0);
 $display("PASS Shift labels: actual left/right/Lock/temporary L, release/menu/reset, unchanged dollar contacts, C64 punctuation/F/CLR, macro quote suppression, LOAD* retained");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
