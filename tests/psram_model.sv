`timescale 1ns/1ps
// Independent pin model used by the complete C64/REU integration test.
module psram_model(input [21:16] a,inout [15:0] dq,
 input adv,cre,ramclk,ce0,ce1,oe,we,ub,lb);
reg [15:0] mem[0:8388607];
reg [22:0] address;reg [15:0] read_data=16'hxxxx,write_data;
reg writing=0,saved_ub,saved_lb;
realtime write_time,data_time,adv_time;
integer writes=0,reads=0;
assign #20 dq=(!oe && (!ce0 || !ce1) && adv && we) ? read_data:16'hzzzz;
always @(negedge adv)adv_time=$realtime;
always @(posedge adv)if(!ce0 || !ce1)begin
 address={!ce1,a,dq};read_data=16'hxxxx;
 if(address[21:0]===22'h3fffff || (!ce0 && !ce1) || cre!==0 || ramclk!==0)$fatal(1,"PSRAM address/control");
 if(!we)begin writing=1;saved_ub=ub;saved_lb=lb;end
 else reads=reads+1;
 #70 read_data=mem[address];
end
always @(negedge we)write_time=$realtime;
always @(dq)if(writing && !we && adv && (^dq!==1'bx))begin write_data=dq;data_time=$realtime;end
always @(posedge we)if(writing)begin
 if($realtime-write_time<45 || $realtime-adv_time<70 || $realtime-data_time<20)$fatal(1,"PSRAM write timing");
 if(!saved_ub)mem[address][15:8]=write_data[15:8];
 if(!saved_lb)mem[address][7:0]=write_data[7:0];
 writing=0;writes=writes+1;
end
endmodule
