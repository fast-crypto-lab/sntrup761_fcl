`timescale 1ns/100ps

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

module tb_Decap;

	reg Clk;
	integer i;

	initial begin
		Clk = 1;
	end
	always #1 Clk <= ~Clk;
	initial begin
		/*
		$dumpfile("tb_Decap.vcd");
		$dumpvars;
		*/
		$fsdbDumpfile("tb_Decap.fsdb"); 
		$fsdbDumpvars;
	end

	parameter P_WIDTH = 16;
	parameter Q_DEPTH = 10;

	parameter P_WIDTH_K = 8;
	parameter Q_DEPTH_K = 11;

	reg Reset;
	reg [1:0] Cmd;

	reg wr_en_C;
	reg wr_en_sk;
	reg [Q_DEPTH_K-1:0] wr_addr_C;
	reg [Q_DEPTH_K-1:0] wr_addr_sk;

	reg [P_WIDTH_K-1:0] wr_di_C;
	reg [P_WIDTH_K-1:0] wr_di_sk;

	reg [2:0] Addr;

	reg wr_en_k;
	// reg wr_en_r;
	reg [Q_DEPTH_K-1:0] wr_addr_k;
	// reg [Q_DEPTH-1:0] wr_addr_r;
	reg [P_WIDTH_K-1:0] wr_di_k;
	// reg [P_WIDTH-1:0] wr_di_r;

	reg wr_en_rho;
	reg [Q_DEPTH_K-1:0] wr_addr_rho;
	reg [P_WIDTH_K-1:0] wr_di_rho;


	wire [31:0] out_r;
	wire [31:0] out_k;


	// bram_n #(.Q_DEPTH(Q_DEPTH_K),.D_SIZE(P_WIDTH_K)) mem_k_bar (.clk(Clk), .wr_en(wr_en_k), .wr_addr(wr_addr_k), .rd_addr(rd_addr_k), .wr_din(wr_di_k), .wr_dout(wr_dout_k), .rd_dout(rd_dout_k));
	// bram_n #(.Q_DEPTH(Q_DEPTH),.D_SIZE(P_WIDTH))     mem_r     (.clk(Clk), .wr_en(wr_en_r), .wr_addr(wr_addr_r), .rd_addr(rd_addr_r), .wr_din(wr_di_r), .wr_dout(wr_dout_r), .rd_dout(rd_dout_r));
	// bram_n #(.Q_DEPTH(Q_DEPTH_K),.D_SIZE(P_WIDTH_K)) mem_C     (.clk(Clk), .wr_en(wr_en_C), .wr_addr(wr_addr_C), .rd_addr(rd_addr_C), .wr_din(wr_di_C), .wr_dout(wr_dout_C), .rd_dout(rd_dout_C));
	// bram_n #(.Q_DEPTH(Q_DEPTH_K),.D_SIZE(P_WIDTH_K)) mem_sk    (.clk(Clk), .wr_en(wr_en_sk), .wr_addr(wr_addr_sk), .rd_addr(rd_addr_sk), .wr_din(wr_di_sk), .wr_dout(wr_dout_sk), .rd_dout(rd_dout_sk));
	
	reg	[15:0] ram_C [0:2047];
	reg [7:0] ram_sk [0:2047];
	reg [7:0] ram_k [0:2047];
	reg [7:0] ram_rho [0:2047];

	wire Valid;

	initial begin
		$display("initial memory...");
	    $readmemh("C_bar_hex.txt", ram_C);
	    $readmemh("sk_hex.txt", ram_sk);
	    $readmemh("k_bar_hex.txt", ram_k);
	    $readmemh("rho_hex.txt", ram_rho);
		#20;
		Reset = 1;
		Cmd = 0;
		#20;
		Reset = 0;
		#10;
		Cmd = 1;
		#10;
		Cmd = 0;
		#10;
		for (i=0; i<2047; i=i+1)
		begin
			#2;
			wr_en_C = 1;
			wr_en_sk = 1;
			wr_en_k = 1;
			wr_en_rho = 1;
			wr_addr_C = i;
			wr_addr_sk = i;
			wr_addr_k = i;
			wr_addr_rho = i;
			wr_di_C = ram_C[i];
			wr_di_sk = ram_sk[i];
			wr_di_k = ram_k[i];
			wr_di_rho = ram_rho[i];
		end
		Cmd = 3;
		#10;

		wait(Valid)
		#10000;

		for(i=0;i<8;i=i+1)
		begin
			#2
			Addr=i;
			#2;
			$display("%d r: %h",i ,out_r);
			$display("%d k: %h",i ,out_k);
		end
		// $writememh("mem_enc_in.txt",decapsualtion0.mem_enc_in.ram);
		$writememh("r_decap.txt",decapsualtion0.mem_r.ram);
		$writememh("mem_rho_decap.txt",decapsualtion0.mem_rho.ram);
		// $writememh("k.txt",decapsualtion0.mem_k_bar.ram);

		// $writememh("k_decap.txt",decapsualtion0.mem_dec.ram);

		// $writememh("f0_decap.txt",decapsualtion0.schonhage_multiplication0.bank_f0.ram);
		// $writememh("f1_decap.txt",decapsualtion0.schonhage_multiplication0.bank_f1.ram);
		// $writememh("f2_decap.txt",decapsualtion0.schonhage_multiplication0.bank_f2.ram);
		// $writememh("f3_decap.txt",decapsualtion0.schonhage_multiplication0.bank_f3.ram);
		// $writememh("f4_decap.txt",decapsualtion0.schonhage_multiplication0.bank_f4.ram);
		// $writememh("f5_decap.txt",decapsualtion0.schonhage_multiplication0.bank_f5.ram);

		// $writememh("r3_mul_decap.txt",decapsualtion0.r3_mul0.bram_3.ram);
		// $writememh("c_encoded.txt",decapsualtion0.mem_enc.ram);


		// $writememh("mul_qwerty.txt",decapsualtion0.schonhage_multiplication0.ram_out.ram);

		//$writememh("mul_qwerty.txt",decapsualtion0.schonhage_multiplication0.ram_out.ram);


		// $display("DONE");
		// $display("c'_bar:");
		// for(i=0;i<1007;i=i+1) begin
		// 	$write("%h ",decapsualtion0.mem_c_.ram[i]);
		// end
		// $display("");
		// $display("h_confirm':");
		// for(i=0;i<8;i=i+1) begin
		// 	$write("%h ",decapsualtion0.hashed_k[i]);
		// end
		// $display("");
		// $display("h_session':");
		// for(i=0;i<8;i=i+1) begin
		// 	$write("%h ",decapsualtion0.hashed_r[i]);
		// end
		// $display("");
		// $display("out:%h",out);

		// $writememh("C_decap.txt",decapsualtion0.mem_c_orig.ram);
		// $writememh("C_decap2.txt",mem_C.ram);
		// $writememh("aaadec0.txt",decapsualtion0.bank_f0.ram);
		// $writememh("aaadec1.txt",decapsualtion0.bank_f1.ram);
		// $writememh("aaadec2.txt",decapsualtion0.bank_f2.ram);
		// $writememh("r3_mul_dec.txt",decapsualtion0.test.bram_3.ram);
		// $writememh("r_decap_aaa.txt",mem_r.ram);
		$finish;
	end

	decapsualtion decapsualtion0(
		.Clk(Clk), 
		.Reset(Reset),
		.Cmd(Cmd),
		.wr_en_k(wr_en_k), .wr_addr_k(wr_addr_k), .wr_di_k(wr_di_k),
		.wr_en_r(), .wr_addr_r(), .wr_di_r(),
		.wr_en_C(wr_en_C), .wr_addr_C(wr_addr_C), .wr_di_C(wr_di_C),
		.wr_en_sk(wr_en_sk), .wr_addr_sk(wr_addr_sk), .wr_di_sk(wr_di_sk),
		.wr_en_rho(wr_en_rho), .wr_addr_rho(wr_addr_rho), .wr_di_rho(wr_di_rho),
		.out_addr(Addr),
		.out_r(out_r), .out_k(out_k), .Valid(Valid));

endmodule
