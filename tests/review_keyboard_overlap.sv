`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg reset=1;
reg [15:0] buttons=0;
wire visible;
wire [63:0] sticky,matrix;
pocket_keyboard dut(.clk(clk),.reset(reset),.blocked(1'b0),.buttons(buttons),
 .visible(visible),.sticky(sticky),.matrix(matrix));
task tap(input integer button);
begin @(negedge clk);buttons=16'b1<<button;@(negedge clk);buttons=0;@(negedge clk);end
endtask
initial begin
 repeat(3) @(negedge clk);reset=0;
 tap(7);
 dut.selected_row=3;dut.selected_col=1;
 tap(4);
 if(sticky!==(64'h1<<15)) $fatal(1,"Shift setup failed");
 dut.selected_row=6;dut.selected_col=0;
 tap(6);
 if(matrix!==((64'h1<<15)|(64'h1<<4)))
   $fatal(1,"locking F2 while Shift already locked must keep Shift: %h",matrix);
 tap(6);
 if(matrix!==(64'h1<<15)) $fatal(1,"unlocking F2 must retain independent Shift");
 tap(6);
 dut.selected_row=3;dut.selected_col=1;tap(4);
 if(matrix!==((64'h1<<15)|(64'h1<<4))) $fatal(1,"unlocking Shift must retain independent F2 chord");
 dut.selected_row=6;dut.selected_col=0;tap(6);
 if(matrix!==0) $fatal(1,"all unlocked keys must release");
 // Repeat in opposite locking order: F2 first, then separate Shift.
 tap(6);
 dut.selected_row=3;dut.selected_col=1;tap(4);
 if(matrix!==((64'h1<<15)|(64'h1<<4))) $fatal(1,"locking Shift after F2 must keep F2");
 dut.selected_row=6;dut.selected_col=0;tap(6);
 if(matrix!==(64'h1<<15)) $fatal(1,"F2 unlock lost Shift in reversed order");
 dut.selected_row=3;dut.selected_col=1;tap(4);
 if(matrix!==0) $fatal(1,"reversed order left a stuck key");
 $display("PASS overlapping virtual chords: independent Shift/F2 locks in both orders and independent release");
 $finish;
end
endmodule
