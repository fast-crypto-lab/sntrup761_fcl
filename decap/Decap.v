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

module decapsualtion(Clk, Reset, Cmd, 
					 wr_en_k, wr_addr_k, wr_di_k,
					 wr_en_r, wr_addr_r, wr_di_r,
					 wr_en_C, wr_addr_C, wr_di_C,
					 wr_en_sk, wr_addr_sk, wr_di_sk,
					 wr_en_rho, wr_addr_rho, wr_di_rho,
					 out_addr,
					 out_r, out_k, Valid);

`include "params.v"

	parameter P_WIDTH = 16;
	parameter Q_DEPTH = 10;

	parameter P_WIDTH_K = 8;
	parameter Q_DEPTH_K = 11;

	parameter WEIGHT_W = 286;

	//Cmd
	parameter start_input = 1;
	parameter start_encap = 2;
	parameter start_decap = 3;

	//state
	parameter IDLE = 0;
	parameter INPUT_DATA = 1;
	parameter DECODE_C = 2;
	parameter MULT_FC = 3;
	parameter MULT_EV = 4;
	parameter CHECK_WEIGHT = 5;
	parameter WRITE_R = 6;

	parameter DECODE_K = 7;
	parameter MULT_KR = 8;
	parameter ENCODE_C = 9;
	parameter HASH_R = 10;//ENCODE_R3
	parameter HASH_K = 11;
	parameter HASH_CONFIRM = 12;
	parameter CHECK_C = 13;
	parameter HASH_RHO = 14;
	parameter HASH_SESSION = 15;

	//substate
	parameter WRITE_HASH = 1;
	parameter COMPUTER_HASH = 2;
	parameter READ_HASH = 3;
/*==================================reg/wire declaration=======================================*/
	integer i;
	// I/O
	input Clk;
	input Reset;
	input [1:0] Cmd;
	input wr_en_k;
	input wr_en_r;
	input [Q_DEPTH_K-1:0] wr_addr_k;
	input [Q_DEPTH-1:0] wr_addr_r;
	input [P_WIDTH_K-1:0] wr_di_k;
	input [P_WIDTH-1:0] wr_di_r;//TODO

	input wr_en_C;
	input wr_en_sk;
	input [Q_DEPTH_K-1:0] wr_addr_C;
	input [Q_DEPTH_K-1:0] wr_addr_sk;
	input [P_WIDTH_K-1:0] wr_di_C;
	input [P_WIDTH_K-1:0] wr_di_sk;
	input wr_en_rho;
	input [Q_DEPTH_K-1:0] wr_addr_rho;
	input [P_WIDTH_K-1:0] wr_di_rho;

	input [2:0] out_addr;

	// input [Q_DEPTH:0] Addr_test;
	


//input
	reg [Q_DEPTH_K-1:0] rd_addr_k;
	reg [Q_DEPTH-1:0] rd_addr_r;
	reg [Q_DEPTH_K-1:0] rd_addr_C;
	reg [Q_DEPTH_K-1:0] rd_addr_sk;
	reg [Q_DEPTH_K-1:0] rd_addr_rho;
	wire [P_WIDTH_K-1:0] rd_dout_k;
	wire [P_WIDTH-1:0] rd_dout_r;
	wire [P_WIDTH_K-1:0] rd_dout_C;
	wire [P_WIDTH_K-1:0] rd_dout_sk;
	wire [P_WIDTH_K-1:0] rd_dout_rho;

	reg _wr_en_k;
	reg _wr_en_r;
	reg [Q_DEPTH_K-1:0] _wr_addr_k;
	reg [Q_DEPTH-1:0] _wr_addr_r;
	reg [P_WIDTH_K-1:0] _wr_di_k;
	reg [P_WIDTH-1:0] _wr_di_r;//TODO

	reg _wr_en_C;
	reg _wr_en_sk;
	reg [Q_DEPTH_K-1:0] _wr_addr_C;
	reg [Q_DEPTH_K-1:0] _wr_addr_sk;
	reg [P_WIDTH_K-1:0] _wr_di_C;
	reg [P_WIDTH_K-1:0] _wr_di_sk;

	reg _wr_en_rho;
	reg [Q_DEPTH_K-1:0] _wr_addr_rho;
	reg [P_WIDTH_K-1:0] _wr_di_rho;

	bram_n #(.Q_DEPTH(Q_DEPTH_K),.D_SIZE(P_WIDTH_K)) mem_k_bar (.clk(Clk), .wr_en(_wr_en_k), .wr_addr(_wr_addr_k), .rd_addr(rd_addr_k), .wr_din(_wr_di_k), .wr_dout(), .rd_dout(rd_dout_k));
	bram_n #(.Q_DEPTH(Q_DEPTH),.D_SIZE(P_WIDTH))     mem_r     (.clk(Clk), .wr_en(_wr_en_r), .wr_addr(_wr_addr_r), .rd_addr(rd_addr_r), .wr_din(_wr_di_r), .wr_dout(), .rd_dout(rd_dout_r));
	bram_n #(.Q_DEPTH(Q_DEPTH_K),.D_SIZE(P_WIDTH_K)) mem_C     (.clk(Clk), .wr_en(_wr_en_C), .wr_addr(_wr_addr_C), .rd_addr(rd_addr_C), .wr_din(_wr_di_C), .wr_dout(), .rd_dout(rd_dout_C));
	bram_n #(.Q_DEPTH(Q_DEPTH_K),.D_SIZE(P_WIDTH_K)) mem_sk    (.clk(Clk), .wr_en(_wr_en_sk), .wr_addr(_wr_addr_sk), .rd_addr(rd_addr_sk), .wr_din(_wr_di_sk), .wr_dout(), .rd_dout(rd_dout_sk));

	bram_n #(.Q_DEPTH(Q_DEPTH_K),.D_SIZE(P_WIDTH_K)) mem_rho     (.clk(Clk), .wr_en(_wr_en_rho), .wr_addr(_wr_addr_rho), .rd_addr(rd_addr_rho), .wr_din(_wr_di_rho), .wr_dout(), .rd_dout(rd_dout_rho));



//FSM
	reg [6:0] state;
	reg [6:0] next_state;

	reg [1:0] substate;
	reg [1:0] next_substate;

	reg [20:0] ctr;
	reg [20:0] next_ctr;


//decode
	wire start_dec;
    wire done_dec;

    wire [4:0] state_l_dec;
    wire [4:0] state_s_dec;
    wire [4:0] state_max_dec;
    wire [`RP_DEPTH-2:0] param_r_max_dec;
    wire [`RP_DEPTH-1:0] param_ro_max_dec;
    wire [`RP_DEPTH-2:0] param_ri_offset_dec;
    wire [`RP_DEPTH-2:0] param_ro_offset_dec;
    wire [1:0] param_outs1_dec;
    wire [1:0] param_outsl_dec;
    wire [1:0] param_outsl_first_dec;
    wire [1:0] param_r_s1_dec;
    wire [1:0] param_r_sl_dec;
    wire [`OUT_DEPTH-1:0] param_outoffset_dec;
    wire [`RP_D_SIZE-1:0] param_m0_dec;
    wire [`RP_INV_SIZE-1:0] param_m0inv_dec;
    //1531
    wire [4:0] state_max_dec1531;
    wire [`RP_DEPTH-2:0] param_r_max_dec1531;
    wire [`RP_DEPTH-1:0] param_ro_max_dec1531;
    wire [`RP_DEPTH-2:0] param_ri_offset_dec1531;
    wire [`RP_DEPTH-2:0] param_ro_offset_dec1531;
    wire [1:0] param_outs1_dec1531;
    wire [1:0] param_outsl_dec1531;
    wire [1:0] param_outsl_first_dec1531;
    wire [1:0] param_r_s1_dec1531;
    wire [1:0] param_r_sl_dec1531;
    wire [`OUT_DEPTH-1:0] param_outoffset_dec1531;
    wire [`RP_D_SIZE-1:0] param_m0_dec1531;
    wire [`RP_INV_SIZE-1:0] param_m0inv_dec1531;
    //4591
    wire [4:0] state_max_dec4591;
    wire [`RP_DEPTH-2:0] param_r_max_dec4591;
    wire [`RP_DEPTH-1:0] param_ro_max_dec4591;
    wire [`RP_DEPTH-2:0] param_ri_offset_dec4591;
    wire [`RP_DEPTH-2:0] param_ro_offset_dec4591;
    wire [1:0] param_outs1_dec4591;
    wire [1:0] param_outsl_dec4591;
    wire [1:0] param_outsl_first_dec4591;
    wire [1:0] param_r_s1_dec4591;
    wire [1:0] param_r_sl_dec4591;
    wire [`OUT_DEPTH-1:0] param_outoffset_dec4591;
    wire [`RP_D_SIZE-1:0] param_m0_dec4591;
    wire [`RP_INV_SIZE-1:0] param_m0inv_dec4591;

    wire [`OUT_DEPTH-1:0] rp_rd_addr_dec;
    wire [`OUT_D_SIZE-1:0] rp_rd_data_dec;
    wire [`RP_DEPTH-1:0] cd_wr_addr_dec;
    wire [`RP_D_SIZE-1:0] cd_wr_data_dec;
    wire [`RP_DEPTH-1:0]  cd_rd_addr_dec;
    wire [`RP_D_SIZE-1:0] cd_rd_data_dec;
    wire cd_wr_en_dec;


//mul
	wire Reset_mul;
	wire [1:0] Cmd_mul;
	wire [Q_DEPTH  :0] Addr;
	wire [P_WIDTH-1:0] Di_f;
	wire [P_WIDTH-1:0] Di_g;
	wire [P_WIDTH-1:0] Do_mul;
	wire Valid_mul;

// ntt_mul
	reg                  ntt_start;
    reg                  input_fg;
    reg                  ntt_cmd;
    wire signed [15 : 0] ntt_din;
    wire signed [15 : 0] ntt_dout;
    wire                 ntt_valid; 



//r3_mul
	wire rst_r3_mul;
    wire in_ready_r3_mul;
	wire wr_en_0_r3_mul;
	wire wr_en_1_r3_mul;
	wire [4:0] wr_addr_0_r3_mul;
	wire [4:0] wr_addr_1_r3_mul;
	wire [63:0] wr_din_0_r3_mul;
	reg [63:0] wr_din_0_r3_mul_reg;
	wire [63:0] wr_din_1_r3_mul;
	reg [63:0] wr_din_1_r3_mul_reg;
	wire [5:0] DO_addr_r3_mul;
    wire [63:0] DO_r3_mul;
    wire valid_r3_mul;

//encode
    wire start_enc;
    wire done_enc;
    wire [4:0] state_l_enc;
    wire [4:0] state_s_enc;
    wire [`OUT_DEPTH-1:0] cd_wr_addr_enc;
    wire [`OUT_D_SIZE-1:0] cd_wr_data_enc;
    wire cd_wr_en_enc;
    wire [`RP_DEPTH-1:0] rp_rd_addr_enc;
    wire [`RP_D_SIZE-1:0] rp_rd_data_enc;
    wire [4:0] state_max_enc;
    wire [`RP_DEPTH-1:0] param_r_max_enc;
    wire [`RP_D_SIZE-1:0] param_m0_enc;
    wire param_1st_round_enc;
    wire [2:0] param_outs1_enc;
    wire [2:0] param_outsl_enc;

    wire [`OUT_DEPTH-1:0] cd_rd_addr_enc;
    wire [`OUT_D_SIZE-1:0] cd_rd_data_enc;

//Hash
	wire reset_n_hash;
	wire [2:0] cmd_hash;
	wire [7:0] do_address_hash;
	wire [31:0] data_out_hash;
	wire Valid_hash;
	wire [8:0] mem_rd_addr_hash;
	wire [31:0] mem_rd_dout_hash;
	wire mem_wr_en_hash;
	wire [8:0] mem_wr_addr_hash;
	wire [31:0] mem_wr_di_hash0;
	wire [31:0] mem_wr_di_hash;
	reg [31:0] mem_wr_di_hash_reg;

	reg [31:0] hashed_r [0:7]; //hashed_r is rewritten as hashed_session after state HASH_SESSION(23)
	reg [31:0] hashed_k [0:7]; //hashed_k is rewritten as hashed_confirm after state HASH_CONFIRM(22)
	reg [31:0] hashed_rho [0:7];

//Check_weight
	 reg [9:0] weight_Lev;

//Check_C
	reg C_equal;
	wire [7:0] C_new;
	wire [7:0] C_orig;
	wire [10:0] ctr_minus_1007;
	assign ctr_minus_1007 = ctr-1007;
	wire [7:0] hashed_confirm_8bit;
	assign hashed_confirm_8bit = (ctr_minus_1007[1:0]==0) ? hashed_k[ctr_minus_1007[4:2]][31:24] : 
								 (ctr_minus_1007[1:0]==1) ? hashed_k[ctr_minus_1007[4:2]][23:16] : 
								 (ctr_minus_1007[1:0]==2) ? hashed_k[ctr_minus_1007[4:2]][15:8] : hashed_k[ctr_minus_1007[4:2]][7:0];
	assign C_new = (ctr<1007) ? cd_rd_data_enc : hashed_confirm_8bit;
	assign C_orig = rd_dout_C;

	reg mode;

	output reg [31:0] out_r;
	always @(*) begin
		out_r = hashed_r[out_addr];
	end

	output reg [31:0] out_k;
	always @(*) begin
		out_k = hashed_k[out_addr];
	end

	output Valid;

	wire READ_HASH_FIN;


//Encode: read data from independent memory instead of reading from schonhage_multiplication0
	// wire mem_wr_en_enc;
	// wire [`RP_DEPTH-1:0] mem_rd_addr_enc;
	// wire [`RP_D_SIZE-1:0] mem_rd_dout_enc;
	// wire [`RP_DEPTH-1:0] mem_wr_addr_enc;
	// wire [`RP_D_SIZE-1:0] mem_wr_di_enc;
	// assign mem_wr_en_enc = (state==ENCODE_C&&ctr>0&&ctr<=761);
	// reg [`RP_D_SIZE-1:0] Do_mul_plus2295div3;
	// always @(posedge Clk) begin
	// 	Do_mul_plus2295div3 <= Do_mul_plus2295/3; 
	// end
	// assign mem_wr_di_enc = (state==ENCODE_C) ? Do_mul_plus2295div3 : 0;
	// assign mem_wr_addr_enc = ctr-1;
	// assign mem_rd_addr_enc = rp_rd_addr_enc;
	// assign rp_rd_data_enc = mem_rd_dout_enc;





/*======================================wire logic=============================================*/
    //state finish signal
    assign DECODE_C_FIN = (state==DECODE_C) && (ctr==2500);//TODO
	assign MULT_FC_FIN = (state==MULT_FC) && (ntt_valid);
	assign MULT_EV_FIN = (state==MULT_EV) && (valid_r3_mul);
	assign CHECK_WEIGHT_FIN = (state==CHECK_WEIGHT) && (ctr==23);
	assign WRITE_R_FIN = (state==WRITE_R) && (ctr==760);

	assign DECODE_K_FIN = (state==DECODE_K) && (ctr==2500);
	assign MULT_KR_FIN = (state==MULT_KR) && (ntt_valid);
	assign ENCODE_C_FIN = (state==ENCODE_C) && (ctr==4000);
	assign HASH_R_FIN = (state==HASH_R) && (READ_HASH_FIN);
	assign HASH_K_FIN = (state==HASH_K) && (READ_HASH_FIN);
	assign HASH_CONFIRM_FIN = (state==HASH_CONFIRM) && (READ_HASH_FIN);
	assign HASH_SESSION_FIN = (state==HASH_SESSION) && (READ_HASH_FIN);
	assign WRITE_HASH_FIN = (substate==WRITE_HASH) && ((state==HASH_R&&ctr==767)||(state==HASH_K&&ctr==1159)||(state==HASH_CONFIRM&&ctr==16)||(state==HASH_SESSION&&ctr==1025)||(state==HASH_RHO&&ctr==191));
	assign COMPUTER_HASH_FIN = (substate==COMPUTER_HASH) && (Valid_hash&&(ctr>5));
	assign READ_HASH_FIN = (substate==READ_HASH) && (ctr==8);
	assign CHECK_C_FIN = (state==CHECK_C) && (ctr==1038);
	assign HASH_RHO_FIN = (state==HASH_RHO) &&(READ_HASH_FIN);

	assign Valid = (HASH_SESSION_FIN);//TODO

	//FSM
	always @(*) begin : proc_state
		case(state)
			IDLE: next_state = (Cmd==start_input) ? INPUT_DATA : IDLE;
			INPUT_DATA: next_state = (Cmd==start_decap) ? DECODE_C : (Cmd==start_encap) ? DECODE_K : INPUT_DATA;
			DECODE_C: next_state = (DECODE_C_FIN) ? MULT_FC : DECODE_C;
			MULT_FC: next_state = (MULT_FC_FIN) ? MULT_EV : MULT_FC;
			MULT_EV: next_state = (MULT_EV_FIN) ? CHECK_WEIGHT : MULT_EV;
			CHECK_WEIGHT: next_state = (CHECK_WEIGHT_FIN) ? WRITE_R : CHECK_WEIGHT;
			WRITE_R: next_state = (WRITE_R_FIN) ? DECODE_K : WRITE_R;
			DECODE_K: next_state = (DECODE_K_FIN) ? MULT_KR : DECODE_K;
			MULT_KR: next_state = (MULT_KR_FIN) ? ENCODE_C : MULT_KR;
			ENCODE_C: next_state = (ENCODE_C_FIN) ? HASH_R : ENCODE_C;
			HASH_R: next_state = (HASH_R_FIN) ? HASH_K : HASH_R;
			HASH_K : next_state = (HASH_K_FIN) ? HASH_CONFIRM : HASH_K;
			HASH_CONFIRM: next_state = (HASH_CONFIRM_FIN) ? ((mode==1)? CHECK_C : HASH_SESSION) : HASH_CONFIRM;
			CHECK_C: next_state = (CHECK_C_FIN) ? HASH_RHO : CHECK_C;
			HASH_RHO: next_state = (HASH_RHO_FIN) ? HASH_SESSION : HASH_RHO;
			HASH_SESSION: next_state = (HASH_SESSION_FIN) ? IDLE : HASH_SESSION;
		endcase
	end

	always @(*) begin : proc_substate
		case(substate)
			IDLE: next_substate = (ENCODE_C_FIN) ? WRITE_HASH : IDLE;
			WRITE_HASH : next_substate = (WRITE_HASH_FIN) ? COMPUTER_HASH : WRITE_HASH;
			COMPUTER_HASH : next_substate = (COMPUTER_HASH_FIN) ? READ_HASH : COMPUTER_HASH;
			READ_HASH : next_substate = (!READ_HASH_FIN) ? READ_HASH : (state==HASH_SESSION) ? IDLE : WRITE_HASH;
		endcase
	end

	always @(*) begin : proc_ctr
		if(DECODE_C_FIN||DECODE_K_FIN||ENCODE_C_FIN||MULT_KR_FIN||HASH_R_FIN||HASH_K_FIN||HASH_CONFIRM_FIN||HASH_SESSION_FIN||WRITE_HASH_FIN||COMPUTER_HASH_FIN||READ_HASH_FIN||MULT_FC_FIN||MULT_EV_FIN||CHECK_WEIGHT_FIN||WRITE_R_FIN||CHECK_C_FIN||HASH_RHO_FIN)
			next_ctr = 0;
		else if(state==DECODE_C||state==DECODE_K||state==ENCODE_C||state==HASH_R||state==HASH_K||state==HASH_CONFIRM||state==HASH_SESSION||state==MULT_EV||state==CHECK_WEIGHT||state==WRITE_R||state==CHECK_C||state==HASH_RHO)
			next_ctr = ctr+1;
		else if (state==MULT_KR || state==MULT_FC) begin
			if (input_fg ==0 && ctr == 1535) begin
				next_ctr = 0;
			end else begin
				next_ctr = ctr+1;
			end
		end
		else
			next_ctr = 0;
	end


	//INPUT
	always @(*) begin
		if(state==INPUT_DATA) begin
			_wr_en_k = wr_en_k;
			_wr_en_r = wr_en_r;
			_wr_en_C = wr_en_C;
			_wr_en_sk = wr_en_sk;
			_wr_en_rho = wr_en_rho;
			_wr_addr_k = wr_addr_k;
			_wr_addr_r = wr_addr_r;
			_wr_addr_C = wr_addr_C;
			_wr_addr_sk = wr_addr_sk;
			_wr_addr_rho = wr_addr_rho;
			_wr_di_k = wr_di_k;
			_wr_di_r = wr_di_r;
			_wr_di_C = wr_di_C;
			_wr_di_sk = wr_di_sk;
			_wr_di_rho = wr_di_rho;
		end else if(state==WRITE_R) begin
			_wr_en_k = 0;
			_wr_en_r = 1;
			_wr_en_C = 0;
			_wr_en_sk = 0;
			_wr_en_rho = 0;
			_wr_addr_k = 0;
			_wr_addr_r = ctr;
			_wr_addr_C = 0;
			_wr_addr_sk = 0;
			_wr_addr_rho = 0;
			_wr_di_k = 0;
			//_wr_di_r = {{14{DO_r3_mul[(2*ctr[4:0]+1)]}},DO_r3_mul[(2*ctr[4:0]+1):(2*ctr[4:0])]};
			if(weight_Lev!=WEIGHT_W) begin 
				_wr_di_r = (ctr<WEIGHT_W) ? 1 : 0;
			end else begin
				case(ctr[4:0])
					 0: _wr_di_r = {{14{DO_r3_mul[ 1]}},DO_r3_mul[ 1: 0]};
					 1: _wr_di_r = {{14{DO_r3_mul[ 3]}},DO_r3_mul[ 3: 2]};
					 2: _wr_di_r = {{14{DO_r3_mul[ 5]}},DO_r3_mul[ 5: 4]};
					 3: _wr_di_r = {{14{DO_r3_mul[ 7]}},DO_r3_mul[ 7: 6]};
					 4: _wr_di_r = {{14{DO_r3_mul[ 9]}},DO_r3_mul[ 9: 8]};
					 5: _wr_di_r = {{14{DO_r3_mul[11]}},DO_r3_mul[11:10]};
					 6: _wr_di_r = {{14{DO_r3_mul[13]}},DO_r3_mul[13:12]};
					 7: _wr_di_r = {{14{DO_r3_mul[15]}},DO_r3_mul[15:14]};
					 8: _wr_di_r = {{14{DO_r3_mul[17]}},DO_r3_mul[17:16]};
					 9: _wr_di_r = {{14{DO_r3_mul[19]}},DO_r3_mul[19:18]};
					10: _wr_di_r = {{14{DO_r3_mul[21]}},DO_r3_mul[21:20]};
					11: _wr_di_r = {{14{DO_r3_mul[23]}},DO_r3_mul[23:22]};
					12: _wr_di_r = {{14{DO_r3_mul[25]}},DO_r3_mul[25:24]};
					13: _wr_di_r = {{14{DO_r3_mul[27]}},DO_r3_mul[27:26]};
					14: _wr_di_r = {{14{DO_r3_mul[29]}},DO_r3_mul[29:28]};
					15: _wr_di_r = {{14{DO_r3_mul[31]}},DO_r3_mul[31:30]};
					16: _wr_di_r = {{14{DO_r3_mul[33]}},DO_r3_mul[33:32]};
					17: _wr_di_r = {{14{DO_r3_mul[35]}},DO_r3_mul[35:34]};
					18: _wr_di_r = {{14{DO_r3_mul[37]}},DO_r3_mul[37:36]};
					19: _wr_di_r = {{14{DO_r3_mul[39]}},DO_r3_mul[39:38]};
					20: _wr_di_r = {{14{DO_r3_mul[41]}},DO_r3_mul[41:40]};
					21: _wr_di_r = {{14{DO_r3_mul[43]}},DO_r3_mul[43:42]};
					22: _wr_di_r = {{14{DO_r3_mul[45]}},DO_r3_mul[45:44]};
					23: _wr_di_r = {{14{DO_r3_mul[47]}},DO_r3_mul[47:46]};
					24: _wr_di_r = {{14{DO_r3_mul[49]}},DO_r3_mul[49:48]};
					25: _wr_di_r = {{14{DO_r3_mul[51]}},DO_r3_mul[51:50]};
					26: _wr_di_r = {{14{DO_r3_mul[53]}},DO_r3_mul[53:52]};
					27: _wr_di_r = {{14{DO_r3_mul[55]}},DO_r3_mul[55:54]};
					28: _wr_di_r = {{14{DO_r3_mul[57]}},DO_r3_mul[57:56]};
					29: _wr_di_r = {{14{DO_r3_mul[59]}},DO_r3_mul[59:58]};
					30: _wr_di_r = {{14{DO_r3_mul[61]}},DO_r3_mul[61:60]};
					31: _wr_di_r = {{14{DO_r3_mul[63]}},DO_r3_mul[63:62]};
					default: _wr_di_r = {{14{DO_r3_mul[1]}},DO_r3_mul[1:0]};
				endcase
			end
			_wr_di_C = 0;
			_wr_di_sk = 0;
			_wr_di_rho = 0;
		end else begin
			_wr_en_k = 0;
			_wr_en_r = 0;
			_wr_en_C = 0;
			_wr_en_sk = 0;
			_wr_en_rho = 0;
			_wr_addr_k = 0;
			_wr_addr_r = 0;
			_wr_addr_C = 0;
			_wr_addr_sk = 0;
			_wr_addr_rho = 0;
			_wr_di_k = 0;
			_wr_di_r = 0;
			_wr_di_C = 0;
			_wr_di_sk = 0;
			_wr_di_rho = 0;
		end
	end
	



	//decode_c/decode_k
	always @(*) begin
		rd_addr_C = (state==DECODE_C) ? rp_rd_addr_dec : (state==CHECK_C) ? ctr : 0;
		rd_addr_k = (state==DECODE_K) ? rp_rd_addr_dec : (state==HASH_K) ? ctr : 0;
	end
	assign rp_rd_data_dec = (state==DECODE_K) ? rd_dout_k : (state==DECODE_C) ? rd_dout_C : 0;
	assign start_dec = (state==DECODE_K && ctr<30) || (state==DECODE_C && ctr<30); //TODO

	//mul
	//TODO: MULT_KR***
	assign cd_rd_addr_dec = (state==MULT_FC||state==MULT_KR) ? ctr : 0;
	always @(*) begin
		rd_addr_sk = (state==MULT_FC) ? ((ctr)>>2) : (state==MULT_EV) ? ((ctr>>2)+191) : 0;
		rd_addr_r = (state==MULT_KR) ? ctr : (state==HASH_R) ? ((ctr<=760) ? ctr : 760) : 0;
	end
	wire [1:0] rd_dout_sk_2bit;
	assign rd_dout_sk_2bit = (ctr[1:0]==0) ? rd_dout_sk[1:0] : (ctr[1:0]==1) ? rd_dout_sk[3:2] : (ctr[1:0]==2) ? rd_dout_sk[5:4] : rd_dout_sk[7:6];
	wire [1:0] rd_dout_sk_2bit_minus1;
	assign rd_dout_sk_2bit_minus1 = rd_dout_sk_2bit-1;

	assign Addr = (state==ENCODE_C) ? rp_rd_addr_enc : (ctr<=1535) ? ctr : 1535;
	wire [15:0] cd_rd_data_dec_minus2295;
	assign cd_rd_data_dec_minus2295=cd_rd_data_dec-2295;
	wire [15:0] cd_rd_data_dec_mul3minus2295;
	assign cd_rd_data_dec_mul3minus2295 = cd_rd_data_dec*3-2295;
	assign Di_f = (state==MULT_KR/*&&ctr<=760*/) ? cd_rd_data_dec_minus2295 :(state==MULT_FC/*&&ctr<=760*/) ? cd_rd_data_dec_mul3minus2295 : 0;
	assign Di_g = (state==MULT_KR/*&&ctr<=760*/) ? rd_dout_r : (state==MULT_FC/*&&ctr<=760*/) ? ((rd_dout_sk_2bit==0) ? -3/*16'd4588*/ : (rd_dout_sk_2bit==1) ? 16'd0 : 16'd3) : 0;
	assign Cmd_mul = (((state==MULT_FC||state==MULT_KR)&&ctr<1024)||DECODE_C_FIN||DECODE_K_FIN) ? 1 : (state==MULT_KR&&ctr==1026) ? 2 : (state==MULT_FC&&ctr==1026) ? 3 : 0;//TODO
	assign Reset_mul = Reset || state==CHECK_WEIGHT;//TODO

	//r3_mul
	assign rst_r3_mul = Reset;
	assign in_ready_r3_mul = (state==MULT_EV&&ctr==769);//TODO
	assign wr_en_0_r3_mul = (state==MULT_EV&&ctr<768);
	assign wr_en_1_r3_mul = (state==MULT_EV&&ctr<768);
	assign wr_addr_0_r3_mul = (state==MULT_EV) ? ctr>>5 : 0;
	assign wr_addr_1_r3_mul = (state==MULT_EV) ? ctr>>5 : 0;
	assign wr_din_0_r3_mul = (state==MULT_EV) ? {((ctr<761) ? (Do_mul[1:0]) : 2'b00),wr_din_0_r3_mul_reg[63:2]} : 0;
	assign wr_din_1_r3_mul = (state==MULT_EV) ? {((ctr<761) ? (rd_dout_sk_2bit_minus1) : 2'b00),wr_din_1_r3_mul_reg[63:2]} : 0;
	assign DO_addr_r3_mul = (state==CHECK_WEIGHT&&ctr<23) ? (ctr+1) : (state==WRITE_R) ? (ctr+1)>>5 : 0;


	//check_weight
	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			weight_Lev = 0;
		end else begin
			if(state==CHECK_WEIGHT)
				weight_Lev = (ctr!=23) ?
							 DO_r3_mul[ 0] + DO_r3_mul[ 2] + DO_r3_mul[ 4] + DO_r3_mul[ 6] + DO_r3_mul[ 8] + DO_r3_mul[10] + DO_r3_mul[12] + DO_r3_mul[14]
						   + DO_r3_mul[16] + DO_r3_mul[18] + DO_r3_mul[20] + DO_r3_mul[22] + DO_r3_mul[24] + DO_r3_mul[26] + DO_r3_mul[28] + DO_r3_mul[30]
						   + DO_r3_mul[32] + DO_r3_mul[34] + DO_r3_mul[36] + DO_r3_mul[38] + DO_r3_mul[40] + DO_r3_mul[42] + DO_r3_mul[44] + DO_r3_mul[46]
						   + DO_r3_mul[48] + DO_r3_mul[50] + DO_r3_mul[52] + DO_r3_mul[54] + DO_r3_mul[56] + DO_r3_mul[58] + DO_r3_mul[60] + DO_r3_mul[62]
						   + weight_Lev :
						     DO_r3_mul[ 0] + DO_r3_mul[ 2] + DO_r3_mul[ 4] + DO_r3_mul[ 6] + DO_r3_mul[ 8] + DO_r3_mul[10] + DO_r3_mul[12] + DO_r3_mul[14]
						   + DO_r3_mul[16] + DO_r3_mul[18] + DO_r3_mul[20] + DO_r3_mul[22] + DO_r3_mul[24] + DO_r3_mul[26] + DO_r3_mul[28] + DO_r3_mul[30]
						   + DO_r3_mul[32] + DO_r3_mul[34] + DO_r3_mul[36] + DO_r3_mul[38] + DO_r3_mul[40] + DO_r3_mul[42] + DO_r3_mul[44] + DO_r3_mul[46]
						   + DO_r3_mul[48]
						   + weight_Lev;
			else
				weight_Lev = weight_Lev;
		end
	end
	//encode
	wire signed [13:0] Do_mul_plus2295;
	assign Do_mul_plus2295 = Do_mul+2295;
	assign rp_rd_data_enc = Do_mul;
	assign start_enc = (state==ENCODE_C && ctr>762 && ctr<790);//TODO

	//Hash
	always @(*) begin
		rd_addr_rho = (state==HASH_RHO) ? ctr : 0;
	end
	assign cd_rd_addr_enc = (state==HASH_SESSION&&ctr>=8) ? ctr-8 : (state==CHECK_C) ? ctr : 0;
	assign reset_n_hash = !(Reset || ENCODE_C_FIN || HASH_R_FIN || HASH_K_FIN || HASH_CONFIRM_FIN || HASH_SESSION_FIN ||HASH_RHO_FIN);
	assign cmd_hash = (ctr>10||substate!=COMPUTER_HASH) ? 5 : (state==HASH_R||state==HASH_RHO) ? 3 : (state==HASH_K) ? 4 : (state==HASH_CONFIRM) ? 2 : (state==HASH_SESSION) ? C_equal : 5;

	assign mem_wr_en_hash = (substate==WRITE_HASH);
	assign mem_wr_addr_hash = (state==HASH_R) ? {ctr[12:4]} : 
							  (state==HASH_K) ? {ctr[10:2]} :
							  (state==HASH_RHO) ? {ctr[10:2]} :
							  (state==HASH_CONFIRM) ? ctr :
							  (state==HASH_SESSION) ? ((ctr<8) ? ctr : (ctr<1015) ? ctr[10:2]+6 : ctr-756) : 0;
	wire [1:0] rd_dout_r_1_0_plus1;
	assign rd_dout_r_1_0_plus1 = rd_dout_r[1:0]+1;
	assign mem_wr_di_hash0 = (state==HASH_R) ? {mem_wr_di_hash_reg[29:0],((ctr<761) ? rd_dout_r_1_0_plus1 : 2'b00)} :
							 (state==HASH_K) ? {mem_wr_di_hash_reg[23:0],rd_dout_k[7:0]} :
							 (state==HASH_RHO) ? {mem_wr_di_hash_reg[23:0],rd_dout_rho[7:0]} :
							 (state==HASH_CONFIRM) ? ((ctr<8) ? hashed_r[ctr[2:0]] : hashed_k[ctr[2:0]]) :
							 (state==HASH_SESSION) ? ((ctr<8) ? (C_equal ? hashed_r[ctr[3:0]] : hashed_rho[ctr[3:0]]) : 
													 (ctr<1015) ? {mem_wr_di_hash_reg[23:0],cd_rd_data_enc[7:0]} : 
													 (ctr==1015) ? {mem_wr_di_hash_reg[23:0],hashed_k[0][31:24]} : 
													 {hashed_k[ctr-1016][23:0],hashed_k[ctr-1015][31:24]}) 
							 : 0;//TODO
	assign mem_wr_di_hash = (state==HASH_R) ? {mem_wr_di_hash0[25:24],mem_wr_di_hash0[27:26],mem_wr_di_hash0[29:28],mem_wr_di_hash0[31:30],
											   mem_wr_di_hash0[17:16],mem_wr_di_hash0[19:18],mem_wr_di_hash0[21:20],mem_wr_di_hash0[23:22],
											   mem_wr_di_hash0[ 9: 8],mem_wr_di_hash0[11:10],mem_wr_di_hash0[13:12],mem_wr_di_hash0[15:14],
											   mem_wr_di_hash0[ 1: 0],mem_wr_di_hash0[ 3: 2],mem_wr_di_hash0[ 5: 4],mem_wr_di_hash0[ 7: 6]}
											: mem_wr_di_hash0;

	assign do_address_hash = (substate==READ_HASH) ? ctr+'h40 : 'h40;







/*=======================================reg logic=============================================*/


	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			state <= 0;
			substate <=0;
			ctr <= 0;
		end else begin
			state <= next_state;
			substate <= next_substate;
			ctr <= next_ctr;
		end
	end

	//r3_mul
	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			wr_din_0_r3_mul_reg <= 0;
			wr_din_1_r3_mul_reg <= 0;
		end else begin
			if(state==MULT_EV) begin
				wr_din_0_r3_mul_reg <= wr_din_0_r3_mul;
				wr_din_1_r3_mul_reg <= wr_din_1_r3_mul;
			end else begin
				wr_din_0_r3_mul_reg <= 0;
				wr_din_1_r3_mul_reg <= 0;
			end
		end
	end

	//hash
	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			mem_wr_di_hash_reg <= 0;
		end else begin
			if(state==HASH_R||state==HASH_K||state==HASH_SESSION||state==HASH_RHO)
				mem_wr_di_hash_reg <= mem_wr_di_hash0;
			else 
				mem_wr_di_hash_reg <= 0;
		end
	end

	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			for(i=0;i<8;i=i+1) begin
				hashed_r[i] <= 0;
			end
		end else begin
			if((state==HASH_R||state==HASH_SESSION)&&substate==READ_HASH)
				for(i=0;i<8;i=i+1) begin
					if(i==ctr)
						hashed_r[i] <= data_out_hash;
					else
						hashed_r[i] <= hashed_r[i];
				end
			else 
				for(i=0;i<8;i=i+1) begin
					hashed_r[i] <= hashed_r[i];
				end
		end
	end

	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			for(i=0;i<8;i=i+1) begin
				hashed_k[i] <= 0;
			end
		end else begin
			if((state==HASH_K||state==HASH_CONFIRM)&&substate==READ_HASH)
				for(i=0;i<8;i=i+1) begin
					if(i==ctr)
						hashed_k[i] <= data_out_hash;
					else
						hashed_k[i] <= hashed_k[i];
				end
			else 
				for(i=0;i<8;i=i+1) begin
					hashed_k[i] <= hashed_k[i];
				end
		end
	end

	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			for(i=0;i<8;i=i+1) begin
				hashed_rho[i] <= 0;
			end
		end else begin
			if((state==HASH_RHO)&&substate==READ_HASH)
				for(i=0;i<8;i=i+1) begin
					if(i==ctr)
						hashed_rho[i] <= data_out_hash;
					else
						hashed_rho[i] <= hashed_rho[i];
				end
			else 
				for(i=0;i<8;i=i+1) begin
					hashed_rho[i] <= hashed_rho[i];
				end
		end
	end


	//c_equal
	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			C_equal <= 1;
		end else begin
			if(state==CHECK_C)
				C_equal <= (C_new!=C_orig) ? 0 : C_equal;
			else
				C_equal <= C_equal;
		end
	end

	always @(posedge Clk or posedge Reset) begin
		if(Reset) begin
			mode <= 0;
		end else begin
			mode <= (Cmd==start_decap) ? 1 : (Cmd==start_encap) ? 0 : mode;
		end
	end






/*========================================modules==============================================*/
	//mem_dec store c after state DECODE_C
	//mem_dec store k after state DECODE_K (c won't be used after state DECODE_K)
    bram_n # ( .D_SIZE(`RP_D_SIZE), .Q_DEPTH(`RP_DEPTH) ) mem_dec (
        .clk(Clk),
        .wr_en(cd_wr_en_dec),
        .wr_addr(cd_wr_addr_dec),
        .wr_din(cd_wr_data_dec),
        .rd_addr(cd_rd_addr_dec),
        .rd_dout(cd_rd_data_dec)
    ) ;

    bram_n # ( .D_SIZE(`OUT_D_SIZE), .Q_DEPTH(`OUT_DEPTH) ) mem_enc (
        .clk(Clk),
        .wr_en(cd_wr_en_enc),
        .wr_addr(cd_wr_addr_enc),
        .wr_din(cd_wr_data_enc),
        .rd_addr(cd_rd_addr_enc),
        .rd_dout(cd_rd_data_enc)
    ) ;

    bram_p # ( .D_SIZE(32), .Q_DEPTH(9) ) mem_hash_in (
        .clk(Clk),
        .wr_en(mem_wr_en_hash),
        .wr_addr(mem_wr_addr_hash),
        .wr_din(mem_wr_di_hash),
        .rd_addr(mem_rd_addr_hash),
        .rd_dout(mem_rd_dout_hash)
    ) ;

    // bram_n # ( .D_SIZE(`RP_D_SIZE), .Q_DEPTH(`RP_DEPTH) ) mem_enc_in (
    //     .clk(Clk),
    //     .wr_en(mem_wr_en_enc),
    //     .wr_addr(mem_wr_addr_enc),
    //     .wr_din(mem_wr_di_enc),
    //     .rd_addr(mem_rd_addr_enc),
    //     .rd_dout(mem_rd_dout_enc)
    // ) ;



	decode_rp decoder0 (
        .clk(Clk),
        .start(start_dec),
        .done(done_dec),
        .state_l(state_l_dec),
        .state_s(state_s_dec),
        .rp_rd_addr(rp_rd_addr_dec),
        .rp_rd_data(rp_rd_data_dec),
        .cd_wr_addr(cd_wr_addr_dec),
        .cd_wr_data(cd_wr_data_dec),
        .cd_wr_en(cd_wr_en_dec),
        .state_max(state_max_dec),
        .param_r_max(param_r_max_dec),
        .param_ro_max(param_ro_max_dec),
        .param_ri_offset(param_ri_offset_dec),
        .param_ro_offset(param_ro_offset_dec),
        .param_m0(param_m0_dec),
        .param_m0inv(param_m0inv_dec),
        .param_outs1(param_outs1_dec),
        .param_outsl(param_outsl_dec),
        .param_outsl_first(param_outsl_first_dec),
        .param_r_s1(param_r_s1_dec),
        .param_r_sl(param_r_sl_dec),
        .param_outoffset(param_outoffset_dec)
    ) ;

    assign state_max_dec 		= (state==DECODE_C) ? state_max_dec1531 		: state_max_dec4591;
    assign param_r_max_dec 		= (state==DECODE_C) ? param_r_max_dec1531 		: param_r_max_dec4591;
    assign param_ro_max_dec 	= (state==DECODE_C) ? param_ro_max_dec1531 		: param_ro_max_dec4591;
    assign param_ri_offset_dec 	= (state==DECODE_C) ? param_ri_offset_dec1531 	: param_ri_offset_dec4591;
    assign param_ro_offset_dec 	= (state==DECODE_C) ? param_ro_offset_dec1531 	: param_ro_offset_dec4591;
    assign param_outs1_dec 		= (state==DECODE_C) ? param_outs1_dec1531 		: param_outs1_dec4591;
    assign param_outsl_dec 		= (state==DECODE_C) ? param_outsl_dec1531 		: param_outsl_dec4591;
    assign param_r_s1_dec 		= (state==DECODE_C) ? param_r_s1_dec1531 		: param_r_s1_dec4591;
    assign param_r_sl_dec 		= (state==DECODE_C) ? param_r_sl_dec1531 		: param_r_sl_dec4591;
    assign param_outoffset_dec 	= (state==DECODE_C) ? param_outoffset_dec1531 	: param_outoffset_dec4591;
    assign param_m0_dec 		= (state==DECODE_C) ? param_m0_dec1531 			: param_m0_dec4591;
    assign param_m0inv_dec 		= (state==DECODE_C) ? param_m0inv_dec1531 		: param_m0inv_dec4591;
    assign param_outsl_first_dec= (state==DECODE_C) ? param_outsl_first_dec1531 : param_outsl_first_dec4591; 

    rp761q4591decode_param param0_dec4591 (
        .state_l(state_l_dec),
        .state_s(state_s_dec),
        .state_max(state_max_dec4591),
        .param_r_max(param_r_max_dec4591),
        .param_ro_max(param_ro_max_dec4591),
        .param_ri_offset(param_ri_offset_dec4591),
        .param_ro_offset(param_ro_offset_dec4591),
        .param_m0(param_m0_dec4591),
        .param_m0inv(param_m0inv_dec4591),
        .param_outs1(param_outs1_dec4591),
        .param_outsl(param_outsl_dec4591),
        .param_outsl_first(param_outsl_first_dec4591),
        .param_r_s1(param_r_s1_dec4591),
        .param_r_sl(param_r_sl_dec4591),
        .param_outoffset(param_outoffset_dec4591)
    ) ;

    rp761q1531decode_param param0_dec1531 (
        .state_l(state_l_dec),
        .state_s(state_s_dec),
        .state_max(state_max_dec1531),
        .param_r_max(param_r_max_dec1531),
        .param_ro_max(param_ro_max_dec1531),
        .param_ri_offset(param_ri_offset_dec1531),
        .param_ro_offset(param_ro_offset_dec1531),
        .param_m0(param_m0_dec1531),
        .param_m0inv(param_m0inv_dec1531),
        .param_outs1(param_outs1_dec1531),
        .param_outsl(param_outsl_dec1531),
        .param_outsl_first(param_outsl_first_dec1531),
        .param_r_s1(param_r_s1_dec1531),
        .param_r_sl(param_r_sl_dec1531),
        .param_outoffset(param_outoffset_dec1531)
    ) ;

	ntt ntt_mul(
		.clk(Clk), 
		.rst(Reset_mul), 
		.start(ntt_start), 
		.input_fg(input_fg), 
		.cmd(ntt_cmd), 
		.addr(Addr), 
		.din(ntt_din), 
		.dout(Do_mul), 
		.valid(ntt_valid)
		);


	assign ntt_din = (Addr > 760) ? 0 : (input_fg) ? $signed(Di_g) : $signed(Di_f);

	always @(posedge Clk ) begin
		if (state == MULT_FC) begin
			ntt_cmd <= 1;  // mod3
		end else begin
			ntt_cmd <= 0;  // round3
		end
	end

	always @(posedge Clk ) begin
		if (input_fg == 1 && ctr == 1540) begin
			ntt_start <= 1;
		end else begin
			ntt_start <= 0;
		end
	end

	always @(posedge Clk ) begin
		if (state == MULT_FC || state == MULT_KR) begin
			if (ctr == 1535 && input_fg == 0) begin
				input_fg <= input_fg + 1;
			end else if (ntt_start) begin
				input_fg <= 0;
			end else begin
				input_fg <= input_fg;
			end
		end else begin
			input_fg <= 0;
		end
	end


    r3_mul r3_mul0(
        .clk(Clk),
        .rst(rst_r3_mul),
        .in_ready(in_ready_r3_mul),
		.wr_en_0(wr_en_0_r3_mul),
		.wr_addr_0(wr_addr_0_r3_mul),
		.wr_din_0(wr_din_0_r3_mul),
		.wr_en_1(wr_en_1_r3_mul),
		.wr_addr_1(wr_addr_1_r3_mul),
		.wr_din_1(wr_din_1_r3_mul),
		.DO_addr(DO_addr_r3_mul),
		.DO(DO_r3_mul),
        .valid(valid_r3_mul)
    );

    encode_rp encoder0 (
        .clk(Clk),
        .start(start_enc),
        .done(done_enc),
        .state_l(state_l_enc),
        .state_s(state_s_enc),
        .rp_rd_addr(rp_rd_addr_enc),
        .rp_rd_data(rp_rd_data_enc),
        .cd_wr_addr(cd_wr_addr_enc),
        .cd_wr_data(cd_wr_data_enc),
        .cd_wr_en(cd_wr_en_enc),
        .state_max(state_max_enc),
        .param_r_max(param_r_max_enc),
        .param_m0(param_m0_enc),
        .param_1st_round(param_1st_round_enc),
        .param_outs1(param_outs1_enc),
        .param_outsl(param_outsl_enc)
    ) ;

    rp761q1531encode_param param0_enc (
        .state_max(state_max_enc),
        .state_l(state_l_enc),
        .state_s(state_s_enc),
        .param_r_max(param_r_max_enc),
        .param_m0(param_m0_enc),
        .param_1st_round(param_1st_round_enc),
        .param_outs1(param_outs1_enc),
        .param_outsl(param_outsl_enc)
    ) ;

    sha512_controller sha512_0(
		.clk(Clk),
		.reset_n(reset_n_hash),
		.cmd(cmd_hash),
		.write_data(mem_rd_dout_hash),
		.do_address  (do_address_hash),
		.read_address(mem_rd_addr_hash),
		.data_out(data_out_hash),
		.error(),
		.Valid(Valid_hash)
		);

endmodule
