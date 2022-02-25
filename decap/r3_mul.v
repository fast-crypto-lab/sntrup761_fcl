/******************************************************************* 
  Author: Bo-Yuan Peng bypeng@crypto.tw
          Ming-Han Tsai      r08943151@ntu.edu.tw
  Copyright 2021 Academia Sinica

  This file is part of sntrup761_fcl.

  The RTL is free software: you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public License
  as published by the Free Software Foundation, either version 2.1 of
  the License, or (at your option) any later version.

  The RTL is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this program.
  If not, see <https://www.gnu.org/licenses/>.
 *******************************************************************/

module r3_mul(clk,rst,in_ready,wr_en_0,wr_addr_0,wr_din_0,wr_en_1,wr_addr_1,wr_din_1,DO_addr,DO,valid);

input 			clk;
input 			rst;
input 			in_ready;
input 			wr_en_0;
input 			wr_en_1;
input  [4:0] 	wr_addr_0;
input  [4:0]	wr_addr_1;
input  [63:0] 	wr_din_0;
input  [63:0] 	wr_din_1;
input  [5:0] 	DO_addr;
output [63:0] 	DO;
output 			valid;

parameter init = 2'd0, mulstep = 2'd1, modstep = 2'd2, finish = 2'd3;
parameter Q_DEPTH = 5;
genvar i;

// state, ctr
reg  [1:0]  state;
reg  [1:0]  next_state;
reg  [5:0]  ctr;
wire [5:0]  ctr_w;
reg  [4:0]  ctr_0;
wire [4:0]  ctr_0_w;
reg  [4:0]  ctr_1;
wire [4:0]  ctr_1_w;
wire		round_end;

// bram_0, bram_1
reg  [4:0] 	rd_addr[0:1];
wire [4:0] 	rd_addr_w[0:1];
wire [63:0] rd_dout[0:3];
wire [63:0] wr_dout[0:3];
// bram_2
reg 		wr_en_2;
reg  [5:0] 	wr_addr_2;
reg  [5:0] 	rd_addr_2;
reg  [63:0]	wr_din_2;

// bram_3
wire 		wr_en_3;
wire  [4:0] 	wr_addr_3;
reg  [4:0] 	rd_addr_3;
reg  [63:0]	wr_din_3;


// r3_mul_32
wire [31:0] DI_F0;
wire [31:0] DI_F1;
wire [31:0] DI_G0;
wire [31:0] DI_G1;
reg 	    r3_mul_32_in_ready;
wire 		r3_mul_32_in_ready_w;
wire [63:0] DO_0;
wire [63:0] DO_1;
wire 		r3_mul_32_valid;

wire [31:0] add_out_0;
wire [31:0] add_out_1;

// bram
bram_p #(.Q_DEPTH(Q_DEPTH)) 
    bram_0 (.clk(clk), .wr_en(wr_en_0), .wr_addr(wr_addr_0), .rd_addr(rd_addr[0]), .wr_din(wr_din_0), .wr_dout(wr_dout[0]), .rd_dout(rd_dout[0]));
bram_p #(.Q_DEPTH(Q_DEPTH)) 
    bram_1 (.clk(clk), .wr_en(wr_en_1), .wr_addr(wr_addr_1), .rd_addr(rd_addr[1]), .wr_din(wr_din_1), .wr_dout(wr_dout[1]), .rd_dout(rd_dout[1]));
bram_p #(.Q_DEPTH(Q_DEPTH+1)) 
    bram_2 (.clk(clk), .wr_en(wr_en_2), .wr_addr(wr_addr_2), .rd_addr(rd_addr_2), .wr_din(wr_din_2), .wr_dout(wr_dout[2]), .rd_dout(rd_dout[2]));
bram_p #(.Q_DEPTH(Q_DEPTH)) 
    bram_3 (.clk(clk), .wr_en(wr_en_3), .wr_addr(wr_addr_3), .rd_addr(rd_addr_3), .wr_din(wr_din_3), .wr_dout(wr_dout[3]), .rd_dout(rd_dout[3]));

// r3_mul_32
r3_mul_32 r3_mul_32_0(
	.clk(clk),
	.rst(rst),
	.in_ready(r3_mul_32_in_ready),
	.DI_F0(DI_F0),
	.DI_F1(DI_F1),
	.DI_G0(DI_G0),
	.DI_G1(DI_G1),
	.DO_0(DO_0),
	.DO_1(DO_1),
	.valid(r3_mul_32_valid));

assign DI_F0 = {rd_dout[0][62],rd_dout[0][60],rd_dout[0][58],rd_dout[0][56],rd_dout[0][54],rd_dout[0][52],rd_dout[0][50],rd_dout[0][48],
				rd_dout[0][46],rd_dout[0][44],rd_dout[0][42],rd_dout[0][40],rd_dout[0][38],rd_dout[0][36],rd_dout[0][34],rd_dout[0][32],
				rd_dout[0][30],rd_dout[0][28],rd_dout[0][26],rd_dout[0][24],rd_dout[0][22],rd_dout[0][20],rd_dout[0][18],rd_dout[0][16],
				rd_dout[0][14],rd_dout[0][12],rd_dout[0][10],rd_dout[0][8],rd_dout[0][6],rd_dout[0][4],rd_dout[0][2],rd_dout[0][0]};
assign DI_F1 = {rd_dout[0][63],rd_dout[0][61],rd_dout[0][59],rd_dout[0][57],rd_dout[0][55],rd_dout[0][53],rd_dout[0][51],rd_dout[0][49],
				rd_dout[0][47],rd_dout[0][45],rd_dout[0][43],rd_dout[0][41],rd_dout[0][39],rd_dout[0][37],rd_dout[0][35],rd_dout[0][33],
				rd_dout[0][31],rd_dout[0][29],rd_dout[0][27],rd_dout[0][25],rd_dout[0][23],rd_dout[0][21],rd_dout[0][19],rd_dout[0][17],
				rd_dout[0][15],rd_dout[0][13],rd_dout[0][11],rd_dout[0][9],rd_dout[0][7],rd_dout[0][5],rd_dout[0][3],rd_dout[0][1]};	
assign DI_G0 = {rd_dout[1][62],rd_dout[1][60],rd_dout[1][58],rd_dout[1][56],rd_dout[1][54],rd_dout[1][52],rd_dout[1][50],rd_dout[1][48],
				rd_dout[1][46],rd_dout[1][44],rd_dout[1][42],rd_dout[1][40],rd_dout[1][38],rd_dout[1][36],rd_dout[1][34],rd_dout[1][32],
				rd_dout[1][30],rd_dout[1][28],rd_dout[1][26],rd_dout[1][24],rd_dout[1][22],rd_dout[1][20],rd_dout[1][18],rd_dout[1][16],
				rd_dout[1][14],rd_dout[1][12],rd_dout[1][10],rd_dout[1][8],rd_dout[1][6],rd_dout[1][4],rd_dout[1][2],rd_dout[1][0]};
assign DI_G1 = {rd_dout[1][63],rd_dout[1][61],rd_dout[1][59],rd_dout[1][57],rd_dout[1][55],rd_dout[1][53],rd_dout[1][51],rd_dout[1][49],
				rd_dout[1][47],rd_dout[1][45],rd_dout[1][43],rd_dout[1][41],rd_dout[1][39],rd_dout[1][37],rd_dout[1][35],rd_dout[1][33],
				rd_dout[1][31],rd_dout[1][29],rd_dout[1][27],rd_dout[1][25],rd_dout[1][23],rd_dout[1][21],rd_dout[1][19],rd_dout[1][17],
				rd_dout[1][15],rd_dout[1][13],rd_dout[1][11],rd_dout[1][9],rd_dout[1][7],rd_dout[1][5],rd_dout[1][3],rd_dout[1][1]};

assign r3_mul_32_in_ready_w = (state == mulstep && ctr == 1) ? 1 : 0;

// ctr
assign round_end = (ctr == 45) ? 1 : 0;
assign ctr_0_w = (round_end) ? (ctr_0 == 23) ? 0 : ctr_0 + 1 : ctr_0;
assign ctr_1_w = (round_end && ctr_0 == 23) ? ctr_1 + 1 : ctr_1;
assign ctr_w = (state == mulstep || state == modstep) ? (round_end) ? 0 : ctr + 1 : 0;

assign rd_addr_w[0] = ctr_0;
assign rd_addr_w[1] = ctr_1;

// rd_addr_2
always@(*)begin
	if(state == mulstep)begin
		if(ctr == 36)
			rd_addr_2 = ctr_0 + ctr_1 + 1;
		else
			rd_addr_2 = ctr_0 + ctr_1;
	end
	/*
	else if(state == finish)
		rd_addr_2 = DO_addr;
	*/
	else if(state == modstep)begin
		rd_addr_2 = ctr + 23;
	end
	else
		rd_addr_2 = rd_addr_2;
end

// wr_addr_2
always@(*)begin
	if(state == mulstep)begin
		if(ctr == 36)
			wr_addr_2 = ctr_0 + ctr_1;
		else if(ctr == 37)
			wr_addr_2 = ctr_0 + ctr_1 + 1;
		else
			wr_addr_2 = wr_addr_2;
	end
	else if(state == modstep)begin
		wr_addr_2 = ctr - 1;
	end
	else
		wr_addr_2 = wr_addr_2;
end

// bram_2 write back adder
wire [63:0] r3_mul_32_out;
wire [63:0] add_out_2;
wire [31:0] add_in_0;
wire [31:0] add_in_1;

generate
	for(i = 0; i < 32; i = i + 1)
	begin : eee
		assign r3_mul_32_out[2*i+1:2*i] = (ctr == 37) ? {DO_1[i+32],DO_0[i+32]} : {DO_1[i],DO_0[i]};
		assign add_out_2[2*i+1:2*i] = {add_out_1[i],add_out_0[i]};
		assign add_in_0[i] = rd_dout[2][2*i];
		assign add_in_1[i] = rd_dout[2][2*i+1];
	end
endgenerate


//wr_din_2
always@(*)begin
	if(state == mulstep)begin
		if(((ctr_0 == 23 || ctr_1 == 0) && ctr == 37) || (ctr_0 == 0 && ctr_1 == 0 && ctr == 36))
			wr_din_2 = r3_mul_32_out;
		else 
			wr_din_2 = add_out_2;
	end
	else
		wr_din_2 = wr_din_2;
end

//wr_en_2
always@(*)begin
	if(state == mulstep && (ctr == 36|| ctr == 37))
		wr_en_2 = 1;
	else 
		wr_en_2 = 0;
end

assign DO = rd_dout[3];
assign valid = (state == finish) ? 1 : 0;


// mod x^761 - x - 1
reg [63:0] data_reg;
wire [63:0] mod_out;
wire [63:0] mod_in;

assign mod_in = {rd_dout[2][49:0],data_reg[63:50]};			

always@(posedge clk)begin
	data_reg <= rd_dout[2];
end

// first round mod adder
generate
	for(i = 0; i < 32; i = i + 1)
	begin : aaa
		f0_adds_g0 f0_adds_g0_(
			.f0(mod_in[2*i]),
			.f1(mod_in[2*i+1]),
			.g0(wr_dout[2][2*i]),
			.g1(wr_dout[2][2*i+1]),
			.c0(mod_out[2*i]),
			.c1(mod_out[2*i+1])
			);
	end
endgenerate

wire [63:0] mod_out_1;
wire [63:0] mod_in_1;

assign mod_in_1 = (ctr == 2) ? {rd_dout[2][47:0],data_reg[63:50],2'b00} : {rd_dout[2][47:0],data_reg[63:48]};

// second round mod adder
generate
	for(i = 0; i < 32; i = i + 1)
	begin : bbb
		f0_adds_g0 f0_adds_g0_(
			.f0(mod_out[2*i]),
			.f1(mod_out[2*i+1]),
			.g0(mod_in_1[2*i]),
			.g1(mod_in_1[2*i+1]),
			.c0(mod_out_1[2*i]),
			.c1(mod_out_1[2*i+1])
			);
	end
endgenerate


assign wr_en_3 = (state==modstep) && (ctr >2 && ctr<27);
//wr_en_3
// always@(posedge clk)begin
// 	if(state == modstep && (ctr > 1 && ctr < 27))
// 		wr_en_3 = 1;
// 	else 
// 		wr_en_3 = 0;
// end

//wr_din_3
always@(posedge clk)begin
	wr_din_3 <= mod_out_1;
end


assign wr_addr_3 = (state==modstep&&ctr>2) ? ctr-3 : 0;
//wr_addr_3
// always@(posedge clk)begin
// 	if(state == modstep && ctr > 2)
// 		wr_addr_3 = wr_addr_3+1;
// 	else 
// 		wr_addr_3 = 0;
// end

//rd_addr_3
always@(*)begin
	rd_addr_3 = DO_addr;
end


generate
	for(i = 0; i < 32; i = i + 1)
	begin : fff
		f0_adds_g0 f0_adds_g0_(
			.f0(add_in_0[i]),
			.f1(add_in_1[i]),
			.g0(r3_mul_32_out[2*i]),
			.g1(r3_mul_32_out[2*i+1]),
			.c0(add_out_0[i]),
			.c1(add_out_1[i])
			);
	end
endgenerate




//state
always@(*)
begin
	case(state)
	init:
	begin
		if(in_ready == 1)
			next_state = mulstep;
		else
			next_state = init;
	end
	mulstep:
	begin
		if(ctr_0 == 23 && ctr_1 == 23 && round_end)
			next_state = modstep;
		else
			next_state = mulstep;
	end
	
	modstep:
	begin
		if(ctr == 27)
			next_state = finish;
		else 
			next_state = modstep;
	end

	finish:
	begin
		if(rst == 1)
			next_state = init;
		else
			next_state = finish;
	end
	default:
		next_state = init;
	endcase
end	

always@(posedge clk)
begin
	if(rst == 1)
	begin
		state <= init;
		ctr_0 <= 0;
		ctr_1 <= 0;
		ctr <= 0;
		rd_addr[0] <= 0;
		rd_addr[1] <= 0;
		r3_mul_32_in_ready <= 0;
	end
	else
	begin
		state <= next_state;
		ctr_0 <= ctr_0_w;
		ctr_1 <= ctr_1_w;
		ctr <= ctr_w;
		rd_addr[0] <= rd_addr_w[0];
		rd_addr[1] <= rd_addr_w[1];
		r3_mul_32_in_ready <= r3_mul_32_in_ready_w;
	end
end	

endmodule
