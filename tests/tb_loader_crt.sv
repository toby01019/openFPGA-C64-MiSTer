`timescale 1ns/1ps
module tb;
reg clk=0,core=0;always #5 clk=~clk;always #15.859 core=~core;
reg restart=0,restart_safe=1;
reg reset=1,hold_storage=0;reg[7:0]events=0;
wire read_start,valid,run,pause,requested;wire[25:0]command;wire wdone;
reg rdone=0,rerror=0;wire[15:0]slot;wire[31:0]offset;wire[10:0]length;
wire[7:0]baddr,keys,error_code;wire[5:0]taddr,state;reg[31:0]bdata=0,tdata=0;
reg[31:0]crt_size=8272;reg present=0;reg[7:0]filedata[0:8271],buffer[0:1023],c64[0:65535];
wire pbusy,perror,attached;reg busy_meta=0,busy_sync=0,error_meta=0,error_sync=0;
always @(posedge clk)begin busy_meta<=pbusy;busy_sync<=busy_meta;error_meta<=perror;error_sync<=error_meta;end
pocket_loader #(.BOOT_CYCLES(10),.KEY_CYCLES(4),.ENABLE_CRT(1)) dut(
.clk(clk),.reset(reset),.restart(restart),.restart_safe(restart_safe),.events(events),.storage_hold(hold_storage),.storage_requested(requested),.cart_busy(busy_sync),.cart_error(error_sync),
.read_start(read_start),.read_ready(1'b1),.read_done(rdone),.read_error(rerror),.read_slot(slot),.read_offset(offset),.read_length(length),
.buffer_addr(baddr),.buffer_data(bdata),.table_addr(taddr),.table_data(tdata),.write_valid(valid),.write_data(command),.write_done(wdone),
.core_run(run),.pause_request(pause),.paused(pause),.auto_keys(keys),.error_code(error_code),.debug_state(state));
wire dv,dr;wire[25:0]dd;wire fire=dv&&dr;
pocket_mailbox mb(.src_clk(clk),.src_reset(reset),.src_valid(valid),.src_data(command),.src_done(wdone),
.dst_clk(core),.dst_reset(reset),.dst_valid(dv),.dst_data(dd),.dst_ready(dr));
wire byte_cmd=dd[25:22]==4'b1100;
wire pstart=fire&&dd[25:22]==4'b1101,pfinish=fire&&dd[25:22]==4'b1110,peject=fire&&dd[25:22]==4'b1111;
wire pready;assign dr=!byte_cmd || pready || perror || !pbusy;
wire ramstart;wire[23:0]ramaddr;wire[7:0]ramdata;reg ramready=1,ramack=0;integer ramdelay=0;
reg[7:0]cartmem[0:65535];reg[15:0]saved_addr;reg[7:0]saved_data;
pocket_crt #(.MAX_PAYLOAD_BYTES(65536),.ALLOWED_TYPES(128'b1)) parser(.clk(core),.reset(reset||peject),.load_start(pstart),.file_size({10'b0,dd[21:0]}),
.byte_valid(dv&&byte_cmd&&pbusy&&!perror),.byte_data(dd[7:0]),.byte_ready(pready),.finish(pfinish),.busy(pbusy),.attached(attached),.error(perror),.error_code(),
.cart_id(),.cart_exrom(),.cart_game(),.bank_wr(),.bank_hi(),.bank_16k(),.bank_num(),.bank_page(),
.ram_start(ramstart),.ram_ready(ramready),.ram_ack(ramack),.ram_addr(ramaddr),.ram_wdata(ramdata));
integer count_bytes=0,expected_bytes=0,starts=0,finishes=0,ejects=0,reads=0,delay_count=0,i,j;
always @(posedge core)begin
 ramack<=0;
 if(ramstart)begin
  if(!ramready)$fatal(1,"RAM busy collision");ramready<=0;ramdelay<=8+count_bytes%5;saved_addr<=ramaddr[15:0];saved_data<=ramdata;
 end else if(ramdelay>0)begin ramdelay<=ramdelay-1;if(ramdelay==1)begin cartmem[saved_addr]<=saved_data;ramack<=1;ramready<=1;end end
 if(pstart)begin expected_bytes=dd[21:0];count_bytes=0;starts=starts+1;end
 if(fire&&byte_cmd)count_bytes=count_bytes+1;
 if(pfinish)begin if(count_bytes!=expected_bytes)$fatal(1,"finish before drain %d/%d",count_bytes,expected_bytes);finishes=finishes+1;end
 if(peject)ejects=ejects+1;
 if(fire && dd[25:24]==0)begin c64[dd[23:8]]<=dd[7:0];if(run&&attached)$fatal(1,"PRG wrote while cart attached");end
end
function[7:0]filebyte(input[15:0]s,input integer p);begin
 if(s==3)filebyte=filedata[p];else if(s==1)case(p)0:filebyte=1;1:filebyte=8;default:filebyte=8'ha0+p;endcase
 else filebyte=(s+p)&255;
end endfunction
always @(posedge clk)begin
 rdone<=0;
 if(run&&busy_sync)$fatal(1,"CPU ran during CRT stream");
 bdata<={buffer[{baddr,2'b00}+3],buffer[{baddr,2'b00}+2],buffer[{baddr,2'b00}+1],buffer[{baddr,2'b00}]};
 case(taddr)
 0:tdata<=200;1:tdata<=8192;2:tdata<=201;3:tdata<=4096;4:tdata<=202;5:tdata<=8192;
 6:tdata<=1;7:tdata<=6;8:tdata<=present ? 3:0;9:tdata<=crt_size;default:tdata<=0;
 endcase
 if(read_start)begin
  if(offset+length>(slot==3?crt_size:slot==1?6:slot==201?4096:8192))$fatal(1,"file read bound");
  for(j=0;j<1024;j=j+1)buffer[j]<=filebyte(slot,offset+j);
  delay_count<=5;reads=reads+1;
 end else if(delay_count>0)begin delay_count<=delay_count-1;if(delay_count==1)rdone<=1;end
end
task event_bits(input[7:0]v);begin @(negedge clk);events=v;@(negedge clk);events=0;end endtask
task wait_idle;begin wait(state!=12);wait(state==12);repeat(4)@(negedge clk);end endtask
integer startup_mode=0,before_count,before_reads,before_ejects;reg[4095:0]path;
initial begin
 $display("CRT loader test starting");$fflush();
 if(!$value$plusargs("FILE=%s",path))$fatal;
 if(!$value$plusargs("INITIAL=%d",startup_mode))$fatal;
 $readmemh(path,filedata);present=startup_mode!=0;if(startup_mode==1)crt_size=0;
 repeat(6)@(negedge clk);reset=0;wait(state==12);$display("CRT startup reached IDLE t=%t",$time);$fflush();
 if(error_code || !run || (startup_mode==2 && !attached))$fatal(1,"optional initial CRT");
 if($test$plusargs("STARTUP_ONLY"))begin $display("PASS CRT startup initial=%d",startup_mode);$finish;end
 present=1;crt_size=8272;before_count=starts;event_bits(8);wait_idle;
 if(!attached || starts!=before_count+1 || finishes!=starts || error_code)$fatal(1,"runtime CRT");
 for(i=0;i<8192;i=i+1)if(cartmem[i]!==filedata[80+i])$fatal(1,"CRT payload %d",i);
 // Reset from a loaded cartridge: request queues while a disk is busy or
 // has unsaved data, then ejects the cartridge and clears every RAM byte.
 before_reads=reads;before_ejects=ejects;hold_storage=1;restart_safe=0;
 c64[16'h8004]=8'hc3;c64[16'ha002]=8'hc3;
 @(negedge clk);restart=1;@(negedge clk);restart=0;
 repeat(20)@(negedge clk);
 if(!attached || !run || ejects!=before_ejects)$fatal(1,"reset ignored disk ownership");
 hold_storage=0;repeat(20)@(negedge clk);
 if(!attached || !run || ejects!=before_ejects)$fatal(1,"reset ignored disk dirty/transfer guard");
 restart_safe=1;wait_idle;
 if(attached || !run || error_code || keys || ejects!=before_ejects+1 || reads!=before_reads)$fatal(1,"reset did not return without cartridge/asset reload");
 for(i=0;i<65536;i=i+1)if(c64[i]!==0)$fatal(1,"reset left RAM byte %h",i);
 // The action can be pressed again; the selected CRT metadata must not auto-boot.
 before_ejects=ejects;@(negedge clk);restart=1;@(negedge clk);restart=0;wait_idle;
 if(attached || !run || ejects!=before_ejects+1 || reads!=before_reads)$fatal(1,"repeated reset");
 // Explicitly selecting the cartridge again still works.
 event_bits(8);wait_idle;if(!attached)$fatal(1,"cartridge load after reset");
 $display("PASS Reset Core: queued disk ownership/dirty guard, CRT eject over real CDC mailbox, all 65536 RAM bytes cleared, no ROM/CRT auto-reload, repeated action, explicit CRT reload");
 // Storage8 owns the buffer: queue both events, retain state and issue no read.
 hold_storage=1;before_reads=reads;before_count=starts;before_ejects=ejects;event_bits(10);
 repeat(20)@(negedge clk);if(!requested || state!=12 || reads!=before_reads)$fatal(1,"storage ownership");
 hold_storage=0;wait(state!=12);wait(starts==before_count+1);wait(state==12);
 if(ejects!=before_ejects+1 || !attached || c64[16'h0801]!==8'ha2)$fatal(1,"mixed events PRG eject then CRT");
 filedata[0]=0;before_count=finishes;event_bits(8);wait(state==23);
 wait(state==12);repeat(4)@(negedge clk);
 if(error_code!=7 || !run || pause || attached || finishes!=before_count || count_bytes>=8272)$fatal(1,"invalid CRT must abort and return BASIC");
 for(i=0;i<65536;i=i+1)if(c64[i]!==0)$fatal(1,"rejected CRT left dirty RAM");
 filedata[0]=8'h43;event_bits(8);wait_idle;if(!attached || error_code)$fatal(1,"CRT error recovery");
 filedata[23]=127;event_bits(8);wait_idle;
 if(error_code!=7 || !run || pause || attached)$fatal(1,"unsupported module hung core");
 filedata[23]=0;event_bits(8);wait_idle;if(!attached || error_code)$fatal(1,"reload after unsupported module");
 crt_size=32'h210041;before_count=starts;before_reads=reads;event_bits(8);wait(state==23);
 wait(state==12);repeat(4)@(negedge clk);
 if(error_code!=6 || !run || pause || attached || starts!=before_count || reads!=before_reads)$fatal(1,"size bound recovery");
 crt_size=0;event_bits(8);wait_idle;if(attached || !run || error_code)$fatal(1,"empty CRT eject");
 $display("PASS CRT loader initial=%d: actual mailbox+parser, payload, Storage8 mix, PRG eject, early malformed/unsupported abort, RAM clear, automatic BASIC recovery, reload, bounds, empty eject",startup_mode);$finish;
end
initial begin #300000000;$fatal(1,"timeout loader state=%d parser=%d",state,parser.state);end
initial begin
 #100000;$display("CRT progress t=%t state=%d clear=%h parser=%d",$time,state,dut.clear_addr,parser.state);$fflush();
 #1000000;$display("CRT progress t=%t state=%d clear=%h parser=%d",$time,state,dut.clear_addr,parser.state);$fflush();
end
endmodule
