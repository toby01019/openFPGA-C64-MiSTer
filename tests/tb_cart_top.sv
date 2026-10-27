`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #6.734 a=~a;always #15.873 b=~b;
reg valid=0;reg[25:0] cmd=0;reg[7:0]crt[0:8271];integer i;
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),.bridge_addr(32'b0),.bridge_wr(1'b0),.bridge_wr_data(32'b0),.bridge_rd(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0));
task send(input[25:0]v);begin
 @(negedge a);cmd=v;valid=1;wait(dut.host_done);@(negedge a);valid=0;
 wait(!dut.host_done);repeat(3)@(negedge a);
end endtask
task rom(input[13:0]addr,input[7:0]v);begin send({2'd1,2'b0,addr,v});end endtask
initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.pause_request=0;
 force dut.host_write=valid;force dut.host_data=cmd;
 // This diagnostic writes every RAM location it subsequently checks.
 // Leave other RAM unknown, as it would be before firmware initialization.
 $readmemh("cart_top.hex",crt);repeat(100)@(negedge b);$display("PROGRESS initial clocks %t",$time);
 // Own KERNAL substitute sets CPU port and jumps into cartridge $8000.
 rom('h2000,'h78);rom('h2001,'ha9);rom('h2002,'h2f);rom('h2003,'h85);rom('h2004,0);
 rom('h2005,'ha9);rom('h2006,'h37);rom('h2007,'h85);rom('h2008,1);
 rom('h2009,'h4c);rom('h200a,0);rom('h200b,'h80);
 rom('h3ffc,0);rom('h3ffd,'he0);rom('h3ffa,0);rom('h3ffb,'he0);rom('h3ffe,0);rom('h3fff,'he0);
 $display("PROGRESS KERNAL uploaded %t",$time);
 send({4'b1101,22'd8272});for(i=0;i<8272;i=i+1)begin send({4'b1100,14'b0,crt[i]});if(i%1024==0)$display("PROGRESS CRT byte %d time %t",i,$time);end send({4'b1110,22'b0});
 repeat(40)@(negedge b);if(!dut.cart_attached || dut.cart_error)$fatal(1,"CRT upload failed");
 force dut.core_run=1;wait(dut.main_ram['hc121]==8'h5a);
 if(dut.main_ram['hc120]!==8'h3c || dut.main_ram['h8000]!==8'h77)$fatal(1,"RAM mapping failed");
 $display("PASS actual C64 CPU executes CRT ROM, ordinary RAM read/write and RAM beneath ROM via APF byte mailbox");
 force dut.core_run=0;repeat(100)@(negedge b);dut.main_ram['hc121]=0;
 force dut.core_run=1;wait(dut.main_ram['hc121]==8'h5a);
 $display("PASS C64 reset preserves attached cartridge and executes it again");
 force dut.core_run=0;repeat(100)@(negedge b);send({4'b1111,22'b0});repeat(20)@(negedge b);
 if(dut.cart_attached || !dut.cart_exrom || !dut.cart_game)$fatal(1,"EJECT failed");
 $display("PASS CRT eject releases GAME/EXROM");$finish;
end
initial begin #100000000;$fatal(1,"CRT top timeout addr=%h RAM=%h",dut.c64_addr,dut.main_ram['hc121]);end
endmodule
