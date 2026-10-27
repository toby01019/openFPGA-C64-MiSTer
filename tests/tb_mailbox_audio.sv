`timescale 1ns/1ps
module tb;
reg a=0,b=0,reset=1,valid=0,ready=0;
always #6.734 a=~a;
always #15.873 b=~b;
reg [25:0] data=0;
wire done,pending;
wire [25:0] outdata;
integer sent=0,received=0;
pocket_mailbox box(.src_clk(a),.src_reset(reset),.src_valid(valid),.src_data(data),
 .src_done(done),.dst_clk(b),.dst_reset(reset),.dst_valid(pending),.dst_data(outdata),.dst_ready(ready));
always @(negedge b) ready=($random & 3)!=0;
always @(posedge b) if(!reset && pending && ready) begin
 if(outdata!==26'(received*257+19)) $fatal(1,"mailbox torn/duplicate/missing data at %0d",received);
 received=received+1;
end
wire mclk,lrck,dac;
pocket_audio tx(.clk74(a),.reset74(reset),.core_clk(b),.core_reset(reset),
 .left({16'h1234,2'b0}),.right({16'habcd,2'b0}),.mclk(mclk),.lrck(lrck),.dac(dac));
reg [1:0] md=0;
reg last_lr=0;
reg [15:0] word_l=0,word_r=0;
integer bits=0,good_l=0,good_r=0;
always @(posedge mclk) begin
 md<=md+1'b1;
 if(md==1 && !reset) begin
  #1;
  if(lrck!=last_lr) begin
   last_lr=lrck;bits=0;
  end else begin
   if(bits<16) begin
    if(lrck) word_r={word_r[14:0],dac};else word_l={word_l[14:0],dac};
    if(bits==15) begin
      if(lrck && word_r==16'habcd) good_r=good_r+1;
      if(!lrck && word_l==16'h1234) good_l=good_l+1;
    end
   end
   bits=bits+1;
  end
 end
end
initial begin
 repeat(10) @(negedge a); reset=0;
 for(sent=0;sent<300;sent=sent+1) begin
   @(negedge a);data=26'(sent*257+19);valid=1;
   wait(done);@(negedge a);valid=0;
   repeat(3) @(negedge a);
 end
 if(received!=300) $fatal(1,"mailbox count");
 #200000;
 if(good_l<3 || good_r<3) $fatal(1,"I2S stereo/delay wrong left=%h right=%h counts=%0d/%0d",word_l,word_r,good_l,good_r);
 $display("PASS 300 asynchronous mailbox transfers with backpressure; decoded I2S stereo 1234/abcd (%0d/%0d frames)",good_l,good_r);$finish;
end
initial begin #2000000;$fatal(1,"unit test timeout");end
endmodule
