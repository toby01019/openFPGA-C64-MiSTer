`timescale 1ns/1ps
module tb;
reg clk=0, reset=1, ce=0;
always #5 clk=~clk;
wire [17:0] l,r;
reg [17:0] filter_value=0;
integer cycle=0, saturated=0, checked=0;
sid_top dut(.clk(clk),.reset(reset),.ce_1m(ce),.cs(2'b0),.we(1'b0),
 .addr(5'b0),.data_in(8'b0),.mode(2'b11),.cfg(4'b0),.filter_en(2'b11),
 .fc_offset_l(13'b0),.fc_offset_r(13'b0),.pot_x_l(8'b0),.pot_y_l(8'b0),
 .pot_x_r(8'b0),.pot_y_r(8'b0),.ext_in_l(18'b0),.ext_in_r(18'b0),
 .ld_clk(clk),.ld_addr(12'b0),.ld_data(16'b0),.ld_wr(1'b0),.audio_l(l),.audio_r(r));
// Inject the MAC's specified latency at its boundary, retaining the real
// SID scheduler and output registers. Intermediate values must never escape.
initial force dut.faudio=filter_value;
always @(negedge clk) begin
 cycle=cycle+1; reset=cycle<4; ce=(cycle%32)==0;
 if(dut.state==15) saturated=saturated+1; else saturated=0;
 filter_value=dut.state==8 ? 18'h1111 :
              saturated>=2 ? 18'h2222 : 18'h3dead;
end
always @(posedge clk) if(!reset && cycle>65) begin
 #1;
 if(r!==0 && r!==18'h2222) $fatal(1,"SID right channel exposed intermediate %h at cycle %0d",r,cycle);
 if(l!==0 && l!==18'h1111) $fatal(1,"SID left channel incorrect %h",l);
 if(l==18'h1111 && r==18'h2222) checked=checked+1;
 if(cycle>650) begin
  if(checked<200)$fatal(1,"not enough stable stereo samples");
  $display("PASS SID capture: no intermediate samples during 10 stereo updates");$finish;
 end
end
endmodule

