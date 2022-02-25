/*******************************************************************
  Integer inversion in R_4591.
 
  Author: Bo-Yuan Peng       bypeng@crypto.tw
          Wei-Chen Bai       go90405@yahoo.com.tw
          Hsuan-Chu Liu      jason841226@gmail.com
  Copyright 2021 Academia Sinica
 
  Version Info:
     Nov.17,2019: 0.1.0 Design ready.
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

`timescale 1ns / 1ps

module inverse4591(Clk, Reset, In, En, Out, Valid);

	parameter P_WIDTH = 13;
	input							Clk;
	input							Reset;
	input signed		[P_WIDTH-1 : 0]		In;
	input							En;
	output signed 		[P_WIDTH-1 : 0]		Out;
	output							Valid;

	parameter IDLE = 0;
	parameter SQUARE = 1;
	parameter MULT = 2;
	
	reg [12:0] r_4591 = 13'd4589;
	reg [1:0] state;
	reg [1:0] next_state;
	reg [3:0] ptr;
	wire [3:0] ptr_minus;
	reg [3:0] next_ptr;
	reg [3:0] cnt;
	reg [3:0] next_cnt;
	reg signed  [P_WIDTH*2-1:0] mul_mod_in;
	wire signed [P_WIDTH-1:0]   mul_mod_out;

	modmul4591S mod_0(.Clk(Clk), .Reset(Reset), .In({{28-P_WIDTH*2{mul_mod_in[P_WIDTH*2-1]}},mul_mod_in}), .Out(mul_mod_out));
	
	assign SQUARE_FIN = (state==SQUARE)&&(cnt==3);
	assign MULT_FIN = (state==MULT)&&(cnt==3);
	assign ptr_minus = ptr-1;

	assign Valid = (ptr==0)&&(state==0);

	assign Out = (Valid) ? mul_mod_out : 0;

//cnt
	always @(*) begin
		if(SQUARE_FIN||MULT_FIN)
			next_cnt = 0;
		else if(state==SQUARE||state==MULT)
			next_cnt = cnt + 1;
		else
			next_cnt = 0;
	end
	always @(posedge Clk or posedge Reset) begin
		if(Reset)
			cnt <= 0;
		else
			cnt <= next_cnt;
	end

//state
	always @(posedge Clk or posedge Reset) begin
		if(Reset)
			state <= 0;
		else
			state <= next_state;
	end
	always @(*) begin
		case(state)
			IDLE : next_state = (En) ? SQUARE : IDLE;
			SQUARE : next_state = (SQUARE_FIN && r_4591[ptr_minus]) ? MULT : SQUARE;
			MULT : next_state = (ptr==0 && MULT_FIN) ? IDLE : (MULT_FIN) ? SQUARE : MULT;
			default : next_state = state;
		endcase
	end

//ptr
	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			ptr <= 12;
		end else begin
			ptr <= next_ptr;
		end
	end

	always @(*) begin
		next_ptr = (SQUARE_FIN) ? ptr_minus : ptr;
	end

	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			mul_mod_in <= 0;
		end else begin
			if(state==IDLE)
				mul_mod_in <= mul_mod_in;
			else if(ptr==12)
				mul_mod_in <= In*In;
			else if(cnt==0)
				mul_mod_in <= mul_mod_out*((state==SQUARE) ? mul_mod_out : In);
			else
				mul_mod_in <= mul_mod_in;
		end
	end

endmodule

