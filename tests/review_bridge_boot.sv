`timescale 1ns/1ps
module tb;
reg clk=0,boot_done=0,setup_done=0;
always #5 clk=~clk;
reg [31:0] addr=0,wdata=0;
reg wr=0;
wire reset_n;
core_bridge_cmd dut(.clk(clk),.reset_n(reset_n),.bridge_endian_little(1'b0),
 .bridge_addr(addr),.bridge_rd(1'b0),.bridge_wr(wr),.bridge_wr_data(wdata),
 .status_boot_done(boot_done),.status_setup_done(setup_done),.status_running(reset_n),
 .i_cpu_clk(clk),.i_cpu_req(1'b0),.i_cpu_addr(32'b0),
 .i_cpu_wdata(32'b0),.i_cpu_wstrb(4'b0));
task write_bridge(input [31:0] a,input [31:0] d);
begin
 @(negedge clk);addr=a;wdata=d;wr=1;
 @(negedge clk);wr=0;
end
endtask
task command(input [15:0] cmd,input [15:0] expected);
begin
 write_bridge(32'hf8000000,{16'h434d,cmd});
 wait(dut.host_0[31:16]===16'h4f4b);
 if(dut.host_0[15:0]!==expected)
   $fatal(1,"command %h result=%h expected=%h",cmd,dut.host_0,expected);
end
endtask
initial begin
 repeat(10) @(negedge clk);
 command(0,1); // PLLs not yet ready: Booting.
 boot_done=1;setup_done=1;
 repeat(10) @(negedge clk);
 command(0,2); // Must remain Setup while the Pocket loads slot metadata.
 if(dut.target_0!==0 || reset_n!==0) $fatal(1,"premature Ready To Run");
 command(16'h008f,0);
 wait(dut.target_0===32'h636d0140);
 command(0,3);
 write_bridge(32'hf8001000,32'h6f6b0000);
 repeat(8) @(negedge clk);
 command(16'h0011,0);
 if(reset_n!==1) $fatal(1,"reset exit missing");
 command(0,4);
 command(16'h0010,0);
 if(reset_n!==0) $fatal(1,"reset enter missing");
 command(0,3);
 command(16'h0011,0);
 command(0,4);
 if(dut.target_0!==32'h6f6b0000) $fatal(1,"spurious repeated Ready To Run");
 $display("PASS APF boot: Booting1, Setup2, 008F, Ready0140, Idle3, ResetExit, Running4, ResetEnter and restart");
 $finish;
end
initial begin #100000;$fatal(1,"APF boot timeout");end
endmodule
