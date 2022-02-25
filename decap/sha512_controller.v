/******************************************************************* 
  Author: Bo-Yuan Peng bypeng@crypto.tw
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

module sha512_controller(
	input wire           clk,
	input wire           reset_n,
	input wire 	[2:0]	 cmd,
	input wire  [31 : 0] write_data,
	input wire  [7 : 0]  do_address,
	output wire [8 : 0] read_address,
	output wire [31 : 0] data_out,
	output wire error,
	output wire Valid

	);

	parameter ADDR_CTRL            = 8'h08;
	parameter ADDR_STATUS          = 8'h09;
	parameter MODE_SHA_512         = 2'h3;
	parameter CTRL_INIT_VALUE        = 2'h1;
	parameter CTRL_NEXT_VALUE        = 2'h2;

	parameter HASH_0_SIZE = 32'h00002180;
	parameter HASH_1_SIZE = 32'h00002180;
	parameter HASH_2_SIZE = 32'h00000208;
	parameter HASH_3_SIZE = 32'h00000600;
	parameter HASH_4_SIZE = 32'h00002438;

	parameter HASH_0_CHUNK = 4'd9;
	parameter HASH_1_CHUNK = 4'd9;
	parameter HASH_2_CHUNK = 4'd1;
	parameter HASH_3_CHUNK = 4'd2;
	parameter HASH_4_CHUNK = 4'd10;

	parameter HASH_0_PAD_IDX = 8'd13;
	parameter HASH_1_PAD_IDX = 8'd13;
	parameter HASH_2_PAD_IDX = 8'd17;
	parameter HASH_3_PAD_IDX = 8'd17;
	parameter HASH_4_PAD_IDX = 8'd2;


	parameter IDLE = 0;
	parameter WRITE_BLOCK = 1;
	parameter WRITE_CTRL = 2;
	parameter WAIT_READY = 3;




	reg [3:0] state;

	reg [7:0] ctr;
	reg [3:0] block_ctr;
	reg [31:0] INPUT_SIZE;
	reg [3:0] MAX_CHUNK;
	reg [7:0] PAD_IDX;
	reg [7:0] HASH_TYPE;
	reg [31:0] write_data_delay1;
	always @(posedge clk or negedge reset_n) begin
		if(~reset_n) begin
			INPUT_SIZE <= 0;
			MAX_CHUNK <= 0;
			PAD_IDX <= 0;
			HASH_TYPE <= 0;
		end else begin
			if(state==IDLE) begin
				case(cmd) 
					0 : begin
						INPUT_SIZE = HASH_0_SIZE;
						MAX_CHUNK = HASH_0_CHUNK;
						PAD_IDX = HASH_0_PAD_IDX;
						HASH_TYPE = 0;
					end
					1: begin
						INPUT_SIZE = HASH_1_SIZE;
						MAX_CHUNK = HASH_1_CHUNK;
						PAD_IDX = HASH_1_PAD_IDX;
						HASH_TYPE = 1;
					end
					2: begin
						INPUT_SIZE = HASH_2_SIZE;
						MAX_CHUNK = HASH_2_CHUNK;
						PAD_IDX = HASH_2_PAD_IDX;
						HASH_TYPE = 2;
					end
					3: begin
						INPUT_SIZE = HASH_3_SIZE;
						MAX_CHUNK = HASH_3_CHUNK;
						PAD_IDX = HASH_3_PAD_IDX;
						HASH_TYPE = 3;
					end
					4: begin
						INPUT_SIZE = HASH_4_SIZE;
						MAX_CHUNK = HASH_4_CHUNK;
						PAD_IDX = HASH_4_PAD_IDX;
						HASH_TYPE = 4;
					end
					default : begin
						INPUT_SIZE = INPUT_SIZE;
						MAX_CHUNK = MAX_CHUNK;
						PAD_IDX = PAD_IDX;
						HASH_TYPE = HASH_TYPE;
					end
				endcase


			end
			else begin

			end
		end
	end

	always @(posedge clk or negedge reset_n) begin : proc_write_data_delay1
		if(~reset_n) begin
			write_data_delay1 <= 0;
		end else begin
			if(state==WRITE_BLOCK&&ctr!=0)
				write_data_delay1 <= write_data;
			else
				write_data_delay1 <= write_data_delay1;
		end
	end


	wire           cs;
	wire           we;
	wire  [7 : 0]  write_address;
	wire WRITE_BLOCK_FIN;
	assign WRITE_BLOCK_FIN  = (state==WRITE_BLOCK&&ctr==32);
	assign cs = ((state==WRITE_BLOCK&&ctr!=0)||state==WRITE_CTRL||state==IDLE||state==WAIT_READY) ? 1 : 0;
	assign we = ((state==WRITE_BLOCK&&ctr!=0)||state==WRITE_CTRL) ? 1 : 0;
	assign read_address = {block_ctr[3:0],ctr[4:0]};

	assign Valid = (state==IDLE && block_ctr==MAX_CHUNK);

	always @(posedge clk or negedge reset_n) begin : proc_state
		if(~reset_n) begin
			state <= 0;
		end else begin
			case(state)
				IDLE: state <= (cmd!=5||(block_ctr!=0&&block_ctr!=MAX_CHUNK)) ? WRITE_BLOCK : IDLE;
				WRITE_BLOCK : state <= (WRITE_BLOCK_FIN) ? WRITE_CTRL : WRITE_BLOCK;
				WRITE_CTRL : state <= WAIT_READY;
				WAIT_READY : state <= (data_out!=0&&ctr>1) ? IDLE : WAIT_READY;
			endcase
		end
	end

	always @(posedge clk or negedge reset_n) begin : proc_ctr
		if(~reset_n) begin
			ctr <= 0;
		end else begin
			if(state==WRITE_BLOCK||(state==WAIT_READY))
				ctr <= ctr+1;
			else
				ctr <= 0;
		end
	end
		
	always @(posedge clk or negedge reset_n) begin : proc_block_ctr
		if(~reset_n) begin
			block_ctr <= 0;
		end else begin
			if(WRITE_BLOCK_FIN)
				block_ctr <= block_ctr+1;
			else
				block_ctr <= block_ctr;
		end
	end


	reg [31:0] dut_write_data;

	always @(*) begin : proc_dut_write_data
		if(state==WRITE_BLOCK) begin 
			if(block_ctr==0&&ctr<=1)
				dut_write_data = {HASH_TYPE,write_data[31:8]};
			else if(block_ctr!=MAX_CHUNK-1||ctr<PAD_IDX)
				dut_write_data = {write_data_delay1[7:0],write_data[31:8]};
			else if(ctr==PAD_IDX)
				dut_write_data = (HASH_TYPE==0||HASH_TYPE==1||HASH_TYPE==3) ? {32'h80000000} : (HASH_TYPE==2) ? {write_data_delay1[7:0],24'h800000} : {write_data_delay1[7:0],write_data[31:16],8'h80};
			else if(ctr==32)
				dut_write_data = INPUT_SIZE;
			else
				dut_write_data = {32'h00000000};
		end
		else begin 
			if(block_ctr==1)
				dut_write_data = {28'h0000000, MODE_SHA_512, CTRL_INIT_VALUE};
			else
				dut_write_data = {28'h0000000, MODE_SHA_512, CTRL_NEXT_VALUE};
		end
	
	end

	wire [7:0] dut_address;
	assign dut_address = (state==IDLE) ? do_address : (state==WRITE_BLOCK) ? ctr+15 : (state==WRITE_CTRL) ? ADDR_CTRL : ADDR_STATUS;

	sha512 dut(
	         .clk(clk),
	         .reset_n(reset_n),
	         .cs(cs),
	         .we(we),
	         .address(dut_address),
	         .write_data(dut_write_data),
	         .read_data(data_out),
	         .error(error)
	        );

endmodule
