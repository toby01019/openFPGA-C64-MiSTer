`timescale 1ns/1ps
module tb;
`include "keyboard_layout.vh"
reg clk=0;always #5 clk=~clk;
reg reset=1,blocked=0;
reg [15:0] buttons=0;
wire visible,restore,busy,captured;
wire [3:0] row,col;
wire [63:0] sticky,matrix;
pocket_keyboard #(.REPEAT_DELAY(12),.REPEAT_RATE(4),.MACRO_CYCLES(4)) dut(
 .clk(clk),.reset(reset),.blocked(blocked),.buttons(buttons),.visible(visible),
 .selected_row(row),.selected_col(col),.sticky(sticky),.matrix(matrix),.restore(restore),.macro_busy(busy),.capture(captured));
integer i,j,count;
reg [63:0] last_matrix,expected;
reg saved_transparency;
task tick;begin @(negedge clk);end endtask
task tap(input integer button);
begin buttons=16'b1<<button;tick;buttons=0;tick;end endtask
task select_key(input integer r,input integer c);
reg [7:0] target;
integer guard;
begin
 // r/c here name the stable original key IDs, not physical UI coordinates.
 target=layout_cell(r*10+c);guard=0;
 while((row<4 ? row:row==4 ? col:row-1)!=(target[7:4]<4 ? target[7:4]:target[7:4]==4 ? target[3:0]:target[7:4]-1)) begin
  tap(1);guard=guard+1;if(guard>6)$fatal(1,"vertical navigation");
 end
 guard=0;
 while({row,col}!=target)begin tap(3);guard=guard+1;if(guard>17)$fatal(1,"horizontal navigation");end
end endtask
task check_key(input integer r,input integer c,input [63:0] mask);
begin select_key(r,c);buttons=16'h10;tick;if(matrix!==mask)$fatal(1,"key %0d,%0d: %h expected%h",r,c,matrix,mask);buttons=0;tick;if(matrix!==0)$fatal(1,"key stuck");end
endtask
initial begin
 repeat(3)tick;reset=0;tick;
 if(visible || matrix!=0)$fatal(1,"reset");
 tap(7);if(!visible || row!=1 || col!=1)$fatal(1,"open/focus");
 check_key(2,0,64'h1<<62); // Q.
 check_key(3,0,64'h1<<10); // A.
 check_key(1,5,64'h1<<19); // C64 6, deliberately no PC Shift remapping.
 check_key(0,1,(64'h1<<4)|(64'h1<<15)); // F2 = Shift F1.
 check_key(6,8,(64'h1<<7)|(64'h1<<15)); // Cursor up.
 check_key(7,2,(64'h1<<0)|(64'h1<<15)); // INSERT.
 select_key(6,0);tap(4);
 if(sticky!==(64'h1<<15))$fatal(1,"sticky Shift");
 select_key(3,0);buttons=16'h10;tick;
 if(matrix!==((64'h1<<15)|(64'h1<<10)))$fatal(1,"Shift A chord");
 buttons=0;tick;tap(6);
 if(sticky!==((64'h1<<15)|(64'h1<<10)))$fatal(1,"X lock");
 buttons=16'h40;repeat(5)tick;
 if(matrix[63])$fatal(1,"X leaked STOP");
 buttons=0;tick;tap(7);if(sticky || matrix)$fatal(1,"clear locks");
 buttons=16'h300;tick;
 if(matrix!==((64'h1<<15)|(64'h1<<61)))$fatal(1,"L/R modifiers");
 buttons=0;tick;
 buttons=16'hc000;tick;
 if(matrix!==((64'h1<<1)|(64'h1<<60)))$fatal(1,"Return Space shortcuts");
 buttons=0;tick;
 select_key(6,5);buttons=16'h10;tick;if(!restore)$fatal(1,"Restore");
 blocked=1;tick;if(visible || restore || matrix || sticky)$fatal(1,"menu release");
 buttons=0;blocked=0;tick;tap(7);
 select_key(3,0);buttons=16'h18;repeat(5)tick;
 if(row!=2 || col!=2 || matrix!==(64'h1<<10))$fatal(1,"navigation moved a held key");
 buttons=0;tick;
 // Direct transparency control is a UI action, never a C64 contact.
 select_key(7,6);if(row!=5 || col!=1)$fatal(1,"transparency key geometry");
 saved_transparency=dut.transparency_toggle;
 for(j=0;j<3;j=j+1)begin
  buttons=16'h10;tick;
  if(dut.transparency_toggle===saved_transparency || matrix || restore || sticky || busy)$fatal(1,"transparency activation leaked key");
  saved_transparency=dut.transparency_toggle;
  repeat(20)tick;
  if(dut.transparency_toggle!==saved_transparency || matrix)$fatal(1,"held transparency key repeated");
  buttons=0;tick;
 end
 tap(6);if(sticky || matrix || dut.transparency_toggle!==saved_transparency)$fatal(1,"transparency X latch");
 tap(7);if(dut.transparency_toggle!==saved_transparency)$fatal(1,"Y changed transparency");
 // Every shortcut must release all contacts between characters, including Shift.
 for(j=0;j<3;j=j+1)begin
  select_key(7,j==2 ? 7:4+j);tap(4);count=0;last_matrix=0;
  while(busy)begin
   if(matrix!=0 && matrix!=last_matrix)begin
    if(j==0)case(count)
     0:expected=64'h1<<17;1:expected=64'h1<<30;2:expected=64'h1<<39;3:expected=64'h1<<1;
     default:$fatal(1,"extra RUN letter");endcase
    else if(j==1) case(count)
     0:expected=64'h1<<42;1:expected=64'h1<<33;2:expected=64'h1<<13;3:expected=64'h1<<22;4:expected=64'h1<<1;
     default:$fatal(1,"extra LIST letter");endcase
    else case(count)
     0:expected=64'h1<<42;1:expected=64'h1<<38;2:expected=64'h1<<10;3:expected=64'h1<<18;
     4,6:expected=(64'h1<<59)|(64'h1<<15);5:expected=64'h1<<49;
     7,9:expected=64'h1<<47;8:expected=64'h1<<27;10:expected=64'h1<<56;11:expected=64'h1<<1;
     default:$fatal(1,"extra LOAD letter / unwanted RUN");endcase
    if(matrix!==expected)$fatal(1,"macro order %0d %0d %h",j,count,matrix);
    count=count+1;
   end
   if(last_matrix!=0 && matrix!=0 && matrix!=last_matrix)$fatal(1,"missing macro release");
   last_matrix=matrix;tick;
  end
  if(count!=(j==0 ? 4:j==1 ? 5:12)||matrix)$fatal(1,"macro count/release");
 end
 // LOAD* clears latched modifiers, ignores held A/L/R, never retriggers on hold.
 select_key(6,0);tap(4);select_key(7,7);buttons=16'h310;tick;
 if(!busy || sticky)$fatal(1,"LOAD sticky clear");
 repeat(20)tick;
 if(matrix & ((64'h1<<15)|(64'h1<<61)))$fatal(1,"LOAD live modifier leak");
 buttons=16'h10;repeat(90)tick;
 if(busy || matrix)$fatal(1,"LOAD held button retrigger or leaked modifier");
 buttons=0;tick;
 // Cancel during a quote, and close/reset/menu blocking release its Shift too.
 for(j=0;j<3;j=j+1)begin
  select_key(7,7);tap(4);
  while(matrix!==((64'h1<<59)|(64'h1<<15)))tick;
  if(j==0)tap(5);
  else if(j==1)begin blocked=1;tick;blocked=0;tick;end
  else begin reset=1;tick;reset=0;tick;end
  if(visible || matrix || sticky || busy)$fatal(1,"LOAD cancel/reset/menu release");
  buttons=0;tick;tap(7);
 end
 select_key(6,2);tap(4);tap(5);
 if(visible || matrix || sticky)$fatal(1,"close release");
 tap(7);buttons=16'h30;tick;
 if(visible || matrix || !captured)$fatal(1,"held A close quarantine");
 buttons=16'h10;repeat(4)tick;if(!captured)$fatal(1,"released capture too soon");
 buttons=0;tick;if(captured)$fatal(1,"capture did not release");
 tap(7);i=dut.selection;buttons=16'h8;repeat(30)tick;buttons=0;tick;
 if(dut.selection==i)$fatal(1,"navigation repeat missing");
 reset=1;tick;if(visible||matrix||sticky||busy)$fatal(1,"reset release");
 $display("PASS virtual keyboard: direct transparency, navigation/repeat, C64 contacts, sticky modifiers, RUN/LIST/LOAD*, exact LOAD quote chords and Return without RUN, clean releases, held-button guard, cancel/menu/reset release");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
