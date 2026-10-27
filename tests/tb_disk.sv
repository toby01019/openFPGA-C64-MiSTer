`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg reset=1,enable=0;
reg [7:0] events=0;
reg [6:0] head=0;
reg need=0,paused=0;
wire busy,pause_request,mounted,rom_loaded,rom_we,track_we,commit;
wire [13:0] rom_addr;wire [7:0] rom_data;
wire [9:0] track_addr;wire [63:0] track_data;
wire [6:0] loaded_track;
wire read_start;reg read_ready=1,read_done=0,read_error=0;
wire [15:0] read_slot;wire [31:0] read_offset;wire [10:0] read_length;
wire [7:0] buffer_addr;reg [31:0] buffer_data=0;
wire [5:0] table_addr;reg [31:0] table_data=0;
wire [7:0] error_code,state;wire [1:0] format;wire [15:0] track_len;
pocket_disk dut(.clk(clk),.reset(reset),.enable(enable),.events(events),.head_track(head),.need_track(need),
 .busy(busy),.pause_request(pause_request),.paused(paused),.mounted(mounted),.rom_loaded(rom_loaded),
 .rom_we(rom_we),.rom_addr(rom_addr),.rom_data(rom_data),.track_we(track_we),.track_addr(track_addr),.track_data(track_data),
 .commit_toggle(commit),.loaded_track(loaded_track),.read_start(read_start),.read_ready(read_ready),.read_done(read_done),.read_error(read_error),
 .read_slot(read_slot),.read_offset(read_offset),.read_length(read_length),.buffer_addr(buffer_addr),.buffer_data(buffer_data),
 .table_addr(table_addr),.table_data(table_data),.error_code(error_code),.debug_state(state),.format(format),.track_len(track_len));
reg [7:0] disk[0:206113],d64[0:205311];
reg [31:0] table_mem[0:63],buffer_mem[0:255];
reg [63:0] cache[0:1023];
integer countdown=0,pause_count=0,requests=0,rom_bytes=0,commits=0,clock_count=0,last_track_write=-100;
integer image_size=0,i,j,k,save_commits,fd;
reg fail_next=0,last_commit=0;
function [7:0] rom_byte(input integer n);rom_byte=(n*13+7)&255;endfunction
always @(posedge clk)begin
 clock_count=clock_count+1;
 buffer_data<=buffer_mem[buffer_addr];table_data<=table_mem[table_addr];
 read_done<=0;read_error<=0;
 if(!pause_request)begin paused<=0;pause_count<=0;end
 else if(pause_count==5)paused<=1;
 else pause_count<=pause_count+1;
 if(read_start && read_ready)begin
  if(!busy || read_length<1 || read_length>1024)$fatal(1,"invalid APF request/ownership");
  if(read_slot!=203 && read_slot!=2)$fatal(1,"unexpected slot");
  if(read_slot==2 && read_offset+read_length>image_size)$fatal(1,"read outside file: %0d+%0d > %0d",read_offset,read_length,image_size);
  if(read_slot==203 && read_offset+read_length>16384)$fatal(1,"read outside ROM");
  for(i=0;i<256;i=i+1)buffer_mem[i]=0;
  for(i=0;i<read_length;i=i+1)begin
   if(read_slot==203)buffer_mem[i/4][(i%4)*8 +:8]=rom_byte(read_offset+i);
   else buffer_mem[i/4][(i%4)*8 +:8]=disk[read_offset+i];
  end
  requests=requests+1;countdown=7;read_ready<=0;
 end else if(countdown>0)begin
  if(!busy)$fatal(1,"ownership released during outstanding read");
  countdown=countdown-1;
  if(countdown==0)begin read_done<=1;read_error<=fail_next;fail_next<=0;read_ready<=1;end
 end
 if(rom_we)begin
  if(!busy || rom_data!==rom_byte(rom_addr))$fatal(1,"ROM byte/address mismatch");
  rom_bytes=rom_bytes+1;
 end
 if(track_we)begin
  if(!busy || !pause_request || !paused)$fatal(1,"track write without pause/ownership");
  cache[track_addr]=track_data;last_track_write=clock_count;
 end
 if(reset)last_commit=0;
 else if(commit!=last_commit)begin
  if(clock_count-last_track_write<2 || !busy || !pause_request || !paused)$fatal(1,"commit too early/unpaused");
  commits=commits+1;last_commit=commit;need<=0;
 end
end
task idle_wait;
integer timeout;
begin
 timeout=0;
 while(busy || state!=0 || timeout<5)begin @(negedge clk);timeout=timeout+1;if(timeout>2000000)$fatal(1,"operation timeout state=%0d",state);end
end
endtask
task event_mount;
begin
 @(negedge clk);events=4;
 @(negedge clk);events=0;
 wait(busy);idle_wait();
end
endtask
task switch_track(input integer n);
begin
 @(negedge clk);head=n;need=1;
 wait(busy);idle_wait();
end
endtask
task word_at(input integer addr,input [31:0] value);
begin disk[addr]=value[7:0];disk[addr+1]=value[15:8];disk[addr+2]=value[23:16];disk[addr+3]=value[31:24];end
endtask
task make_g64;
begin
 for(j=0;j<15000;j=j+1)disk[j]=0;
 disk[0]="G";disk[1]="C";disk[2]="R";disk[3]="-";disk[4]="1";disk[5]="5";disk[6]="4";disk[7]="1";
 disk[8]=0;disk[9]=84;disk[10]=8'haa;disk[11]=8'h1f; // max8106
 word_at(12,689);word_at(20,6897);
 word_at(348,3);word_at(352,1);word_at(356,2); // constant speed zones accepted
 // Both track offsets are deliberately unaligned.
 disk[689]=8'h39;disk[690]=8'h18; // 6201
 for(j=0;j<6201;j=j+1)disk[691+j]=(j*31+13)&255;
 disk[6897]=8'h97;disk[6898]=8'h1b; // 7063
 for(j=0;j<7063;j=j+1)disk[6899+j]=(j*17+99)&255;
 image_size=13962;table_mem[3]=image_size;
end
endtask
task check_g64(input integer offset,input integer length);
reg [7:0] found;
begin
 if(!mounted || !rom_loaded || format!=2 || error_code || track_len!=length || loaded_track!=head)$fatal(1,"G64 mount metadata");
 for(k=0;k<length+2;k=k+1)begin
  found=cache[k/8]>>((k%8)*8);
  if(found!==disk[offset+k])$fatal(1,"G64 cache mismatch byte%0d %h %h",k,found,disk[offset+k]);
 end
 for(k=length+2;k<((length+9)/8)*8;k=k+1)
  if((8'(cache[k/8]>>((k%8)*8)))!==0)$fatal(1,"partial word not padded");
end
endtask
task expect_error(input integer code);
begin
 save_commits=commits;event_mount();
 if(error_code!=code || mounted || busy || pause_request || commits!=save_commits)
  $fatal(1,"expected error%0d got%0d mounted%0d commits%0d/%0d",code,error_code,mounted,commits,save_commits);
end
endtask
task make_d64(input integer tracks,input integer errors);
integer n,sectors;
begin
 sectors=tracks==35 ? 683:tracks==40 ? 768:802;
 n=sectors*256;
 for(j=0;j<n;j=j+1)disk[j]=d64[j];
 if(errors)for(j=n;j<n+sectors;j=j+1)disk[j]=1;
 image_size=n+(errors ? sectors:0);table_mem[3]=image_size;
end
endtask
task dump_d64;
begin
 if(!mounted || !rom_loaded || format!=1 || error_code || loaded_track!=head)$fatal(1,"D64 mount failed error=%0d",error_code);
 $fdisplay(fd,"TRACK %0d %0d",head,track_len);
 for(k=0;k<track_len+2;k=k+1)$fdisplay(fd,"%02x",8'(cache[k/8]>>((k%8)*8)));
end
endtask
initial begin
 $readmemh("disk_d64_fixture.hex",d64);
 for(j=0;j<64;j=j+1)table_mem[j]=0;
 table_mem[0]=203;table_mem[1]=16384;table_mem[2]=2;
 make_g64();
 repeat(5)@(negedge clk);reset=0;
 repeat(20)@(negedge clk);if(busy || requests)$fatal(1,"started while disabled");
 enable=1;wait(busy);enable=0; // enable gates only operation start
 idle_wait();enable=1;
 check_g64(689,6201);if(rom_bytes!=16384)$fatal(1,"ROM upload count %0d",rom_bytes);
 switch_track(2);check_g64(6897,7063);
 switch_track(1);if(track_len!=0 || cache[0]!==0 || !mounted)$fatal(1,"missing halftrack not empty");
 switch_track(2);
 disk[7000]=disk[7000]^8'hc5;event_mount();check_g64(6897,7063);
 // Replace while the second raw chunk is requested: old partial contents
 // must never commit, and the queued operation must reload from metadata.
 save_commits=commits;
 @(negedge clk);events=4;@(negedge clk);events=0;
 wait(busy);wait(read_start && read_slot==2 && read_offset>7500);
 @(negedge clk);events=4;disk[7000]=disk[7000]^8'h59;
 @(negedge clk);events=0;
 wait(commits==save_commits+1);idle_wait();
 if(commits!=save_commits+1)$fatal(1,"old slot contents committed during replacement");
 check_g64(6897,7063);
 // Exact 8-KiB cache boundary (8190 raw bytes plus the length header).
 make_g64();head=0;word_at(20,0);disk[10]=254;disk[11]=31;
 disk[689]=254;disk[690]=31;
 for(j=0;j<8190;j=j+1)disk[691+j]=(j*23+71)&255;
 image_size=8881;table_mem[3]=image_size;event_mount();check_g64(689,8190);
 make_g64();word_at(348,4);expect_error(6); // variable speed map
 make_g64();word_at(12,image_size-1);expect_error(5);
 make_g64();word_at(12,32'hffffffff);expect_error(5);
 make_g64();disk[0]=0;expect_error(3);
 make_g64();disk[9]=85;expect_error(4);
 make_g64();disk[8]=1;expect_error(4);
 make_g64();disk[10]=255;disk[11]=31;expect_error(4); // max8191 exceeds8190
 make_g64();head=0;disk[689]=8'h70;disk[690]=8'h17;expect_error(7); // 6000
 make_g64();table_mem[3]=10000;image_size=10000;head=2;expect_error(5);
 make_g64();fail_next=1;expect_error(1);
 fd=$fopen("disk_d64_tracks.hex","w");
 make_d64(42,0);head=0;event_mount();dump_d64();
 switch_track(34);dump_d64();switch_track(48);dump_d64();switch_track(60);dump_d64();switch_track(82);dump_d64();
 switch_track(35);if(track_len || cache[0]!==0)$fatal(1,"D64 halftrack");
 make_d64(35,0);head=68;event_mount();dump_d64();switch_track(70);if(track_len || cache[0]!==0)$fatal(1,"D64 beyond end");
 make_d64(40,0);head=78;event_mount();dump_d64();
 make_d64(35,1);head=0;event_mount();dump_d64();
 make_d64(40,1);event_mount();dump_d64();
 make_d64(42,1);event_mount();dump_d64();
 disk[205312+33]=2;expect_error(8);
 make_d64(42,0);table_mem[3]=205313;image_size=205313;expect_error(3);
 $fclose(fd);
 // Eject by clearing the optional slot, then missing-ROM failure on restart.
 table_mem[3]=0;event_mount();if(mounted || error_code)$fatal(1,"empty slot not unmounted");
 @(negedge clk);reset=1;repeat(3)@(negedge clk);reset=0;table_mem[1]=16383;
 wait(busy);idle_wait();if(rom_loaded || mounted || error_code!=2)$fatal(1,"bad ROM size accepted");
 table_mem[1]=16384;event_mount();
 if(!rom_loaded || mounted || error_code || rom_bytes!=32768)$fatal(1,"ROM recovery failed");
 $display("PASS disk frontend: ROM; G64 unaligned/chunked/two tracks/empty/replacement; D64 all sizes/error-table variants/density zones; bounds/magic/version/speed/errors; pause/ownership/commit spacing");
 $finish;
end
initial begin #500000000;$fatal(1,"global timeout state=%0d error=%0d",state,error_code);end
endmodule
