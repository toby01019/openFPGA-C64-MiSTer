`timescale 1ns/1ps
module tb;
reg clk=0,clk74=0,reset=1;
integer model=1;
reg [31:0] signature=0;
always #15.859 clk=~clk;
always #6.734 clk74=~clk74;
reg [4:0] phase=0;
always @(posedge clk) phase<=phase+1'b1;
wire ce=phase==31;
reg [1:0] cs=0;
reg we=0;
reg [4:0] addr=0;
reg [7:0] data=0;
wire [17:0] l,r;
sid_top sid(.clk(clk),.reset(reset),.ce_1m(ce),.cs(cs),.we(we),
 .addr(addr),.data_in(data),.mode({2{model[0]}}),.cfg(4'b0),.filter_en(2'b11),
 .fc_offset_l(13'b0),.fc_offset_r(13'b0),.pot_x_l(8'b0),.pot_y_l(8'b0),
 .pot_x_r(8'b0),.pot_y_r(8'b0),.ext_in_l(18'b0),.ext_in_r(18'b0),
 .ld_clk(clk),.ld_addr(12'b0),.ld_data(16'b0),.ld_wr(1'b0),.audio_l(l),.audio_r(r));
wire mclk,lrck,dac;
pocket_audio tx(.clk74(clk74),.reset74(reset),.core_clk(clk),.core_reset(reset),
 .left(l),.right(r),.mclk(mclk),.lrck(lrck),.dac(dac));
// Real SID writes/voices/filter; no force or fabricated filter result.
task write_sid(input [4:0] a,input [7:0] d);
begin
 @(negedge clk);addr=a;data=d;cs=3;we=1;
 repeat(40)@(negedge clk);cs=0;we=0;
 repeat(4)@(negedge clk);
end
endtask
// Both chips have the same program. Valid decoded frames must be mono,
// match an actual emitted SID sample, and contain a changing waveform.
reg [65535:0] seen=0;
reg checking=0;
always @(posedge clk) if(!reset) begin
 if(checking && ((^l)===1'bx || (^r)===1'bx))$fatal(1,"unknown SID output");
 if(checking && l!==r)$fatal(1,"identical SID programs produced differing channels %h/%h",l,r);
 if((^l)!==1'bx) seen[l[17:2]]=1;
end
reg [1:0] md=0;
reg old_lr=0,locked=0,have_left=0;
reg [15:0] word_l=0,word_r=0,prev_sample=0;
integer bits=0,checked=0,changed=0,nonzero=0;
always @(posedge mclk) begin
 md<=md+1'b1;
 if(md==1)begin
  #1;
  if(lrck!=old_lr)begin old_lr=lrck;bits=0;locked=1;end
  else if(locked)begin
   if(bits<16)begin
    if(lrck)word_r={word_r[14:0],dac};else word_l={word_l[14:0],dac};
    if(bits==15)begin
     if(!lrck)have_left=1;
     else if(have_left && checking)begin
      if(word_l!==word_r)$fatal(1,"I2S changed mono SID into stereo %h/%h",word_l,word_r);
      if(!seen[word_l])$fatal(1,"I2S sample %h was never emitted by SID",word_l);
      checked=checked+1;signature=signature*33+word_l;
      if(word_l!=0)nonzero=nonzero+1;
      if(word_l!=prev_sample)changed=changed+1;
      prev_sample=word_l;
     end
    end
   end
   bits=bits+1;
  end
 end
end
initial begin
 if($value$plusargs("MODEL=%d",model))begin end
 repeat(128)@(negedge clk);reset=0;
 write_sid(0,8'h00);write_sid(1,8'h20);
 write_sid(5,0);write_sid(6,8'hf0);write_sid(24,15);
 write_sid(4,8'h21); // Sawtooth, gate on, fastest attack.
 #300000;
 checking=1;
 // History includes the earlier samples still in the transport pipeline.
 have_left=0;#2500000;
 if(checked<90 || nonzero<80 || changed<70)$fatal(1,"missing SID waveform %0d/%0d/%0d",checked,nonzero,changed);
 $display("PASS real SID-to-I2S: %0d frames, %0d changing samples, identical stereo, every decoded value belongs to the SID waveform",checked,changed);
 $display("MODEL %0d SIGNATURE %h",model,signature);
 $finish;
end
initial begin #4000000;$fatal(1,"SID I2S timeout");end
endmodule
