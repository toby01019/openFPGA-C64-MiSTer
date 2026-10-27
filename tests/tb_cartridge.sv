`timescale 1ns/1ps
module tb #(parameter ROM_BYTES=65536);
reg clk=0;always #15.859 clk=~clk;
reg reset=1,c64_reset=0,load_start=0,valid=0,finish=0;reg[31:0]size=0;reg[7:0]data=0;
wire ready,busy,attached,error;wire[3:0]code;
reg rl=0,rh=0,vic=0,ioe=0,iof=0,mwe=0,mce=0,freeze=0,nack=0;
reg[15:0]address=0;reg[7:0]cpu_data=0;wire exrom,game,iorom,iord,nmi,ceout,weout;wire[7:0]iodata,q,write_data_out;wire[24:0]mapped;
pocket_cartridge #(.ROM_BYTES(ROM_BYTES)) dut(.clk(clk),.reset(reset),.c64_reset(c64_reset),.load_start(load_start),.file_size(size),.byte_valid(valid),.byte_data(data),.byte_ready(ready),.finish(finish),.busy(busy),.attached(attached),.error(error),.error_code(code),
.romL(rl),.romH(rh),.UMAXromH(vic),.IOE(ioe),.IOF(iof),.mem_write(mwe),.mem_ce(mce),.addr_in(address),.data_in(cpu_data),.main_ram_data(8'hc7),.mem_data_out(write_data_out),.freeze_key(freeze),.mod_key(1'b0),.nmi_ack(nack),
.exrom(exrom),.game(game),.IO_rom(iorom),.IO_rd(iord),.IO_data(iodata),.data_out(q),.nmi(nmi),.mem_addr(mapped),.mem_ce_out(ceout),.mem_write_out(weout));
reg[7:0]stream[0:140000];reg[4095:0]path;integer actual,mode,i;
function[7:0]pattern(input integer offset,input integer seed);begin pattern=(offset*3+(offset>>8)*7+seed*29)&255;end endfunction
task read_cart(input[15:0]a,input integer which,input[7:0]wanted);begin
 @(negedge clk);address=a;rl=which==0;rh=which==1;vic=which==2;ioe=0;iof=0;mwe=0;mce=1;
 @(negedge clk);if(q!==wanted)$fatal(1,"one-cycle read address=%h mapped=%h got=%h want=%h",a,mapped,q,wanted);
 mce=0;rl=0;rh=0;vic=0;
end endtask
task bank_write(input[15:0]a,input[7:0]v);begin
 @(negedge clk);address=a;cpu_data=v;ioe=a[15:8]==8'hde;iof=a[15:8]==8'hdf;mwe=1;mce=1;
 repeat(3)@(negedge clk);ioe=0;iof=0;mwe=0;mce=0;repeat(3)@(negedge clk);
end endtask
task upload(input integer count);integer j;begin
 load_start=1;size=count;@(negedge clk);load_start=0;
 for(j=0;j<count;j=j+1)begin
  valid=1;data=stream[j];while(!ready && busy)@(negedge clk);
  if(!busy)begin valid=0;j=count;end else begin @(negedge clk);valid=0;end
 end
 finish=1;@(negedge clk);finish=0;while(busy)@(negedge clk);repeat(12)@(negedge clk);
end endtask
initial begin
 if(!$value$plusargs("FILE=%s",path))$fatal;if(!$value$plusargs("SIZE=%d",actual))$fatal;if(!$value$plusargs("MODE=%d",mode))$fatal;
 $readmemh(path,stream,0,actual-1);repeat(5)@(negedge clk);reset=0;upload(actual);
 if(mode>=10)begin
  if(attached || !error || exrom!==1 || game!==1)$fatal(1,"invalid/large cart attached");
 end else begin
  if(!attached || error)$fatal(1,"load failed %d",code);
  read_cart(16'h1234,3,8'hc7);
  @(negedge clk);address=16'h1234;cpu_data=8'h9a;mwe=1;mce=1;
  @(negedge clk);if(mapped!==25'h1234 || !weout || write_data_out!==8'h9a)$fatal(1,"main RAM write-through");
  mwe=0;mce=0;
  case(mode)
   0:begin
    if(exrom!==0 || game!==1)$fatal(1,"8K lines");read_cart(16'h8123,0,pattern('h123,0));
    read_cart(16'h9007,0,pattern('h1007,0));
   end
   1:begin
    if(exrom!==0 || game!==0)$fatal(1,"16K lines");read_cart(16'h8123,0,pattern('h123,0));read_cart(16'ha321,1,pattern('h2321,0));
   end
   2:begin
    if(exrom!==1 || game!==0)$fatal(1,"Ultimax lines");read_cart(16'he123,1,pattern('h123,0));read_cart(16'h3123,2,pattern('h1123,0));
   end
   3,4:begin
    read_cart(16'h8123,0,pattern('h123,0));bank_write(16'hde00,2);read_cart(16'h8123,0,pattern('h123,2));
    bank_write(16'hde00,63);read_cart(16'h8123,0,8'hff);
   end
   5:begin
    read_cart(16'h8123,0,pattern('h123,0));bank_write(16'hde00,8'h10);read_cart(16'h8123,0,pattern('h123,2));
    bank_write(16'hde00,8'h20);
    @(negedge clk);address=16'h8123;cpu_data=8'h5a;rl=1;mwe=1;mce=1;@(negedge clk);mwe=0;mce=0;rl=0;
    read_cart(16'h8123,0,8'h5a);
    bank_write(16'hde00,0);read_cart(16'h8123,0,pattern('h123,0));
    freeze=1;repeat(3)@(negedge clk);if(!nmi)$fatal(1,"AR freeze");freeze=0;nack=1;repeat(3)@(negedge clk);nack=0;
   end
   6:begin
    read_cart(16'h8123,0,pattern('h123,0));bank_write(16'hdfff,2);
    read_cart(16'h8123,0,pattern('h123,2));read_cart(16'ha123,1,pattern('h2123,2));
    read_cart(16'h3123,2,pattern('h3123,2));
   end
   8:begin
    bank_write(16'hde00,15);read_cart(16'h9fff,0,pattern('h1fff,15));
   end
   7:begin
    read_cart(16'h8123,0,pattern('h123,0));repeat(2)@(negedge clk);read_cart(16'ha123,1,pattern('h123,1));
    read_cart(16'h9123,0,pattern('h123,0));repeat(2)@(negedge clk);read_cart(16'ha123,1,pattern('h123,2));
   end
  endcase
 end
 if(mode<10)begin
  c64_reset=1;repeat(3)@(negedge clk);if(!attached || exrom!==1 || game!==1)$fatal(1,"soft reset lost cartridge");
  c64_reset=0;repeat(12)@(negedge clk);
  if(mode==5)begin bank_write(16'hde00,8'h20);read_cart(16'h8123,0,8'h5a);end
  upload(actual);if(!attached || error)$fatal(1,"reload");
 end else begin
  // Recover from every parser error without requiring a system reset.
  stream[23]=0;stream[24]=0;stream[25]=1;upload(8272);
  if(!attached || error)$fatal(1,"error recovery reload");read_cart(16'h8123,0,pattern('h123,0));
 end
 reset=1;@(negedge clk);if(attached || exrom!==1 || game!==1 || nmi)$fatal(1,"reset detach");
 $display("PASS compact cartridge mode=%d (real mapper, synchronous memory)",mode);$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
