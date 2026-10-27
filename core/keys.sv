// SPDX-License-Identifier: MIT
// MiSTer keyboard events: toggle, pressed, extended, PS/2 set-2 scan code.
module pocket_keys(input wire clk,reset,input wire [7:0] desired,
 output reg [10:0] ps2_key=0);
 reg [7:0] sent=0;
 reg [2:0] scan=0;
 reg [5:0] pace=0;
 function automatic [7:0] code(input [2:0] n);
 case(n)
 0:code=8'h5a;1:code=8'h29;2:code=8'h05;3:code=8'h12;
 4:code=8'h2d;5:code=8'h3c;6:code=8'h31;7:code=8'h76;
 endcase
 endfunction
 always @(posedge clk) begin
   if(reset) begin ps2_key<=0;sent<=0;scan<=0;pace<=0;end
   else begin
     pace<=pace+1'b1;
     if(pace==0) begin
       scan<=scan+1'b1;
       if(sent[scan]!=desired[scan]) begin
         ps2_key<={~ps2_key[10],desired[scan],1'b0,code(scan)};
         sent[scan]<=desired[scan];
       end
     end
   end
 end
endmodule
