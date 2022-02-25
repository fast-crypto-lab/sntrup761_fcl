/*******************************************************************
  NTRU Prime KeyGen top module.

  Author: Bo-Yuan Peng       bypeng@crypto.tw
          Hsuan-Chu Liu      jason841226@gmail.com
          Ming-Han Tsai      r08943151@ntu.edu.tw
  Copyright 2021 Academia Sinica
 
  Version Info:
     Jun.10,2020: 0.1.0 Design ready.
     Dec.20.2020: 0.2.0 Design revised for different inversion
                        approach.
     Jun. 4.2021: 0.3.0 Design revised for Good's trick multi-
                        plication approach.

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

module keygen(clk, rst, 
              wr_addr_f, wr_data_f, 
              r3_start, wr_en_in, wr_addr_in, wr_di_in, 
              poly_inverse_cmd, poly_inverse_addr, poly_inverse_DI,
              poly_mul_addr, poly_mul_DI,
              pk_addr, pk_out, sk_addr, sk_out, valid
              );

    input 							clk;
    input 							rst;

    input       [9 : 0]             wr_addr_f;
    input       [7 : 0]             wr_data_f;
    
    input                           r3_start;
    input                           wr_en_in;
    input       [9 : 0]             wr_addr_in;
    input       [7 : 0]             wr_di_in;

    input 		[2:0]				poly_inverse_cmd;
    input 		[9:0]				poly_inverse_addr;
    input 		[12:0]				poly_inverse_DI;

    input 		[10:0]				poly_mul_addr;
    input 		[12:0]				poly_mul_DI;

    input      	[`OUT_DEPTH-1:0]  	pk_addr;
    input      	[9:0]  				sk_addr;

    output	   	[`OUT_D_SIZE-1:0]  	pk_out;
    output  	[7:0] 				sk_out;
    output reg						valid;

    //state
    parameter IDLE = 0;
    parameter r3_recip_state = 1;
    parameter r3_mul_state = 2;
    parameter rq_mul_state = 3;
    parameter mod_state = 4;
    parameter encode_state = 5;
    parameter finish = 6;
    reg 	[2:0]		state;
    reg 	[2:0]		next_state;

    //ctr
    reg 	[11:0] 		ctr, ctr_s1, ctr_s6;
    
    wire r3_wr_en, wr_en_b;
    wire [9 : 0] r3_wr_addr, r3_rd_addr, wr_addr_b, rd_addr_b;
    wire [7 : 0] r3_wr_di, r3_rd_dout, wr_di_b, rd_dout_b;
    reg  [9 : 0] rd_addr_out;

    assign r3_rd_dout = rd_dout_b;
    assign wr_en_b   = (state == r3_recip_state) ? r3_wr_en   : wr_en_in;
    assign wr_addr_b = (state == r3_recip_state) ? r3_wr_addr : wr_addr_in;
    assign wr_di_b   = (state == r3_recip_state) ? r3_wr_di   : wr_di_in;
    assign rd_addr_b = (state == r3_recip_state) ? r3_rd_addr : rd_addr_out;

    // rd_addr_out
    always @(posedge clk ) begin
        if (state == r3_mul_state) begin
            rd_addr_out <= rd_addr_out - 1;
        end else begin
            rd_addr_out <= 761;
        end
    end

    r3_inverse r3_inverse_0(
        .clk(clk),
        .rst(rst),
        .start(r3_start),
        .wr_en(r3_wr_en), 
        .wr_addr(r3_wr_addr), .rd_addr(r3_rd_addr), 
        .wr_di(r3_wr_di), .rd_dout(r3_rd_dout),
        .valid(r3_valid)
    );

    bram_p # ( .D_SIZE(8), .Q_DEPTH(10) ) b0 (
        .clk(clk),
        .wr_en(wr_en_b),
        .wr_addr(wr_addr_b), 
        .rd_addr(rd_addr_b), 
        .wr_din(wr_di_b),
        //.wr_dout(wr_dout),
        .rd_dout(rd_dout_b)
    );

    //poly_inverse
    wire signed [12:0] poly_inverse_DO;
    wire        [9:0]  poly_inverse_addr_in;
    reg         [9:0]  poly_inverse_addr_out;
    wire 	           poly_inverse_valid;

    poly_inverse poly_inverse_0(.Clk(clk),.Reset(rst),.Cmd(poly_inverse_cmd),.Addr(poly_inverse_addr_in),.DI(poly_inverse_DI),.DO(poly_inverse_DO),.Valid(poly_inverse_valid));

    assign poly_inverse_addr_in = (poly_inverse_valid) ? poly_inverse_addr_out : poly_inverse_addr;

    always @(posedge clk)begin
        if(state == rq_mul_state)
            poly_inverse_addr_out <= poly_inverse_addr_out + 1;
        else
            poly_inverse_addr_out <= 1;
    end

    // poly_mul

    reg                  poly_mul_start;
    reg                  poly_mul_input_fg;
    reg         [10 : 0] poly_mul_addr_in;
    reg  signed [12 : 0] poly_mul_in;
    wire signed [13 : 0] poly_mul_out;
    wire 		   	     poly_mul_valid;

    ntt poly_mul(.clk(clk), .rst(rst), .start(poly_mul_start), .input_fg(poly_mul_input_fg), .addr(poly_mul_addr_in), .din(poly_mul_in), .dout(poly_mul_out), .valid(poly_mul_valid));

    // ctr_s1
    always @(posedge clk ) begin
        ctr_s1 <= ctr;
        ctr_s6 <= ctr - 6;
    end

    // poly_mul_input_fg
    always @(posedge clk ) begin
        if (state == rq_mul_state) begin
            poly_mul_input_fg <= 1;
        end else begin
            poly_mul_input_fg <= 0;
        end
    end

    // poly_mul_start
    always @(posedge clk ) begin
        if (state == rq_mul_state && ctr == 1539) begin
            poly_mul_start <= 1;
        end else begin
            poly_mul_start <= 0;
        end
    end

    // poly_mul_addr_in
    always @(posedge clk ) begin
        if (state == rq_mul_state) begin
            poly_mul_addr_in <= ctr_s1;
        end else if (state == encode_state) begin
            poly_mul_addr_in <= ctr_s1;
        end else if (state == mod_state) begin
            poly_mul_addr_in <= ctr;
        end else begin
            poly_mul_addr_in <= poly_mul_addr;
        end
    end

    // poly_mul_in
    always @(posedge clk ) begin
        if (state == rq_mul_state) begin
            if (ctr >= 762) begin
                poly_mul_in <= 0;
            end else begin
                poly_mul_in <= poly_inverse_DO;
            end
        end else if (state == mod_state) begin
            poly_mul_in <= ctr;
        end else begin
            poly_mul_in <= poly_mul_DI;
        end
    end

    reg [1 : 0] round;

    // round
    always @(posedge clk ) begin
        if (state == mod_state) begin
            if (ctr == 760 || ctr == 1521) begin
                round <= round + 1;
            end else begin
                round <= round;
            end
        end else begin
            round <= 0;
        end
    end

    reg                  wr_en_mod;
    reg         [9  : 0] wr_addr_mod, rd_addr_mod;
    wire        [9  : 0] rd_addr_mod_in;
    reg  signed [13 : 0] wr_data_mod;
    wire signed [13 : 0] rd_dout_mod;

    bram_n # ( .D_SIZE(14), .Q_DEPTH(10) ) mod_ram (
        .clk(clk),
        .wr_en(wr_en_mod),
        .wr_addr(wr_addr_mod),
        .wr_din(wr_data_mod),
        .rd_addr(rd_addr_mod_in),
        .rd_dout(rd_dout_mod)
    );
    
    reg signed [13 : 0] add_sum, mod_sum_s2295;
    reg signed [12 : 0] mod_sum;


    // wr_data_mod
    always @(posedge clk ) begin
        if ((round >= 2 && ctr >= 770) || round == 3) begin
            wr_data_mod <= mod_sum_s2295;
        end else begin
            wr_data_mod <= mod_sum;
        end
    end

    // wr_en_mod
    always @(posedge clk ) begin
        if (state == mod_state && ctr > 7) begin
            wr_en_mod <= 1;
        end else begin
            wr_en_mod <= 0;
        end
    end

    // wr_addr_mod
    always @(posedge clk ) begin
        if (round == 2 && wr_addr_mod == 759) begin
            wr_addr_mod <= 0;
        end else if (round == 1 && wr_addr_mod == 760) begin
            wr_addr_mod <= 0;
        end else if (round == 2 && rd_addr_mod == 3) begin
            wr_addr_mod <= 0;
        end else if (ctr > 9) begin
            wr_addr_mod <= wr_addr_mod + 1;
        end else begin
            wr_addr_mod <= 0;
        end
    end

    // add_sum
    always @(posedge clk ) begin
        if (round == 0 || (round == 1 && ctr <= 767)) begin
            add_sum <= poly_mul_out;
        end else if (round == 2 && rd_addr_mod == 0) begin
            add_sum <= rd_dout_mod;
        end else begin
            add_sum <= poly_mul_out + rd_dout_mod;
        end
    end

    // mod_sum
    always @(posedge clk ) begin
        if (add_sum > 2295) begin
            mod_sum <= add_sum - 4591;
        end else if (add_sum < -2295) begin
            mod_sum <= add_sum + 4591;
        end else begin
            mod_sum <= add_sum;
        end
    end

    // mod_sum_s2295
    always @(posedge clk ) begin
        mod_sum_s2295 <= mod_sum + 2295;
    end


    //encode
    wire [4:0] 			    state_l;
    wire [4:0] 			    state_s;
    wire [`OUT_DEPTH-1:0]   cd_wr_addr;
    wire [`OUT_D_SIZE-1:0]  cd_wr_data;
    wire 					cd_wr_en;
    wire [`RP_DEPTH-1:0]    rp_rd_addr;
    wire [`RP_D_SIZE-1:0]   rp_rd_data;
    wire [4:0] 			    state_max;
    wire [`RP_DEPTH-1:0]    param_r_max;
    wire [`RP_D_SIZE-1:0]   param_m0;
    wire 				    param_1st_round;
    wire [2:0] 			  	param_outs1;
    wire [2:0] 			  	param_outsl;
    wire 					done;
    reg  					start;
    integer                 i;
        
    assign rd_addr_mod_in = (state == encode_state) ? rp_rd_addr : rd_addr_mod;
    assign rp_rd_data = rd_dout_mod;

    // rd_addr_mod
    always @(posedge clk ) begin
        if (state == mod_state) begin
            if (round == 0 || (round == 1 && ctr <= 767)) begin
                rd_addr_mod <= 0;
            end else if (round == 2 && rd_addr_mod == 759) begin
                rd_addr_mod <= 0;
            end else begin
                rd_addr_mod <= rd_addr_mod + 1;
            end
        end else begin
            rd_addr_mod <= rp_rd_addr;
        end
    end

    always @(posedge clk)begin
        if(state == encode_state && ctr < 6)
            start <= 1;
        else 
            start <= 0;
    end

    encode_rp encoder_0 (
        .clk(clk),
        .start(start),
        .done(done),
        .state_l(state_l),
        .state_s(state_s),
        .rp_rd_addr(rp_rd_addr),
        .rp_rd_data(rp_rd_data),
        .cd_wr_addr(cd_wr_addr),
        .cd_wr_data(cd_wr_data),
        .cd_wr_en(cd_wr_en),
        .state_max(state_max),
        .param_r_max(param_r_max),
        .param_m0(param_m0),
        .param_1st_round(param_1st_round),
        .param_outs1(param_outs1),
        .param_outsl(param_outsl)
    ) ;

    rp761q4591encode_param param0(.state_max(state_max),.state_l(state_l),.state_s(state_s),.param_r_max(param_r_max),.param_m0(param_m0),.param_1st_round(param_1st_round),.param_outs1(param_outs1),.param_outsl(param_outsl));

    //h
    bram_n # ( .D_SIZE(`OUT_D_SIZE), .Q_DEPTH(`OUT_DEPTH) ) outram0 (
        .clk(clk),
        .wr_en(cd_wr_en),
        .wr_addr(cd_wr_addr),
        .wr_din(cd_wr_data),
        .rd_addr(pk_addr),
        .rd_dout(pk_out)
    );

    reg wr_en_sk;
    wire [8 : 0] wr_addr_sk, rd_addr_sk;
    wire [7 : 0] wr_data_sk, rd_dout_sk;
    reg  [8 : 0] wr_addr_v;
    reg  [7 : 0] wr_data_v;
    reg  [1 : 0] v_3, v_2, v_1, v_0;

    bram_p # ( .D_SIZE(8), .Q_DEPTH(9) ) sk_ram (
        .clk(clk),
        .wr_en(wr_en_sk),
        .wr_addr(wr_addr_sk),
        .wr_din(wr_data_sk),
        .rd_addr(rd_addr_sk),
        .rd_dout(rd_dout_sk)
    );  

    always @(posedge clk ) begin
        if (state == IDLE) begin
            wr_en_sk <= 1;
        end else if (state == r3_mul_state && wr_addr_v > 190 && wr_addr_v < 381) begin
            wr_en_sk <= 1;
        end else begin
            wr_en_sk <= 0;
        end

        if (state == r3_mul_state) begin
            if (wr_addr_v == 381) begin
                wr_addr_v <= wr_addr_v;
            end else if (rd_addr_out[1 : 0] == 2'b00) begin
                wr_addr_v <= wr_addr_v + 1;
            end else begin
                wr_addr_v <= wr_addr_v;
            end
        end else begin
            wr_addr_v <= 190;
        end        

        v_0 <= rd_dout_b[7 : 6] + 1;
        v_1 <= v_0;
        v_2 <= v_1;
        v_3 <= v_2;
    end

    always @(*) begin
        if (wr_addr_v == 381) begin
            wr_data_v = {6'b0, v_0};
        end else begin
            wr_data_v = {v_0, v_1, v_2, v_3};
        end
    end

    assign wr_addr_sk = (state == r3_mul_state) ? wr_addr_v : wr_addr_f;
    assign wr_data_sk = (state == r3_mul_state) ? wr_data_v : wr_data_f;
    assign rd_addr_sk = sk_addr;
    assign sk_out = rd_dout_sk;


    //state
    always @(posedge clk)begin
        if(rst)
            state <= 3'd0;
        else
            state <= next_state;
    end
    always @(*)begin
        case(state)
        IDLE : 
        begin
            if(r3_start)
                next_state = r3_recip_state;
            else
                next_state = IDLE;
        end
        r3_recip_state :
        begin
            if(r3_valid)
                next_state = r3_mul_state;
            else
                next_state = r3_recip_state;
        end
        r3_mul_state :
        begin
            if(/*r3_mul_valid &&*/ poly_inverse_valid)
                next_state = rq_mul_state;
            else
                next_state = r3_mul_state;
        end
        rq_mul_state :
        begin
            if(poly_mul_valid)
                next_state = mod_state;
            else
                next_state = rq_mul_state;
        end
        mod_state :
        begin
            if (round == 3 && wr_addr_mod == 760) begin
                next_state = encode_state;
            end else begin
                next_state = mod_state;
            end
        end
        encode_state :
        begin
            if(cd_wr_addr == 1158)
                next_state = finish;
            else
                next_state = encode_state;
        end
        finish :
        begin
            next_state = finish;
        end
        default : next_state = state;
        endcase
    end

    //ctr
    always @(posedge clk) begin
        if (rst)
            ctr <= 0;
        else if (state == rq_mul_state) begin
            if (poly_mul_valid)
                ctr <= 0;
            else 
                ctr <= ctr + 1;
        end else if (state == mod_state) begin
            if (ctr == 1521) begin
                ctr <= 761;
            end else if (round == 3 && wr_addr_mod == 760) begin
                ctr <= 0;
            end else begin
                ctr <= ctr + 1;
            end
        end else if (state == encode_state) begin
            /*if(ctr == 400)
                ctr <= ctr;
            else*/
                ctr <= ctr + 1;
        end
        else
            ctr <= 0;
    end

    //valid
    always @(posedge clk)begin
        if(rst)
            valid <= 0;
        else if(state == finish)
            valid <= 1;    
        else 
            valid <= valid;
    end

endmodule
