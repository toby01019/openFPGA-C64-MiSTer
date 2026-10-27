`timescale 1ns/1ps
module tb;
reg a=0,b=0;always #6.734 a=~a;always #15.859 b=~b;
core_top dut(.clk_74a(a),.clk_74b(a),.clk_32mhz(b),.bridge_addr(32'b0),.bridge_wr(1'b0),
 .bridge_wr_data(32'b0),.bridge_rd(1'b0),.cont_update(1'b0),
 .cont1_key(32'b0),.cont2_key(32'b0),.cont3_key(32'b0),.cont4_key(32'b0));
defparam dut.disk_autostart.SETTLE_MS=2;
integer i,entries=0,waits=0;
always @(posedge b)if(dut.monitor_valid)begin
 if(dut.monitor_addr==16'ha483)begin
  if(dut.monitor_data!==8'h20)$fatal(1,"opcode data misaligned");entries=entries+1;
 end
 if(dut.monitor_addr==16'he5cd)begin
  if(dut.monitor_data!==8'ha5)$fatal(1,"wait opcode data misaligned");waits=waits+1;
 end
end
initial begin
 force dut.reset_n=1;force dut.core_run=0;force dut.host_write=0;
 force dut.pause_request=0;force dut.disk_pause=0;force dut.disk9_pause=0;
 force dut.load_state=11;force dut.disk_mounted=0;
 for(i=0;i<65536;i=i+1)dut.main_ram[i]=0;
 $readmemh("autostart_cpu_rom.hex",dut.c64.buslogic.kernel_c64.ram);
 repeat(100)@(negedge b);force dut.core_run=1;
 wait(entries==1 && waits>2);repeat(100)@(negedge b);
 force dut.load_state=12;
 repeat(100)@(negedge b);
 if(dut.disk_autostart.line_dirty)$fatal(1,"boot keyboard guard incorrectly treated as user input");
 wait(dut.autostart_prompt);@(negedge b);
 if(entries!=1 || waits<2)$fatal(1,"opcode tap includes data reads or missed CPU fetches %d/%d",entries,waits);
 force dut.os_menu=1;force dut.cont1_key=32'h20;repeat(8)@(negedge b);
 force dut.disk_mounted=1;repeat(8)@(negedge b);
 force dut.os_menu=0;repeat(16)@(negedge b);
 if(dut.autostart_typing || dut.autostart_keys!=0)$fatal(1,"menu-closing button started typing");
 if(dut.disk_autostart.state!=1)$fatal(1,"menu-closing button cancelled request");
 force dut.cont1_key=0;
 wait(dut.autostart_typing);@(negedge b);
 if(dut.combined_keys!==(64'b1<<42))$fatal(1,"top-level L contact missing");
 force dut.cont1_key=32'h20;repeat(8)@(negedge b);
 if(dut.autostart_keys!==0)$fatal(1,"top-level controller cancel failed");
 $display("PASS actual 6510 opcode tap: ROM data fetch excluded, READY observed, mount CDC, menu-close held-button guard, LOAD contact, controller cancels");$finish;
end
initial begin #10000000;$fatal(1,"CPU tap timeout pc=%h entries=%d waits=%d",dut.c64.cpuaddr_pre,entries,waits);end
endmodule
