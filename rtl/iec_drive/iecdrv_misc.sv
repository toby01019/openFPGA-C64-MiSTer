
module iecdrv_sync #(parameter WIDTH = 1) 
(
	input                  clk,
	input      [WIDTH-1:0] in,
	output reg [WIDTH-1:0] out
);

reg [WIDTH-1:0] s1,s2;
always @(posedge clk) begin
	s1 <= in;
	s2 <= s1;
	if(s1 == s2) out <= s2;
end

endmodule

// -------------------------------------------------------------------------------

module iecdrv_mem #(parameter DATAWIDTH, ADDRWIDTH, INITFILE=" ")
(
	input	                     clock_a,
	input	     [ADDRWIDTH-1:0] address_a,
	input	     [DATAWIDTH-1:0] data_a,
	input	                     wren_a,
	output reg [DATAWIDTH-1:0] q_a,

	input	                     clock_b,
	input	     [ADDRWIDTH-1:0] address_b,
	input	     [DATAWIDTH-1:0] data_b,
	input	                     wren_b,
	output reg [DATAWIDTH-1:0] q_b
);

(* ram_init_file = INITFILE *) reg [DATAWIDTH-1:0] ram[1<<ADDRWIDTH];

reg                 wren_a_d;
reg [ADDRWIDTH-1:0] address_a_d;
always @(posedge clock_a) begin
	wren_a_d    <= wren_a;
	address_a_d <= address_a;
end

always @(posedge clock_a) begin
	if(wren_a_d) begin
		ram[address_a_d] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a_d];
	end
end

reg                 wren_b_d;
reg [ADDRWIDTH-1:0] address_b_d;
always @(posedge clock_b) begin
	wren_b_d    <= wren_b;
	address_b_d <= address_b;
end

always @(posedge clock_b) begin
	if(wren_b_d) begin
		ram[address_b_d] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b_d];
	end
end

endmodule

module iecdrv_bitmem #(parameter ADDRWIDTH)
(
	input	                     clock_a,
	input	     [ADDRWIDTH-1:0] address_a,
	input	               [7:0] data_a,
	input	                     wren_a,
	output wire          [7:0] q_a,

	input	                     clock_b,
	input	     [ADDRWIDTH+2:0] address_b,
	input	                     data_b,
	input	                     wren_b,
	output wire                q_b
);
`ifdef POCKET_ALTERA_RAM
// Cyclone V requires the explicit mixed-width dual-clock primitive for a
// byte-wide host port and bit-wide rotating head port with writes on both.
reg [ADDRWIDTH-1:0] address_a_d;
reg [ADDRWIDTH+2:0] address_b_d;
reg [7:0] data_a_d;
reg data_b_d,wren_a_d,wren_b_d;
always @(posedge clock_a) begin
 address_a_d<=address_a;data_a_d<=data_a;wren_a_d<=wren_a;
end
always @(posedge clock_b) begin
 address_b_d<=address_b;data_b_d<=data_b;wren_b_d<=wren_b;
end
altsyncram #(
 .operation_mode("BIDIR_DUAL_PORT"),.intended_device_family("Cyclone V"),.ram_block_type("M10K"),
 .width_a(8),.widthad_a(ADDRWIDTH),.numwords_a(1<<ADDRWIDTH),
 .width_b(1),.widthad_b(ADDRWIDTH+3),.numwords_b(1<<(ADDRWIDTH+3)),
 .outdata_reg_a("UNREGISTERED"),.outdata_reg_b("UNREGISTERED"),
 .address_reg_b("CLOCK1"),.indata_reg_b("CLOCK1"),.wrcontrol_wraddress_reg_b("CLOCK1"),
 .clock_enable_input_a("BYPASS"),.clock_enable_input_b("BYPASS"),
 .clock_enable_output_a("BYPASS"),.clock_enable_output_b("BYPASS"),
 .read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
 .read_during_write_mode_port_b("NEW_DATA_NO_NBE_READ"),
 .read_during_write_mode_mixed_ports("DONT_CARE"),.power_up_uninitialized("TRUE")
) track_ram(
 .clock0(clock_a),.clock1(clock_b),.clocken0(1'b1),.clocken1(1'b1),.clocken2(1'b1),.clocken3(1'b1),
 .aclr0(1'b0),.aclr1(1'b0),.addressstall_a(1'b0),.addressstall_b(1'b0),
 .address_a(address_a_d),.data_a(data_a_d),.wren_a(wren_a_d),.byteena_a(1'b1),.rden_a(1'b1),.q_a(q_a),
 .address_b(address_b_d),.data_b(data_b_d),.wren_b(wren_b_d),.byteena_b(1'b1),.rden_b(1'b1),.q_b(q_b),.eccstatus()
);
`else
reg [7:0] ram[1<<ADDRWIDTH];
reg [7:0] q_a_reg;
reg q_b_reg;
assign q_a=q_a_reg;
assign q_b=q_b_reg;

reg                 wren_a_d;
reg [ADDRWIDTH-1:0] address_a_d;
reg           [7:0] data_a_d;
always @(posedge clock_a) begin
	wren_a_d    <= wren_a;
	address_a_d <= address_a;
	data_a_d    <= data_a;
end

always @(posedge clock_a) begin
	if(wren_a_d) begin
		ram[address_a_d] <= data_a_d;
		q_a_reg <= data_a_d;
	end else begin
		q_a_reg <= ram[address_a_d];
	end
end

reg                 wren_b_d;
reg [ADDRWIDTH+2:0] address_b_d;
reg                 data_b_d;
always @(posedge clock_b) begin
	wren_b_d    <= wren_b;
	address_b_d <= address_b;
	data_b_d    <= data_b;
end

always @(posedge clock_b) begin
	if(wren_b_d) begin
		ram[address_b_d[ADDRWIDTH+2:3]][address_b_d[2:0]] <= data_b_d;
		q_b_reg <= data_b_d;
	end else begin
		q_b_reg <= ram[address_b_d[ADDRWIDTH+2:3]][address_b_d[2:0]];
	end
end
`endif
endmodule

module iecdrv_bitmem64 #(parameter ADDRWIDTH)
(
	input	                     clock_a,
	input	     [ADDRWIDTH-1:0] address_a,
	input	              [63:0] data_a,
	input	                     wren_a,
	output wire          [63:0] q_a,

	input	                     clock_b,
	input	     [ADDRWIDTH+5:0] address_b,
	input	                     data_b,
	input	                     wren_b,
	output wire                 q_b
);

wire [7:0] q_a_bytes[8];
wire q_b_bits[8];

genvar i;
generate
	for(i=0; i<8; i=i+1) begin : rams
		iecdrv_bitmem #(ADDRWIDTH) bitmem (
			.clock_a(clock_a),
			.address_a(address_a),
			.data_a(data_a[i*8 +: 8]),
			.wren_a(wren_a),
			.q_a(q_a_bytes[i]),

			.clock_b(clock_b),
			.address_b({address_b[ADDRWIDTH+5:6], address_b[2:0]}),
			.data_b(data_b),
			.wren_b(wren_b & (address_b[5:3] == i[2:0])),
			.q_b(q_b_bits[i])
		);
	end
endgenerate

assign q_a = {q_a_bytes[7], q_a_bytes[6], q_a_bytes[5], q_a_bytes[4],
              q_a_bytes[3], q_a_bytes[2], q_a_bytes[1], q_a_bytes[0]};

reg [2:0] b_sel_d, b_sel_d2;
always @(posedge clock_b) begin
	b_sel_d <= address_b[5:3];
	b_sel_d2 <= b_sel_d;
end

assign q_b = q_b_bits[b_sel_d2];

endmodule

// -------------------------------------------------------------------------------

module iecdrv_bitmemSP #(parameter ADDRWIDTH)
(
	input	                     clock_a,
	input	     [ADDRWIDTH-1:0] address_a,
	input	               [7:0] data_a,
	input	                     wren_a,
	output reg           [7:0] q_a
);

reg [7:0] ram[1<<ADDRWIDTH];

reg                 wren_a_d;
reg [ADDRWIDTH-1:0] address_a_d;
reg           [7:0] data_a_d;
always @(posedge clock_a) begin
	wren_a_d    <= wren_a;
	address_a_d <= address_a;
	data_a_d    <= data_a;
end

always @(posedge clock_a) begin
	if(wren_a_d) begin
		ram[address_a_d] <= data_a_d;
		q_a <= data_a_d;
	end else begin
		q_a <= ram[address_a_d];
	end
end

endmodule

module iecdrv_bitmem64SP #(parameter ADDRWIDTH)
(
	input	                     clock_a,
	input	     [ADDRWIDTH-1:0] address_a,
	input	              [63:0] data_a,
	input	                     wren_a,
	output wire          [63:0] q_a
);

wire [7:0] q_a_bytes[8];

genvar i;
generate
	for(i=0; i<8; i=i+1) begin : rams
		iecdrv_bitmemSP #(ADDRWIDTH) bitmem (
			.clock_a(clock_a),
			.address_a(address_a),
			.data_a(data_a[i*8 +: 8]),
			.wren_a(wren_a),
			.q_a(q_a_bytes[i])
		);
	end
endgenerate

assign q_a = {q_a_bytes[7], q_a_bytes[6], q_a_bytes[5], q_a_bytes[4],
              q_a_bytes[3], q_a_bytes[2], q_a_bytes[1], q_a_bytes[0]};

endmodule
