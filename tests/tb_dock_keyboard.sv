`timescale 1ns/1ps
module tb;
 reg h=0,c=0;always #6.734 h=~h;always #15.873 c=~c;
 reg host_reset=1,reset=1,blocked=0,valid=0;
 reg [31:0] k=0,j=0;reg [15:0] t=0;reg [1:0] mode=1;
 wire [63:0] m;wire restore,connected;
 pocket_dock_keyboard #(.TIMEOUT_CYCLES(1000)) dut(
 .host_clk(h),.host_reset(host_reset),.link_reset(reset),.report_valid(valid),
 .report_key(k),.report_joy(j),.report_trig(t),.clk(c),.reset(reset),
 .blocked(blocked),.mode(mode),.matrix(m),.restore(restore),.connected(connected));
 integer checks=0;
 task expect_keys(input [63:0] expected,input r);
 begin
  checks=checks+1;
  if(m!==expected || restore!==r)$fatal(1,"check %0d keys=%h want=%h restore=%b want=%b",checks,m,expected,restore,r);
 end endtask
 task report(input [3:0] device,input [7:0] mods,input [47:0] keys);
 begin
  @(negedge h);k={device,12'b0,mods,8'b0};j=keys[47:16];t=keys[15:0];valid=1;
  @(negedge h);valid=0;
  repeat(28)@(negedge c);
 end endtask
 initial begin
  repeat(8)@(negedge c);host_reset=0;reset=0;repeat(8)@(negedge c);
  // First held key cannot leak after core open/reset. Neutral report arms.
  report(4,0,48'h040000000000);expect_keys(0,0);
  report(4,0,0);report(4,0,48'h040000000000);expect_keys(64'h1<<10,0);
  report(4,0,48'h040000000000);expect_keys(64'h1<<10,0); // typematic is C64-side
  report(4,0,0);expect_keys(0,0);
  // Both modifier bytes checked: ordinary HID byte is APF key[15:8].
  report(4,8'h02,48'h210000000000);expect_keys((64'h1<<15)|(64'h1<<11),0); // Shift+4 = $
  @(negedge h);k=32'h40000002;j=32'h04000000;t=0;valid=1;
  @(negedge h);valid=0;repeat(28)@(negedge c);expect_keys(64'h1<<10,0); // wrong modifier byte is not Shift
  report(4,8'h20,48'h040000000000);expect_keys((64'h1<<52)|(64'h1<<10),0);
  report(4,8'h11,0);expect_keys(64'h1<<58,0);
  report(4,8'hcc,0);expect_keys(64'h1<<61,0);
  report(4,0,0);
  // Six unordered/duplicate HID slots, including both bytes of trigger.
  report(4,0,48'h04051e282c3a);
  expect_keys((64'h1<<10)|(64'h1<<28)|(64'h1<<56)|(64'h1<<1)|(64'h1<<60)|(64'h1<<4),0);
  report(4,0,48'h3a2c281e0504);
  expect_keys((64'h1<<10)|(64'h1<<28)|(64'h1<<56)|(64'h1<<1)|(64'h1<<60)|(64'h1<<4),0);
  report(4,0,48'h040404000000);expect_keys(64'h1<<10,0);
  // Arrows/even F-keys need C64 Shift chords.
  report(4,0,48'h503b00000000);expect_keys((64'h1<<15)|(64'h1<<2)|(64'h1<<4),0);
  report(4,0,48'h524100000000);expect_keys((64'h1<<15)|(64'h1<<7)|(64'h1<<3),0);
  report(4,0,48'h494a00000000);expect_keys((64'h1<<15)|(64'h1<<0)|(64'h1<<51),0);
  report(4,0,48'h4b0000000000);expect_keys(64'h1<<54,0);
  report(4,0,48'h452900000000);expect_keys(64'h1<<63,1); // STOP+RESTORE
  report(4,0,0);expect_keys(0,0);
  // Caps is a rising-edge C64 Shift Lock, not repeated inversion.
  report(4,0,48'h390400000000);expect_keys((64'h1<<15)|(64'h1<<10),0);
  report(4,0,48'h390400000000);expect_keys((64'h1<<15)|(64'h1<<10),0);
  report(4,0,0);expect_keys(64'h1<<15,0);
  report(4,0,48'h390000000000);expect_keys(0,0);report(4,0,0);
  // Error/rollover releases all and requires neutral before accepting more.
  report(4,2,48'h040102030405);expect_keys(0,0);
  report(4,0,48'h040000000000);expect_keys(0,0);
  report(4,0,0);report(4,0,48'h040000000000);expect_keys(64'h1<<10,0);
  // Joystick/mouse payload on Player3 is never interpreted as a keyboard.
  report(3,8'hff,48'h04051e282c45);expect_keys(0,0);
  report(4,0,48'h040000000000);expect_keys(0,0);report(4,0,0);
  // Menu, Off, layout changes and reset cannot replay held keys.
  blocked=1;report(4,2,48'h040000000000);expect_keys(0,0);
  blocked=0;report(4,2,48'h040000000000);expect_keys(0,0);
  report(4,0,0);report(4,0,48'h1c0000000000);expect_keys(64'h1<<25,0);
  mode=2;report(4,0,48'h1c0000000000);expect_keys(0,0);
  report(4,0,0);report(4,0,48'h1c1d00000000);expect_keys((64'h1<<12)|(64'h1<<25),0);
  report(4,0,48'h1c0000000000);expect_keys(64'h1<<12,0);
  mode=0;report(4,2,48'h040000000000);expect_keys(0,0);
  mode=1;report(4,0,48'h040000000000);expect_keys(0,0);
  report(4,0,0);report(4,0,48'h040000000000);expect_keys(64'h1<<10,0);
  reset=1;repeat(8)@(negedge c);expect_keys(0,0);reset=0;
  report(4,0,48'h040000000000);expect_keys(0,0);report(4,0,0);
  report(4,2,48'h040000000000);expect_keys((64'h1<<15)|(64'h1<<10),0);
  // Staged source changes must not become keys without a complete report.
  @(negedge h);k=32'h40000000;j=32'h45290000;t=0;
  repeat(30)@(negedge c);expect_keys((64'h1<<15)|(64'h1<<10),0);
  repeat(1000)@(negedge c);expect_keys(0,0);
  if(connected!==0)$fatal(1,"timeout retained keyboard connection");
  report(4,0,48'h040000000000);expect_keys(0,0);report(4,0,0);
  report(4,0,48'h450000000000);expect_keys(0,1);
  report(0,0,0);expect_keys(0,0);
  $display("PASS Dock keyboard: %0d async-report checks, 6 keys/order/duplicates, APF modifier byte order, C64 chords, Shift Lock, QWERTZ, rollover, device type, menu/reset/disconnect/timeout and no partial-report leakage",checks);
  $finish;
 end
 initial begin #1000000;$fatal(1,"Dock keyboard timeout");end
endmodule
