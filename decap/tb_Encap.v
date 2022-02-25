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

module tb_Encap;

	reg Clk;
	integer i;

	initial begin
		Clk = 1;
	end
	always #1 Clk <= ~Clk;
	initial begin
		/*
		$dumpfile("tb_Encap.vcd");
		$dumpvars;
		*/
		$fsdbDumpfile("tb_Encap.fsdb"); 
		$fsdbDumpvars;
	end

	parameter P_WIDTH = 16;
	parameter Q_DEPTH = 10;

	parameter P_WIDTH_K = 8;
	parameter Q_DEPTH_K = 11;

	reg Reset;
	reg [1:0] Cmd;

	reg [2:0] Addr;


	reg wr_en_k;
	reg wr_en_r;
	reg [Q_DEPTH_K-1:0] wr_addr_k;
	reg [Q_DEPTH-1:0] wr_addr_r;
	reg [P_WIDTH_K-1:0] wr_di_k;
	reg [P_WIDTH-1:0] wr_di_r;

	reg [15:0] ram_r [0:2047];
	reg [7:0] ram_k [0:2047];

	wire [31:0] out_r;
	wire [31:0] out_k;

	wire Valid;

	// bram_n #(.Q_DEPTH(Q_DEPTH_K),.D_SIZE(P_WIDTH_K)) ram_k (.clk(Clk), .wr_en(wr_en_k), .wr_addr(wr_addr_k), .rd_addr(rd_addr_k), .wr_din(wr_di_k), .wr_dout(wr_dout_k), .rd_dout(rd_dout_k));
	// bram_p #(.Q_DEPTH(Q_DEPTH),.D_SIZE(P_WIDTH)) ram_r (.clk(Clk), .wr_en(wr_en_r), .wr_addr(wr_addr_r), .rd_addr(rd_addr_r), .wr_din(wr_di_r), .wr_dout(wr_dout_r), .rd_dout(rd_dout_r));
	

	initial begin
		$display("initial memory...");
	    $readmemh("r_hex.txt", ram_r);
	    $readmemh("k_bar_hex.txt", ram_k);
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
			wr_en_r = (i<1024) ? 1 :0;
			wr_en_k = 1;
			wr_addr_r = i;
			wr_addr_k = i;
			wr_di_r = ram_r[i];
			wr_di_k = ram_k[i];
		end
		Cmd = 2;
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

		$writememh("mem_c_encap.txt",decapsualtion0.mem_enc.ram);

		// $writememh("mem_r_encap.txt",decapsualtion0.mem_r.ram);
		// $writememh("mem_dec_encap.txt",decapsualtion0.mem_enc.ram);
		// $display("DONE");

		// $display("c_bar:");
		// for(i=0;i<1007;i=i+1) begin
		// 	$write("%h ",encapsualtion0.mem_c_.ram[i]);
		// end
		// $display("");
		// $display("h_confirm:");
		// for(i=0;i<8;i=i+1) begin
		// 	$write("%h ",encapsualtion0.hashed_k[i]);
		// end
		// $display("");
		// $display("h_session:");
		// for(i=0;i<8;i=i+1) begin
		// 	$write("%h ",encapsualtion0.hashed_r[i]);
		// end
		// $display("");
		// $writememh("aaaaa0.txt",encapsualtion0.bank_f0.ram);
		// $writememh("aaaaa1.txt",encapsualtion0.bank_f1.ram);
		// $writememh("aaaaa2.txt",encapsualtion0.bank_f2.ram);
		// $writememh("k_hex2.txt", encapsualtion0.mem_k.ram);
		// $writememh("c_hex_.txt", encapsualtion0.mem_c_.ram);
		// $writememh("c_hex.txt", encapsualtion0.mem_c.ram);
		$finish;
	end

	decapsualtion decapsualtion0(
		.Clk(Clk), 
		.Reset(Reset),
		.Cmd(Cmd),
		.wr_en_k(wr_en_k), .wr_addr_k(wr_addr_k), .wr_di_k(wr_di_k),
		.wr_en_r(wr_en_r), .wr_addr_r(wr_addr_r), .wr_di_r(wr_di_r),
		.wr_en_C(), .wr_addr_C(), .wr_di_C(),
		.wr_en_sk(), .wr_addr_sk(), .wr_di_sk(),
		.out_addr(Addr),
		.out_r(out_r), .out_k(out_k), .Valid(Valid));


endmodule
