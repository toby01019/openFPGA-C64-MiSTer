`timescale 1ns/1ps
module tb;
reg clk=0;always #15.859 clk=~clk;
reg reset=1,enable=1;reg[1:0]cfg=3;reg wrap=0;
wire req;wire[15:0]da;wire[7:0]dd;wire dwe;reg[7:0]c64[0:65535];wire[7:0]di=c64[da];
reg[4:0]phase=0;always @(posedge clk)if(enable)phase<=phase+1'b1;
wire dc=phase[4];wire[23:0]ra;wire[7:0]rdout;reg[7:0]rdin=0;wire rwe,rstart;reg rready=1,rack=0;
reg[15:0]ca=0;reg[7:0]cd=0;wire[7:0]cq;reg cwe=0,cs=0;wire irq;
pocket_reu dut(.clk(clk),.reset(reset),.enable(enable),.cfg(cfg),.wrap(wrap),.dma_req(req),.dma_cycle(dc),.dma_addr(da),.dma_dout(dd),.dma_din(di),.dma_we(dwe),
.ram_cycle(1'b0),.ram_ready(rready),.ram_ack(rack),.ram_start(rstart),.ram_addr(ra),.ram_dout(rdout),.ram_din(rdin),.ram_we(rwe),
.cpu_addr(ca),.cpu_dout(cd),.cpu_din(cq),.cpu_we(cwe),.cpu_cs(cs),.irq(irq));
reg[7:0]ram[0:16777215];integer delay_count=0,requests=0;reg[23:0]latched;reg[7:0]latched_data;reg latched_write;
always @(posedge clk)begin
 rack<=0;
 if(enable && dwe)c64[da]<=dd;
 if(rstart)begin
  if(!rready)$fatal(1,"start while busy");
  rready<=0;latched<=ra;latched_data<=rdout;latched_write<=rwe;delay_count<=8+requests%5;requests<=requests+1;
 end else if(delay_count>0)begin
  delay_count<=delay_count-1;
  if(delay_count==1)begin
   if(latched_write)ram[latched]<=latched_data;
   rdin<=ram[latched];rack<=1;rready<=1;
  end
 end
end
task poke(input[4:0]regno,input[7:0]v);begin
 @(negedge clk);ca=16'hdf00+regno;cd=v;cwe=1;cs=1;
 @(negedge clk);cs=0;cwe=0;@(negedge clk);
end endtask
task peek(input[4:0]regno,output[7:0]v);begin
 @(negedge clk);ca=16'hdf00+regno;cwe=0;cs=1;
 @(negedge clk);v=cq;cs=0;@(negedge clk);
end endtask
task setup(input[15:0]caddr,input[23:0]raddr,input[15:0]len,input[7:0]ctl);begin
 poke(2,caddr[7:0]);poke(3,caddr[15:8]);poke(4,raddr[7:0]);poke(5,raddr[15:8]);poke(6,raddr[23:16]);poke(7,len[7:0]);poke(8,len[15:8]);poke(10,ctl);
end endtask
task finish_dma;integer timeout;begin
 timeout=0;while(req!==1 && timeout<10)begin @(negedge clk);timeout=timeout+1;end
 if(req!==1)$fatal(1,"no DMA");
 while(req)@(negedge clk);
 repeat(3)@(negedge clk);
end endtask
task run(input[1:0]kind);begin poke(1,8'h90|kind);finish_dma;end endtask
integer i,n;reg[7:0]status;reg[15:0]saved_addr;
initial begin #300000000;$fatal(1,"timeout");end
initial begin
 for(i=0;i<65536;i=i+1)c64[i]=(i*13+7)&255;
 repeat(4)@(negedge clk);reset=0;
 setup(16'h2000,24'h123456,16,0);run(0);
 for(i=0;i<16;i=i+1)if(ram[24'h123456+i]!==c64[16'h2000+i])$fatal(1,"C64->REU");
 setup(16'h3000,24'h123456,16,0);run(1);
 for(i=0;i<16;i=i+1)if(c64[16'h3000+i]!==c64[16'h2000+i])$fatal(1,"REU->C64");
 for(i=0;i<16;i=i+1)begin c64[16'h4000+i]=8'h80+i;ram[24'h234560+i]=8'h30+i;end
 setup(16'h4000,24'h234560,16,0);run(2);
 for(i=0;i<16;i=i+1)if(c64[16'h4000+i]!==8'h30+i || ram[24'h234560+i]!==8'h80+i)$fatal(1,"swap");
 peek(0,status);poke(9,8'he0);setup(16'h2000,24'h123456,16,0);run(3);
 if(!irq)$fatal(1,"end IRQ");peek(0,status);if(status!==8'hd0)$fatal(1,"verify equal %h",status);if(irq)$fatal(1,"IRQ clear");
 ram[24'h123456]=8'hff;setup(16'h2000,24'h123456,16,0);n=requests;run(3);
 peek(0,status);if(status!==8'hf0 || requests-n!=1)$fatal(1,"verify mismatch %h",status);
 setup(16'h5000,24'h100000,4,8'h80);run(0);
 for(i=0;i<4;i=i+1)if(ram[24'h100000+i]!==c64[16'h5000])$fatal(1,"fixed C64");
 setup(16'h5000,24'h100100,4,8'h40);run(0);if(ram[24'h100100]!==c64[16'h5003])$fatal(1,"fixed REU");
 cfg=1;setup(16'h2000,24'hfffffe,4,0);run(0);
 if(ram[24'h7fffe]!==c64[16'h2000] || ram[0]!==c64[16'h2002])$fatal(1,"512K mask/wrap");
 cfg=2;setup(16'h2000,24'hfffffe,4,0);run(0);
 if(ram[24'h1ffffe]!==c64[16'h2000] || ram[0]!==c64[16'h2002])$fatal(1,"2M mask/wrap");
 cfg=3;setup(16'h2000,24'hfffffe,4,0);run(0);
 if(ram[24'hfffffe]!==c64[16'h2000] || ram[0]!==c64[16'h2002])$fatal(1,"16M wrap");
 wrap=1;setup(16'h2000,24'h17fffe,4,0);run(0);wrap=0;
 if(ram[24'h100000]!==c64[16'h2002])$fatal(1,"512K bank wrap");
 setup(16'h2000,24'h900,1,0);poke(1,8'h80);repeat(30)@(negedge clk);if(req)$fatal(1,"premature FF00");
 ca=16'hff00;cwe=1;@(negedge clk);cwe=0;finish_dma;if(ram[24'h900]!==c64[16'h2000])$fatal(1,"FF00");
 // A completion arrives while paused; no C64 phase/count may run away.
 setup(16'h6000,24'h900,1,0);poke(1,8'h91);wait(rstart);@(negedge clk);enable=0;saved_addr=da;
 repeat(30)@(negedge clk);if(da!==saved_addr || !req)$fatal(1,"pause advanced DMA");
 enable=1;finish_dma;if(c64[16'h6000]!==ram[24'h900])$fatal(1,"lost paused ack");
 // Stop mid C64 DMA phase: the 16-tick cycle must resume, not finish while paused.
 setup(16'h6100,24'h900,1,0);poke(1,8'h91);wait(dwe && dc);
 repeat(4)@(negedge clk);enable=0;saved_addr=da;
 repeat(40)@(negedge clk);if(da!==saved_addr || !req || dwe)$fatal(1,"paused C64 DMA count/strobe");
 enable=1;finish_dma;if(c64[16'h6100]!==ram[24'h900])$fatal(1,"resume C64 DMA");
 setup(16'h2000,24'h900,1,0);poke(1,8'hb0);finish_dma;peek(2,status);if(status!==0)$fatal(1,"autoload address");peek(7,status);if(status!==1)$fatal(1,"autoload length");
 setup(0,24'h400000,0,0);n=requests;run(0);
 if(requests-n!=65536)$fatal(1,"length zero %d",requests-n);
 for(i=0;i<65536;i=i+1)if(ram[24'h400000+i]!==c64[i])$fatal(1,"64K data %d",i);
 setup(16'h2000,24'h900,20,0);poke(1,8'h91);wait(rstart);@(negedge clk);reset=1;repeat(20)@(negedge clk);reset=0;
 repeat(5)@(negedge clk);if(req || irq || rstart || dwe)$fatal(1,"reset");
 cfg=0;repeat(3)@(negedge clk);if(req || irq || cq!==8'hff)$fatal(1,"disabled");
 $display("PASS REU all four DMA modes; variable 8-12 clock RAM; 64K length; fixed addresses; 512K/2M/16M masks/wrap; IRQ; FF00; autoload; pause ack; reset");$finish;
end
endmodule
