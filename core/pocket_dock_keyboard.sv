// SPDX-License-Identifier: MIT
// Original C64 matrix decoder for Analogue's documented Player-3 USB report.
// No myc64-pocket implementation is used. APF key modifiers are byte-swapped;
// usages are {cont3_joy[31:0],cont3_trig[15:0]}, up to six unordered HID keys.
module pocket_dock_keyboard #(parameter TIMEOUT_CYCLES=3153000)(
 input wire host_clk,host_reset,link_reset,report_valid,
 input wire [31:0] report_key,report_joy,input wire [15:0] report_trig,
 input wire clk,reset,blocked,input wire [1:0] mode,
 output reg [63:0] matrix=0,output reg restore=0,output reg connected=0
);
 wire [67:0] report;
 wire available;
 reg busy=0;
 pocket_mailbox #(.WIDTH(68)) reports(
  .src_clk(host_clk),.src_reset(host_reset),.src_valid(report_valid),
  .src_data({report_key[31:28],report_key[15:0],report_joy,report_trig}),.src_done(),
  .dst_clk(clk),.dst_reset(link_reset),.dst_valid(available),.dst_data(report),.dst_ready(!busy));

 // Bit row*8+column is a contact in the existing C64 CIA matrix.
 function automatic [63:0] contact(input integer n);
  contact=64'h1<<n;
 endfunction
 function automatic [64:0] usage(input [7:0] code,input swap_yz);
  reg [7:0] c;
  begin
   c=code;
   if(swap_yz && code==8'h1c)c=8'h1d;
   else if(swap_yz && code==8'h1d)c=8'h1c;
   usage=0;
   case(c)
    // USB HID alphabet -> independently specified C64 contacts.
    8'h04:usage=contact(10); 8'h05:usage=contact(28); 8'h06:usage=contact(20);
    8'h07:usage=contact(18); 8'h08:usage=contact(14); 8'h09:usage=contact(21);
    8'h0a:usage=contact(26); 8'h0b:usage=contact(29); 8'h0c:usage=contact(33);
    8'h0d:usage=contact(34); 8'h0e:usage=contact(37); 8'h0f:usage=contact(42);
    8'h10:usage=contact(36); 8'h11:usage=contact(39); 8'h12:usage=contact(38);
    8'h13:usage=contact(41); 8'h14:usage=contact(62); 8'h15:usage=contact(17);
    8'h16:usage=contact(13); 8'h17:usage=contact(22); 8'h18:usage=contact(30);
    8'h19:usage=contact(31); 8'h1a:usage=contact(9); 8'h1b:usage=contact(23);
    8'h1c:usage=contact(25); 8'h1d:usage=contact(12);
    8'h1e,8'h59:usage=contact(56); 8'h1f,8'h5a:usage=contact(59);
    8'h20,8'h5b:usage=contact(8); 8'h21,8'h5c:usage=contact(11);
    8'h22,8'h5d:usage=contact(16); 8'h23,8'h5e:usage=contact(19);
    8'h24,8'h5f:usage=contact(24); 8'h25,8'h60:usage=contact(27);
    8'h26,8'h61:usage=contact(32); 8'h27,8'h62:usage=contact(35);
    8'h28,8'h58:usage=contact(1); // Return, keypad Enter
    8'h29:usage=contact(63); // Escape = RUN/STOP
    8'h2a,8'h4c:usage=contact(0); // Backspace/Delete = DEL
    8'h2b:usage=contact(58); // Tab = CTRL
    8'h2c:usage=contact(60);
    // C64 positions, not host OS text translation. See the user key table.
    8'h2d,8'h56:usage=contact(43); 8'h2e,8'h57:usage=contact(40);
    8'h2f:usage=contact(46); 8'h30,8'h55:usage=contact(49);
    8'h31,8'h32,8'h64:usage=contact(48); // pound
    8'h33:usage=contact(45); 8'h34:usage=contact(50);
    8'h35:usage=contact(57); // left arrow
    8'h36:usage=contact(47); 8'h37,8'h63:usage=contact(44);
    8'h38,8'h54:usage=contact(55);
    8'h3a:usage=contact(4); 8'h3b:usage=contact(4)|contact(15);
    8'h3c:usage=contact(5); 8'h3d:usage=contact(5)|contact(15);
    8'h3e:usage=contact(6); 8'h3f:usage=contact(6)|contact(15);
    8'h40:usage=contact(3); 8'h41:usage=contact(3)|contact(15);
    8'h45:usage[64]=1; // F12 = RESTORE (never reset/eject)
    8'h49:usage=contact(0)|contact(15); // Insert
    8'h4a:usage=contact(51); 8'h4d:usage=contact(51)|contact(15); // HOME/CLR
    8'h4b:usage=contact(54); // Page Up = C64 up-arrow character key
    8'h4f:usage=contact(2); 8'h50:usage=contact(2)|contact(15);
    8'h51:usage=contact(7); 8'h52:usage=contact(7)|contact(15);
    default:usage=0;
   endcase
  end
 endfunction
 function automatic [63:0] modifiers(input [7:0] m);
  begin
   modifiers=0;
   if(m[0] || m[4])modifiers=modifiers|contact(58); // either Ctrl
   if(m[1])modifiers=modifiers|contact(15);
   if(m[5])modifiers=modifiers|contact(52);
   if(m[2] || m[3] || m[6] || m[7])modifiers=modifiers|contact(61); // Alt/GUI = C=
  end
 endfunction

 reg [47:0] codes=0;
 reg [64:0] accumulated=0;
 reg [2:0] index=0;
 reg invalid=0,has_caps=0,caps_previous=0,caps_lock=0,armed=0;
 reg neutral=0;
 reg [1:0] previous_mode=0;
 localparam AGE_BITS=$clog2(TIMEOUT_CYCLES+1);
 reg [AGE_BITS-1:0] age=0;
 wire [64:0] decoded=usage(codes[47:40],mode==2);
 wire error_usage=codes[47:40]>=1 && codes[47:40]<=3;
 wire final_caps=has_caps || codes[47:40]==8'h39;
 wire next_lock=caps_lock ^ (final_caps && !caps_previous);

 always @(posedge clk)begin
  previous_mode<=mode;
  if(available && !busy)age<=0;
  else if(age<TIMEOUT_CYCLES)age<=age+1'b1;
  if(reset || blocked || mode==0 || mode!=previous_mode || age==TIMEOUT_CYCLES-1)begin
   matrix<=0;restore<=0;busy<=0;armed<=0;caps_lock<=0;caps_previous<=0;
   if(reset || age==TIMEOUT_CYCLES-1)connected<=0;
  end else if(available && !busy)begin
   connected<=report[67:64]==4;
   if(report[67:64]!=4)begin
    matrix<=0;restore<=0;armed<=0;caps_lock<=0;caps_previous<=0;
   end else begin
    codes<=report[47:0];index<=0;busy<=1;invalid<=0;has_caps<=0;
    accumulated<={1'b0,modifiers(report[63:56])};
    neutral<=report[63:0]==0;
   end
  end else if(busy)begin
   codes<={codes[39:0],8'b0};index<=index+1'b1;
   accumulated<=accumulated|decoded;
   invalid<=invalid|error_usage;
   has_caps<=final_caps;
   if(index==5)begin
    busy<=0;
    if(invalid || error_usage)begin
     matrix<=0;restore<=0;armed<=0;caps_lock<=0;caps_previous<=0;
    end else if(neutral)begin
     armed<=1;matrix<=caps_lock ? contact(15):0;restore<=0;caps_previous<=0;
    end else if(armed)begin
     caps_previous<=final_caps;caps_lock<=next_lock;
     matrix<=accumulated[63:0]|decoded[63:0]|(next_lock ? contact(15):64'b0);
     restore<=accumulated[64]|decoded[64];
    end else begin matrix<=0;restore<=0;end
   end
  end
 end
endmodule
