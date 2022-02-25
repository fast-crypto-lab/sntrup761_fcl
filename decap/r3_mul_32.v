/******************************************************************* 
  Author: Bo-Yuan Peng       bypeng@crypto.tw
          Wei-Chen Bai       go90405@yahoo.com.tw
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
module r3_mul_32(clk,rst,in_ready,DI_F0,DI_F1,DI_G0,DI_G1,DO_0,DO_1,valid);

input clk;
input rst;
input in_ready;
input [31:0] DI_F0;
input [31:0] DI_F1;
input [31:0] DI_G0;
input [31:0] DI_G1;

output [63:0] DO_0;
output [63:0] DO_1;
output valid;

/* TODO Here */

//multiplexer imput
reg [31:0] f0;
reg [31:0] f1;
reg [31:0] g0;
reg [31:0] g1;
wire [31:0] f0_w;
wire [31:0] f1_w;
wire [31:0] g0_w;
wire [31:0] g1_w;
//multiplexer output
wire [31:0] m0;
wire [31:0] m1;
//output
reg [62:0] c0;
reg [62:0] c1;
wire [62:0] c0_w;
wire [62:0] c1_w;
//counter
reg [9:0] counter;
wire [9:0] counter_w;
//state
reg [1:0] state;
reg [1:0] state_n;
//adder input/output
wire [30:0] a0_in, a1_in;
wire [30:0] a0_out, a1_out;

parameter init = 2'd0, mulstep = 2'd1, finish = 2'd2;
genvar i;

//counter
assign counter_w = (state == mulstep || state == finish) ? counter + 1 : 0;

// multiplexer input
assign f0_w = (state == init && in_ready == 1) ? DI_F0 : f0;
assign f1_w = (state == init && in_ready == 1) ? DI_F1 : f1;
assign g0_w = (state == init && in_ready == 1) ? DI_G0 : 
			  (state == mulstep) ? (g0>>1) : 
			  g0;
assign g1_w = (state == init && in_ready == 1) ? DI_G1 : 
			  (state == mulstep) ? (g1>>1) : 
			  g1;
			  
//adder input
assign a0_in = m0[30:0];
assign a1_in = m1[30:0];
			   
//c0_w			   
assign c0_w[0] = (state == init) ? 0 : (state == mulstep) ? a0_out[0] : c0[0];
assign c0_w[30:1] = (state == init) ? 0 : (state == mulstep) ? a0_out[30:1] : c0[30:1];
assign c0_w[31] = (state == init) ? 0 : (state == mulstep) ? m0[31] : c0[31];
assign c0_w[32] = (state == init) ? 0 : (state == mulstep) ? c0[33] : c0[32];
assign c0_w[62:33] = (state == init) ? 0 : (state == mulstep) ? {c0[0],c0[62:34]} : c0[62:33];
						
//c1_w
assign c1_w[0] = (state == init) ? 0 : (state == mulstep) ? a1_out[0] : c1[0];
assign c1_w[30:1] = (state == init) ? 0 : (state == mulstep) ? a1_out[30:1] : c1[30:1];
assign c1_w[31] = (state == init) ? 0 : (state == mulstep) ? m1[31] : c1[31];
assign c1_w[32] = (state == init) ? 0 : (state == mulstep) ? c1[33] : c1[32];
assign c1_w[62:33] = (state == init) ? 0 : (state == mulstep) ? {c1[0],c1[62:34]} :	c1[62:33];
						
//output			
assign DO_0 = {2'b00,c0[31:0],c0[62:32]};
assign DO_1 = {2'b00,c1[31:0],c1[62:32]};
assign valid = (state == finish) ? 1 : 0;

//state
always@(*)
begin
	case(state)
	init:
	begin
		if(in_ready == 1)
			state_n = mulstep;
		else
			state_n = init;
	end
	mulstep:
	begin
		if(counter == 10'd31)
			state_n = finish;
		else
			state_n = mulstep;
	end
	finish:
	begin
		if(counter == 10'd35)
			state_n = init;
		else
			state_n = finish;
	end
	default:
		state_n = init;
	endcase
end

//multiplexer
generate
	for(i = 0; i < 32; i = i + 1)
	begin : ccc
		f0_times_g0 f0_times_g0_(
			.f0(f0[i]),
			.f1(f1[i]),
			.g0(g0[0]),
			.g1(g1[0]),
			.c0(m0[i]),
			.c1(m1[i])
			);
	end
endgenerate	

//adder
generate
	for(i = 0; i < 31; i = i + 1)
	begin : ddd
		f0_adds_g0 f0_adds_g0_(
			.f0(a0_in[i]),
			.f1(a1_in[i]),
			.g0(c0[i+1]),
			.g1(c1[i+1]),
			.c0(a0_out[i]),
			.c1(a1_out[i])
			);
	end
endgenerate


always@(posedge clk)
begin
	if(rst == 1)
	begin
		counter <= 0;
		state <= init;
		f0 <= 0;
		f1 <= 0;
		g0 <= 0;
		g1 <= 0;
		c0 <= 0;
		c1 <= 0;
	end
	else
	begin
		counter <= counter_w;
		state <= state_n;
		f0 <= f0_w;
		f1 <= f1_w;
		g0 <= g0_w;
		g1 <= g1_w;
		c0 <= c0_w;
		c1 <= c1_w;
	end
end	

endmodule
