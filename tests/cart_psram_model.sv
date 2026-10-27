`timescale 1ns/1ps
// Independent pin-level model: 70ns array from ADV latch, 20ns output enable.
module cart_psram_model #(parameter INITIAL_WORD=16'h1234)(input wire [21:16] a,inout wire [15:0] dq,
 input wire clk,adv,cre,ce0,ce1,oe,we,ub,lb);
reg [15:0] memory[0:524287];reg [21:0] latched;
reg [15:0] value=16'hxxxx,captured;
reg writing=0,saved_ub,saved_lb;
realtime adv_time,write_time,data_time;
integer i;
initial for(i=0;i<524288;i=i+1)memory[i]=INITIAL_WORD;
assign #20 dq=(!oe && !ce0 && ce1 && adv && we) ? value:16'hzzzz;
always @(negedge adv)adv_time=$realtime;
always @(posedge adv)if(!ce0 || !ce1)begin
 latched={a,dq};
 if(ce0!==0 || ce1!==1 || cre!==0 || clk!==0 || latched>=524288)$fatal(1,"cartridge PSRAM pin/address range");
 if(!we)begin writing=1;saved_ub=ub;saved_lb=lb;end
 value=16'hxxxx;#70 value=memory[latched];
end
always @(negedge we)write_time=$realtime;
always @(dq)if(writing && !we && adv && (^dq!==1'bx))begin captured=dq;data_time=$realtime;end
always @(posedge we)if(writing)begin
 if($realtime-write_time<45 || $realtime-adv_time<70 || $realtime-data_time<20)$fatal(1,"cartridge PSRAM write timing");
 if(!saved_lb)memory[latched][7:0]=captured[7:0];
 if(!saved_ub)memory[latched][15:8]=captured[15:8];
 writing=0;
end
endmodule
