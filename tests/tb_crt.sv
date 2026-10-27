`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg reset=1,load_start=0,valid=0,finish=0;reg[31:0]size=0;reg[7:0]data=0;wire ready,busy,attached,error;wire[3:0]code;wire[7:0]id,bn,bp;wire exrom,game,bw,bhi,b16;
wire start;reg rr=1,ack=0;wire[23:0]addr;wire[7:0]wd;
pocket_crt dut(.clk(clk),.reset(reset),.load_start(load_start),.file_size(size),.byte_valid(valid),.byte_data(data),.byte_ready(ready),.finish(finish),.busy(busy),.attached(attached),.error(error),.error_code(code),.cart_id(id),.cart_exrom(exrom),.cart_game(game),.bank_wr(bw),.bank_hi(bhi),.bank_16k(b16),.bank_num(bn),.bank_page(bp),.ram_start(start),.ram_ready(rr),.ram_ack(ack),.ram_addr(addr),.ram_wdata(wd));
reg[7:0]stream[0:2200000],memory[0:2097151];integer delay_count=0,writes=0,banks=0;reg[23:0]saved_addr;reg[7:0]saved_data;
reg[25:0]meta[0:255];
always @(posedge clk)begin
 ack<=0;
 if(start)begin
  if(!rr || addr<24'h200000 || addr>=24'h400000)$fatal(1,"RAM contract");
  rr<=0;saved_addr<=addr;saved_data<=wd;delay_count<=8+writes%5;
 end else if(delay_count!=0)begin
  delay_count<=delay_count-1;
  if(delay_count==1)begin memory[saved_addr-24'h200000]<=saved_data;writes<=writes+1;rr<=1;ack<=1;end
 end
 if(bw)begin meta[banks]<={bhi,b16,bn,bp};banks<=banks+1;end
end
integer actual=0,success=0,wantedwrites=0,wantedbanks=0,expectedsize=0,i,j;reg[4095:0]path;
initial begin
 if(!$value$plusargs("FILE=%s",path))$fatal;
 if(!$value$plusargs("ACTUAL=%d",actual))$fatal;
 if(!$value$plusargs("SIZE=%d",expectedsize))$fatal;
 if(!$value$plusargs("SUCCESS=%d",success))$fatal;
 if(!$value$plusargs("WRITES=%d",wantedwrites))$fatal;
 if(!$value$plusargs("BANKS=%d",wantedbanks))$fatal;
 $readmemh(path,stream,0,actual-1);
 repeat(3)@(negedge clk);reset=0;load_start=1;size=expectedsize;
 @(negedge clk);load_start=0;
 for(i=0;i<actual;i=i+1)begin
  if(i%17==0)begin valid=0;repeat(2)@(negedge clk);end
  valid=1;data=stream[i];
  while(!ready && busy)@(negedge clk);
  if(!busy)begin i=actual;valid=0;end
  else begin @(negedge clk);valid=0;end
 end
 finish=1;@(negedge clk);finish=0;
 while(busy)@(negedge clk);repeat(2)@(negedge clk);
 if(success)begin
  if(!attached || error || writes!=wantedwrites || banks!=wantedbanks)$fatal(1,"valid CRT failed attach=%b err=%d writes=%d banks=%d",attached,code,writes,banks);
  $writememh("result.hex",memory,0,writes-1);$writememh("meta.hex",meta,0,banks-1);
 end else if(attached || !error)$fatal(1,"invalid attached");
 reset=1;@(negedge clk);if(attached || error || busy)$fatal(1,"reset state");
 $display("PASS CRT success=%d writes=%d banks=%d errorcode=%d",success,writes,banks,code);$finish;
end
initial begin #1000000000;$fatal(1,"timeout");end
endmodule

