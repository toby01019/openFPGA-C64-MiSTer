`timescale 1ns/1ps
module tb;
reg clk=0;always #15.859 clk=~clk;
reg reset=1,start=0,write=0;reg[23:0]addr=0;reg[7:0]wdata=0;wire ready,done;wire[7:0]rdata;
wire[21:16]a;tri[15:0]dq;wire ramclk,adv,cre,ce0,ce1,oe,we,ub,lb;
pocket_psram dut(.clk(clk),.reset(reset),.start(start),.write(write),.addr(addr),.wdata(wdata),.ready(ready),.done(done),.rdata(rdata),
.cram_a(a),.cram_dq(dq),.cram_wait(1'b1),.cram_clk(ramclk),.cram_adv_n(adv),.cram_cre(cre),.cram_ce0_n(ce0),.cram_ce1_n(ce1),.cram_oe_n(oe),.cram_we_n(we),.cram_ub_n(ub),.cram_lb_n(lb));
// Pin-level asynchronous CellularRAM: address latched on ADV rising edge,
// 70-ns array delay plus 20-ns OE delay; writes commit when WE rises.
reg[15:0]mem[0:8388607];reg[22:0]latched;reg[15:0]value=16'hxxxx,captured;
reg saved_ub,saved_lb,writing=0;integer cycles=0;realtime adv_time,write_time,data_time;
assign #20 dq=(!oe && (!ce0 || !ce1) && adv && we) ? value:16'hzzzz;
always @(negedge adv) begin adv_time=$realtime;cycles=cycles+1;end
always @(posedge adv) if(!ce0 || !ce1) begin
 latched={!ce1,a,dq};
 if(latched[21:0]===22'h3fffff)$fatal(1,"forbidden physical last word");
 if((ce0===0 && ce1===0) || cre!==0 || ramclk!==0)$fatal(1,"chip selection");
 if(!we)begin writing=1;saved_ub=ub;saved_lb=lb;end
 value=16'hxxxx;
 #70 value=mem[latched];
end
always @(negedge we)write_time=$realtime;
always @(dq)if(writing && !we && adv && (^dq!==1'bx))begin captured=dq;data_time=$realtime;end
always @(posedge we)if(writing)begin
 if($realtime-write_time<45 || $realtime-adv_time<70 || $realtime-data_time<20)$fatal(1,"write timing");
 if(!saved_ub)mem[latched][15:8]=captured[15:8];
 if(!saved_lb)mem[latched][7:0]=captured[7:0];
 writing=0;
end
always @(negedge clk)if(ce0===0 && ce1===0)$fatal(1,"both chips active");
task access(input bit wr,input[23:0]address,input[7:0]data);
begin
 while(!ready)@(negedge clk);
 start=1;write=wr;addr=address;wdata=data;
 @(negedge clk);start=0;addr=24'h123456;wdata=8'h00;write=~wr;
 while(!done)@(negedge clk);
 if(!wr && rdata!==data)$fatal(1,"read %h expected %h got %h",address,data,rdata);
end endtask
integer i,before_shadow;reg[23:0]base;
initial begin #1000000;$fatal(1,"timeout");end
initial begin
 repeat(5)@(negedge clk);reset=0;repeat(3)@(negedge clk);
 for(i=0;i<32;i=i+1)begin
  base=(i[0] ? 24'h800000:0)+(i*12346);
  access(1,base,8'ha0+i);access(1,base+1,8'h30+i);
  access(0,base,8'ha0+i);access(0,base+1,8'h30+i);
  access(1,base,8'hc0+i);access(0,base+1,8'h30+i);
 end
 access(1,24'h7ffffc,8'h55);access(1,24'hfffffd,8'h66);
 access(0,24'h7ffffc,8'h55);access(0,24'hfffffd,8'h66);
 before_shadow=cycles;
 access(1,24'h7ffffe,8'h12);access(1,24'h7fffff,8'h34);
 access(1,24'hfffffe,8'h56);access(1,24'hffffff,8'h78);
 access(0,24'h7ffffe,8'h12);access(0,24'h7fffff,8'h34);
 access(0,24'hfffffe,8'h56);access(0,24'hffffff,8'h78);
 if(cycles!=before_shadow)$fatal(1,"shadow used pins");
 // Reset during an actual write drains it without truncating the pin cycle.
 while(!ready)@(negedge clk);start=1;write=1;addr=24'h800020;wdata=8'h9a;
 @(negedge clk);start=0;wait(!we);@(negedge clk);reset=1;
 repeat(12)begin @(negedge clk);if(done || ready)$fatal(1,"reset handshake");end
 if(!ce0 || !ce1 || !we || !oe || !adv)$fatal(1,"reset left pins active");
 reset=0;repeat(3)@(negedge clk);access(0,24'h800020,8'h9a);
 // Reset after acceptance but before launch must not touch memory.
 while(!ready)@(negedge clk);before_shadow=cycles;start=1;write=1;addr=24'h800020;wdata=8'hff;
 @(negedge clk);start=0;reset=1;repeat(4)@(negedge clk);reset=0;
 repeat(3)@(negedge clk);if(cycles!=before_shadow)$fatal(1,"prelaunch reset touched pins");
 access(0,24'h800020,8'h9a);
 // Reset during a read suppresses its completion and returns the bus to idle.
 while(!ready)@(negedge clk);start=1;write=0;addr=24'h800020;
 @(negedge clk);start=0;wait(!adv);@(negedge clk);reset=1;
 repeat(10)begin @(negedge clk);if(done || ready)$fatal(1,"read reset handshake");end
 reset=0;repeat(3)@(negedge clk);if(done)$fatal(1,"stale completion");
 access(0,24'h7ffffe,8'h12);access(0,24'h7fffff,8'h34);
 access(0,24'hfffffe,8'h56);access(0,24'hffffff,8'h78);
 $display("PASS PSRAM pin-level 70ns array +20ns OE, byte lanes, both dies, shadows, back-to-back and reset drain (%d physical cycles)",cycles);$finish;
end
endmodule
