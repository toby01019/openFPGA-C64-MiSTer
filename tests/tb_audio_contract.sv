`timescale 1ns/1ps
// Decode the external pins only, with a continuously running Pocket-side
// MCLK / 4 divider. A core restart must not restart that receiver's clock.
module tb;
reg clk74=0,core_clk=0,reset74=1;
always #6.734 clk74=~clk74;
always #15.859 core_clk=~core_clk;
reg reset_meta=1,core_reset=1;
always @(posedge core_clk) begin reset_meta<=reset74;core_reset<=reset_meta;end
reg [15:0] source=16'h1234;
always @(posedge core_clk) if(!core_reset) source<={source[14:0],source[15]^source[13]^source[12]^source[10]};
wire mclk,lrck,dac;
pocket_audio dut(.clk74(clk74),.reset74(reset74),.core_clk(core_clk),.core_reset(core_reset),
 .left({source,2'b0}),.right({~source,2'b0}),.mclk(mclk),.lrck(lrck),.dac(dac));
integer master_edges=0,prev_transition=0,transitions=0,frames=0,silent=0;
reg previous_lr=0;
reg [1:0] divider=0;
reg [15:0] left_word=0,right_word=0;
integer bits=0;
reg locked=0,have_left=0;
always @(posedge mclk) begin
 master_edges=master_edges+1;divider<=divider+1'b1;
 // Falling SCLK is at MCLK edge 4; sample at rising SCLK, edge 2.
 if(divider==1) begin
  #1;
  if(lrck!=previous_lr) begin
   if(locked && master_edges-prev_transition!=128)
    $fatal(1,"I2S channel truncated across restart: %0d MCLK edges, expected 128",master_edges-prev_transition);
   previous_lr=lrck;prev_transition=master_edges;transitions=transitions+1;
   bits=0;locked=1;
  end else if(locked) begin
   if(bits<16) begin
    if(lrck)right_word={right_word[14:0],dac};else left_word={left_word[14:0],dac};
    if(bits==15) begin
     if(!lrck)have_left=1;
     else if(have_left) begin
      if(left_word==0 && right_word==0)silent=silent+1;
      else if(right_word!==~left_word)$fatal(1,"torn stereo sample %h/%h",left_word,right_word);
      else frames=frames+1;
     end
    end
   end else if(dac!==0)$fatal(1,"nonzero I2S padding");
   bits=bits+1;
  end
 end
end
integer n;
initial begin
 repeat(23)@(negedge clk74);reset74=0;
 #250000;
 // Restart at different positions in both channels, including long resets.
 for(n=0;n<8;n=n+1) begin
  #(1307+n*503);@(negedge clk74);reset74=1;
  repeat(13+n*17)@(negedge clk74);reset74=0;
  #85000;
 end
 @(negedge clk74);reset74=1;#150000;
 if(silent<5)$fatal(1,"reset did not produce complete silence frames");
 @(negedge clk74);reset74=0;#150000;
 if(frames<35 || transitions<100)$fatal(1,"insufficient dynamic stereo coverage");
 $display("PASS I2S contract: %0d changing stereo frames, %0d silent frames, continuous 48 kHz framing through 9 resets",frames,silent);$finish;
end
initial begin #2000000;$fatal(1,"audio contract timeout");end
endmodule
