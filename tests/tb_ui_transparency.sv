`timescale 1ns/1ps
module tb;
reg host=0,core=0;always #6.734 host=~host;always #15.873 core=~core;
reg [15:0] buttons=0;reg [31:0] addr=0,data=0;reg wr=0,core_reset=0;
wire [31:0] result;
core_top dut(.clk_74a(host),.clk_74b(host),.clk_32mhz(core),
 .bridge_addr(addr),.bridge_wr(wr),.bridge_wr_data(data),.bridge_rd(1'b1),.bridge_rd_data(result),
 .cont1_key(buttons),.cont2_key(16'b0),.cont3_key(16'b0),.cont4_key(16'b0));
task press(input [15:0] value);begin buttons=value;repeat(16)@(negedge core);end endtask
task check(input [1:0] value);
begin
 repeat(16)@(negedge core);
 if(dut.keyboard_transparency!==value || dut.transparency_sync!==value)$fatal(1,"mode CDC %0d host%0d core%0d",value,dut.keyboard_transparency,dut.transparency_sync);
 addr=32'ha0000004;#1;if(result!=={30'b0,value})$fatal(1,"readback");
 if(dut.virtual_keys!==0 || dut.joy!==0)$fatal(1,"UI action leaked to C64");
end endtask
task menu(input [1:0] value);
begin @(negedge host);addr=32'ha0000004;data=value;wr=1;@(negedge host);wr=0;end endtask
initial begin
 force dut.reset_n=1;force dut.core_run=1;force dut.core_reset=core_reset;
 force dut.c64_paused=0;force dut.keyboard_ready_sync=1;force dut.menu_sync=0;
 repeat(20)@(negedge core);
 press(16'h80);press(0);
 if(!dut.keyboard_visible)$fatal(1,"open");
 // Functional navigation to this cell is independently checked by keyboard tests.
 dut.virtual_keyboard.selected_row=5;dut.virtual_keyboard.selected_col=1;
 press(16'h10);check(1);
 repeat(100)@(negedge core);check(1); // Held A advances only once.
 press(0);press(16'h10);check(2);
 press(0);press(16'h10);check(0);
 press(0);menu(1);check(1); // Menu and on-keyboard control share one value.
 press(16'h10);check(2);press(0);
 press(16'h20);press(0);
 if(dut.keyboard_visible)$fatal(1,"close");
 // Hidden A is fire, not a transparency shortcut.
 press(16'h10);press(0);
 if(dut.keyboard_transparency!==2)$fatal(1,"hidden shortcut");
 press(16'h80);press(0);check(2);
 core_reset=1;repeat(8)@(negedge core);core_reset=0;repeat(16)@(negedge core);
 if(dut.keyboard_transparency!==2)$fatal(1,"reset generated phantom toggle");
 press(16'h80);press(0);check(2);
 menu(3);check(0);
 $display("PASS direct keyboard transparency: A cycles 0/25/50 once per press, host/core CDC and readback, shared menu state, close/reopen/reset, no C64/joystick contacts");$finish;
end
initial begin #200000;$fatal(1,"timeout");end
endmodule
