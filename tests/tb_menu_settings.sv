`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #6.734 a=~a;always #15.859 b=~b;
reg [31:0] ba=0,bd=0;reg bw=0;wire [31:0] br;
reg [3:0] color=0;reg [23:0] expected[0:127];integer pal,idx,m;
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),
 .bridge_addr(ba),.bridge_wr(bw),.bridge_wr_data(bd),.bridge_rd(1'b1),.bridge_rd_data(br),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0));
task wr(input [31:0] addr,input [31:0] data);begin
 @(negedge a);ba=addr;bd=data;bw=1;
 @(negedge a);bw=0;repeat(8)@(negedge b);
end endtask
initial begin
 force dut.reset_n=1;force dut.core_run=0;
 force dut.c64.viccolorindex=color;
 $readmemh("menu_palette_expected.hex",expected);
 repeat(20)@(negedge b);
 if(dut.palette_sync!=0 || dut.sid_model_sync!=1)$fatal(1,"default palette/SID changed");
 for(pal=0;pal<8;pal=pal+1)begin
  wr(32'ha0000018,pal);
  if(br!==pal || dut.c64.palette!==pal[2:0])$fatal(1,"palette register/CDC %0d",pal);
  for(idx=0;idx<16;idx=idx+1)begin
   color=idx;repeat(2)@(negedge b);
   if({dut.red,dut.green,dut.blue}!==expected[pal*16+idx])$fatal(1,"palette %0d color %0d",pal,idx);
  end
 end
 for(m=0;m<2;m=m+1)begin
  wr(32'ha000001c,m);
  if(br!==m || dut.c64.sid.mode!=={2{m[0]}})$fatal(1,"SID register/CDC/model port %0d",m);
 end
 for(m=0;m<2;m=m+1)begin
  wr(32'ha0000020,m);
  if(br!==m || dut.pcm_sync!==m[0])$fatal(1,"PCM menu register/CDC");
 end
 wr(32'ha0000010,2);
 if(br!==0 || dut.drive9_mode!==0)$fatal(1,"old persisted D81 mode not rejected");
 wr(32'ha0000010,1);
 if(br!==1)$fatal(1,"1541 drive9 mode lost");
 wr(32'ha0000010,0);
 wr(32'ha0000014,0);
 if(br!==0 || dut.loader.restart_pending)$fatal(1,"zero action triggered reset");
 wr(32'ha0000014,1);
 if(br!==0 || !dut.loader.restart_pending)$fatal(1,"menu Reset Core did not queue");
 $display("PASS menu bridge: all 128 MiSTer palette colors exact, defaults Colodore/8580, both SID models through CDC, Reset Core action, PCM enable/disable CDC, D81 rejection/1541 retention, readback");$finish;
end
initial begin #1000000;$fatal(1,"menu settings timeout");end
endmodule
