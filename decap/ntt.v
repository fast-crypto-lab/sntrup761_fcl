/*******************************************************************
  512-point NTT module on R_7681 and R_10753 simultaneously.
 
  Author: Bo-Yuan Peng       bypeng@crypto.tw
          Ming-Han Tsai      r08943151@ntu.edu.tw
  Copyright 2021 Academia Sinica
 
  Version Info:
     Jun.10,2021: 0.1.0 Design Ready.

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

module ntt (clk, rst, start, input_fg, cmd, addr, din, dout, valid);

    parameter P_WIDTH = 13;
    parameter Q = 7681;
    parameter bit = 9; // 512 point

    // state
    parameter idle = 0;
    parameter ntt = 1;
    parameter point_mul = 2;
    parameter reload = 3;
    parameter intt = 4;
    parameter crt = 5;
    parameter reduce = 6;
    parameter round3 = 7;
    parameter mod3 = 8;
    parameter finish = 9;

    // cmd
    parameter start_and_round3 = 0;
    parameter start_and_mod3 = 1;

    input                clk;
    input                rst;
    input                start;
    input                input_fg;
    input                cmd;
    input       [10 : 0] addr;
    input       [15 : 0] din;
    output signed [15 : 0] dout;
    output reg           valid;

    // bram
    reg            wr_en   [0 : 2];
    reg   [10 : 0] wr_addr [0 : 2];
    reg   [10 : 0] rd_addr [0 : 2];
    reg   [27 : 0] wr_din  [0 : 2];
    wire  [27 : 0] rd_dout [0 : 2];
    wire  [27 : 0] wr_dout [0 : 2];

    // addr_gen
    wire         bank_index_rd [0 : 1];
    wire         bank_index_wr [0 : 1];
    wire [7 : 0] data_index_rd [0 : 1];
    wire [7 : 0] data_index_wr [0 : 1];
    reg  bank_index_wr_0_shift_1, bank_index_wr_0_shift_2;

    // w_addr_gen
    reg  [7 : 0] stage_bit;
    wire [7 : 0] w_addr;

    // bfu
    reg                  ntt_state; 
    reg  signed [13 : 0] in_a  [0 : 1];
    reg  signed [13 : 0] in_b  [0 : 1];
    reg  signed [14 : 0] w     [0 : 1];
    wire signed [28 : 0] bw    [0 : 1];
    wire signed [13 : 0] out_a [0 : 1];
    wire signed [13 : 0] out_b [0 : 1];

    // state, stage, counter
    reg  [3 : 0] state, next_state;
    reg  [3 : 0] stage, stage_wr;
    reg  [8 : 0] ctr;
    reg  [8 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_1, ctr_shift_2;
    reg  [2 : 0] ctr_ntt;
    reg  [1 : 0] count_f, count_g;
    reg          part, part_shift, ctr_8_shift_1;
    wire         ctr_end, ctr_shift_7_end, stage_end, stage_wr_end, ntt_end, point_mul_end;
    reg  [1 : 0] count_f_shift_1, count_f_shift_2;
    reg  [1 : 0] count_g_shift_1, count_g_shift_2, count_g_shift_3, count_g_shift_4, count_g_shift_5;

    // w_7681
    reg         [8  : 0] w_addr_in;
    wire signed [13 : 0] w_dout [0 : 1];

    reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
    reg [8  : 0] wr_ctr [0 : 1];
    reg [12 : 0] din_shift_1, din_shift_2, din_shift_3;
    reg [8  : 0] w_addr_in_shift_1;

    // mod_3
    wire [2 : 0] in_addr;
    wire [10 : 0] mod3_addr;

    // crt
    reg signed [27 : 0] bw_sum;
    reg signed [27 : 0] bw_sum_mod;
    wire signed [12 : 0] mod4591_out;

    reg                  wr_en_mod;
    reg         [9  : 0] wr_addr_mod, rd_addr_mod;
    wire        [9  : 0] rd_addr_mod_in;
    reg  signed [13 : 0] wr_data_mod;
    wire signed [13 : 0] rd_dout_mod;

    reg signed [13 : 0] add_sum, mod_sum_s2295;
    reg signed [12 : 0] mod_sum;
    reg        [11 : 0] mod_ctr;
    reg        [1 : 0]  round;

    reg         [10 : 0] poly_mul_addr_in;
    reg  signed [13 : 0] poly_mul_out;

    reg mode;

    bram_p #(.D_SIZE(28), .Q_DEPTH(11)) bank_0 
    (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
    bram_p #(.D_SIZE(28), .Q_DEPTH(11)) bank_1
    (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);
    bram_p #(.D_SIZE(28), .Q_DEPTH(11)) bank_2
    (clk, wr_en[2], wr_addr[2], rd_addr[2], wr_din[2], wr_dout[2], rd_dout[2]);
    bram_n # ( .D_SIZE(14), .Q_DEPTH(10) ) mod_ram (
        .clk(clk),
        .wr_en(wr_en_mod),
        .wr_addr(wr_addr_mod),
        .wr_din(wr_data_mod),
        .rd_addr(rd_addr_mod_in),
        .rd_dout(rd_dout_mod)
    );



    addr_gen addr_rd_0 (clk, stage,    {1'b0, ctr[7 : 0]}, bank_index_rd[0], data_index_rd[0]);
    addr_gen addr_rd_1 (clk, stage,    {1'b1, ctr[7 : 0]}, bank_index_rd[1], data_index_rd[1]);
    addr_gen addr_wr_0 (clk, stage_wr, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
    addr_gen addr_wr_1 (clk, stage_wr, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

    w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[7 : 0], w_addr);

    bfu_7681 bfu_0 (clk, ntt_state, in_a[0], in_b[0], w[0], bw[0], out_a[0], out_b[0]);
    bfu_10753 bfu_1 (clk, ntt_state, in_a[1], in_b[1], w[1], bw[1], out_a[1], out_b[1]);

    w_7681 rom_w_7681 (clk, w_addr_in_shift_1, w_dout[0]);
    w_10753 rom_w_10753 (clk, w_addr_in_shift_1, w_dout[1]);

    mod_3 in_addr_gen (clk, mod3_addr, input_fg, in_addr);
    modmul4591S mod_4591 ( clk, rst, bw_sum_mod, mod4591_out);

    assign ctr_end         = (ctr[7 : 0] == 255) ? 1 : 0;
    assign ctr_shift_7_end = (ctr_shift_7[7 : 0] == 255) ? 1 : 0;
    assign stage_end       = (stage == 9) ? 1 : 0;
    assign stage_wr_end    = (stage_wr == 9) ? 1 : 0;
    assign ntt_end         = (stage_end && ctr[7 : 0] == 10) ? 1 : 0;
    // change assign ntt_end         = (stage_end && ctr[7 : 0] == 8) ? 1 : 0;
    assign point_mul_end   = (count_f == 3 && ctr_shift_7 == 511) ? 1 : 0;
    assign reload_end      = (count_f == 0 && ctr == 4) ? 1 : 0;
    assign reduce_end      = (round == 3 && wr_addr_mod == 760) ? 1 : 0;

    assign mod3_addr = (state == reduce) ? poly_mul_addr_in : addr;


    assign rd_addr_mod_in = (state == finish) ? addr : rd_addr_mod;
    assign dout = {{2{rd_dout_mod[13]}}, rd_dout_mod};
    


    reg signed [2 : 0] remainder_3;
    reg signed [1 : 0] remainder_mod3, remainder_mod3_s1, remainder_mod3_s2, remainder_mod3_s3;
    reg signed [13 : 0] mod_sum_shift1, mod_sum_shift2, round_3, round_3_div_3, round_3_div_3_s765;
    reg signed [13 : 0] test;

    // remainder_3, mod_sum_shift1, round_3, round_3_div_3, round_3_div_3_s765
    always @(posedge clk ) begin
        remainder_3 <= mod_sum % 3;
        if (remainder_3 == 2) begin
            remainder_mod3 <= -1;
        end else if (remainder_3 == -2) begin
            remainder_mod3 <= 1;
        end else begin
            remainder_mod3 <= remainder_3;
        end
        remainder_mod3_s1 <= remainder_mod3;
        remainder_mod3_s2 <= remainder_mod3_s1;
        remainder_mod3_s3 <= remainder_mod3_s2;

        mod_sum_shift1 <= mod_sum;
        mod_sum_shift2 <= mod_sum_shift1;
        round_3 <= mod_sum_shift2 - remainder_mod3;
        round_3_div_3 <= round_3/3;
        round_3_div_3_s765 <= round_3_div_3 + 765;

        if (mode == 0) begin
            test <= round_3_div_3_s765;
        end else begin
            test <= remainder_mod3_s3;
        end
    end


    // poly_mul_addr_in
    always @(posedge clk ) begin
        poly_mul_addr_in <= mod_ctr;
    end

    // mod_ctr
    always @(posedge clk ) begin
        if (state == reduce) begin
            if (mod_ctr == 1521) begin
                mod_ctr <= 761;
            end else if (round == 3 && wr_addr_mod == 760) begin
                mod_ctr <= 0;
            end else begin
                mod_ctr <= mod_ctr + 1;
            end
        end else begin
            mod_ctr <= 0;
        end
    end

    // round
    always @(posedge clk ) begin
        if (state == reduce) begin
            if (mod_ctr == 760 || mod_ctr == 1521) begin
                round <= round + 1;
            end else begin
                round <= round;
            end
        end else begin
            round <= 0;
        end
    end

    // wr_data_mod
    always @(posedge clk ) begin
        if ((round >= 2 && mod_ctr >= 770) || round == 3) begin
            //wr_data_mod <= mod_sum_s2295;
            if (mode == 0) begin
                wr_data_mod <= round_3_div_3_s765;
            end else begin
                wr_data_mod <= remainder_mod3_s3;
            end
        end else begin
            wr_data_mod <= mod_sum;
        end
    end

    // rd_addr_mod
    always @(posedge clk ) begin
        if (state == reduce) begin
            if (round == 0 || (round == 1 && mod_ctr <= 767)) begin
                rd_addr_mod <= 0;
            end else if (round == 2 && rd_addr_mod == 759) begin
                rd_addr_mod <= 0;
            end else begin
                rd_addr_mod <= rd_addr_mod + 1;
            end
        end else begin
            rd_addr_mod <= addr;
        end
    end

    // wr_en_mod
    always @(posedge clk ) begin
        if (state == reduce && mod_ctr > 7) begin
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
        end else if (round == 2 && (rd_addr_mod >= 3 && rd_addr_mod <= 7)) begin
            wr_addr_mod <= 0;
        end else if (mod_ctr > 9) begin
            wr_addr_mod <= wr_addr_mod + 1;
        end else begin
            wr_addr_mod <= 0;
        end
    end

    // add_sum
    always @(posedge clk ) begin
        if (round == 0 || (round == 1 && mod_ctr <= 767)) begin
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
        mod_sum_s2295 <= mod_sum + 0;
    end


    // cmd
    always @(posedge clk ) begin
        if (start && cmd == start_and_round3) begin
            mode <= 0;
        end else if (start && cmd == start_and_mod3) begin
            mode <= 1;
        end else begin
            mode <= mode;
        end	
    end

    // crt
    always @(posedge clk ) begin
        bw_sum <= bw[0] + bw[1];
        
        if (bw_sum > 80000000) begin
            bw_sum_mod <= bw_sum - 82593793;
        end else if (bw_sum < -80000000) begin
            bw_sum_mod <= bw_sum + 82593793;
        end else begin
            bw_sum_mod <= bw_sum;
        end
    end

    // poly_mul_out
    always @(posedge clk ) begin
        if (bank_index_wr_0_shift_2) begin
            //dout <= wr_dout[1][27 : 14];
            poly_mul_out <= wr_dout[1][13 : 0];
        end else begin
            //dout <= wr_dout[0][27 : 14];
            poly_mul_out <= wr_dout[0][13 : 0];
        end
    end

    // bank_index_wr_0_shift_1
    always @(posedge clk ) begin
        bank_index_wr_0_shift_1 <= bank_index_wr[0];
        bank_index_wr_0_shift_2 <= bank_index_wr_0_shift_1;
    end

    // part
    always @(posedge clk ) begin
        ctr_8_shift_1 <= ctr[8];
        part <= ctr_8_shift_1;
        part_shift <= ctr_shift_7[8];
    end

    // count_f, count_g
    always @(posedge clk ) begin
        if (state == point_mul || state == reload || state == crt) begin
            if (count_g == 2 && ctr == 511) begin
                count_f <= count_f + 1;
            end else begin
                count_f <= count_f;
            end
        end else begin
            count_f <= 0;
        end
        count_f_shift_1 <= count_f;
        count_f_shift_2 <= count_f_shift_1;


        if (state == point_mul || state == reload || state == crt) begin
            if (ctr == 511) begin
                if (count_g == 2) begin
                    count_g <= 0;
                end else begin
                    count_g <= count_g + 1;
                end
            end else begin
                count_g <= count_g;
            end
        end else begin
            count_g <= 0;
        end
        count_g_shift_1 <= count_g;
        count_g_shift_2 <= count_g_shift_1;
        count_g_shift_3 <= count_g_shift_2;
        count_g_shift_4 <= count_g_shift_3;
        count_g_shift_5 <= count_g_shift_4;
    end

    // rd_addr[2]
    always @(posedge clk ) begin
        if (state == point_mul) begin
            rd_addr[2][8 : 0] <= ctr;
        end else if (state == reload) begin
            rd_addr[2][8 : 0] <= {bank_index_wr[1], data_index_wr[1]};
        end else begin
            rd_addr[2][8 : 0] <= 0;
        end

        if (state == point_mul) begin
            if (ctr == 0) begin
                if (count_g == 0) begin
                    rd_addr[2][10 : 9] <= count_f;
                end else begin
                    if (rd_addr[2][10 : 9] == 0) begin
                        rd_addr[2][10 : 9] <= 1;
                    end else if (rd_addr[2][10 : 9] == 1) begin
                        rd_addr[2][10 : 9] <= 2;
                    end else begin
                        rd_addr[2][10 : 9] <= 0;
                    end
                end
            end else begin
                rd_addr[2][10 : 9] <= rd_addr[2][10 : 9];
            end
        end else if (state == reload) begin
            rd_addr[2][10 : 9] <= count_g_shift_3;
        end else begin
            rd_addr[2][10 : 9] <= 0;
        end
    end

    // wr_en[2]
    always @(posedge clk ) begin
        if (state == point_mul) begin
            if (count_f == 0 && count_g == 0 && ctr < 8 /* change ctr < 6*/) begin
                wr_en[2] <= 0;
            end else begin
                wr_en[2] <= 1;
            end
        end else begin
            wr_en[2] <= 0;
        end
    end

    // wr_addr[2]
    always @(posedge clk ) begin
        if (state == point_mul) begin
            wr_addr[2][8 : 0] <= ctr_shift_7;
        end else begin
            wr_addr[2][8 : 0] <= 0;
        end        

        if (state == point_mul) begin
            if (ctr_shift_7 == 0) begin
                if (count_g == 0) begin
                    wr_addr[2][10 : 9] <= count_f;
                end else begin
                    if (wr_addr[2][10 : 9] == 0) begin
                        wr_addr[2][10 : 9] <= 1;
                    end else if (wr_addr[2][10 : 9] == 1) begin
                        wr_addr[2][10 : 9] <= 2;
                    end else begin
                        wr_addr[2][10 : 9] <= 0;
                    end
                end
            end else begin
                wr_addr[2][10 : 9] <= wr_addr[2][10 : 9];
            end
        end else begin
            wr_addr[2][10 : 9] <= 0;
        end
    end

    // wr_din[2]
    always @(* ) begin
        wr_din[2][13 : 0] = out_a[0];
        wr_din[2][27 : 14] = out_a[1];
    end

    // ctr_ntt
    always @(posedge clk ) begin
        if (state == ntt || state == intt) begin
            if (ntt_end) begin
                ctr_ntt <= ctr_ntt + 1;
            end else begin
                ctr_ntt <= ctr_ntt;
            end    
        end else begin
            ctr_ntt <= 0;
        end
    end

    // w_addr_in_shift_1
    always @(posedge clk ) begin
        w_addr_in_shift_1 <= w_addr_in;
    end

    // din_shift
    always @(posedge clk ) begin
        din_shift_1 <= din;
        din_shift_2 <= din_shift_1;
        din_shift_3 <= din_shift_2;
    end

    // rd_addr
    always @(posedge clk ) begin
        if (state == point_mul || state == crt) begin
            rd_addr[0][7 : 0] <= ctr[7 : 0];
            rd_addr[1][7 : 0] <= ctr[7 : 0];
        end else begin
            if (bank_index_rd[0] == 0) begin
                rd_addr[0][7 : 0] <= data_index_rd[0];
                rd_addr[1][7 : 0] <= data_index_rd[1];
            end else begin
                rd_addr[0][7 : 0] <= data_index_rd[1];
                rd_addr[1][7 : 0] <= data_index_rd[0];
            end
        end

        if (state == point_mul) begin
            rd_addr[0][10 : 8] <= count_f;
            rd_addr[1][10 : 8] <= count_f;
        end else if (state == crt) begin
            rd_addr[0][10 : 8] <= count_g;
            rd_addr[1][10 : 8] <= count_g;  
        end else begin
            rd_addr[0][10 : 8] <= ctr_ntt;
            rd_addr[1][10 : 8] <= ctr_ntt;
        end
    end

    // wr_ctr
    always @(posedge clk ) begin
        if (state == idle) begin
            wr_ctr[0] <= addr[8 : 0];
        end else if (state == reload) begin
            wr_ctr[0] <= {ctr_shift_2[0], ctr_shift_2[1], ctr_shift_2[2], ctr_shift_2[3], ctr_shift_2[4], ctr_shift_2[5], ctr_shift_2[6], ctr_shift_2[7], ctr_shift_2[8]};
        end else if (state == reduce) begin
            wr_ctr[0] <= {poly_mul_addr_in[0], poly_mul_addr_in[1], poly_mul_addr_in[2],
                          poly_mul_addr_in[3], poly_mul_addr_in[4], poly_mul_addr_in[5],
                          poly_mul_addr_in[6], poly_mul_addr_in[7], poly_mul_addr_in[8]};
        end else begin
            wr_ctr[0] <= {1'b0, ctr_shift_7[7 : 0]};
        end

        if (state == reload) begin
            wr_ctr[1] <= ctr;
        end else begin
            wr_ctr[1] <= {1'b1, ctr_shift_7[7 : 0]};
        end
    end

    // wr_en
    always @(posedge clk ) begin
        if (state == idle || state == reload) begin
            if (bank_index_wr[0]) begin
                wr_en[0] <= 0;
                wr_en[1] <= 1;
            end else begin
                wr_en[0] <= 1;
                wr_en[1] <= 0;
            end
        end else if (state == ntt || state == intt) begin
            if (stage == 0 && ctr < 11 /*change 9*/) begin
                wr_en[0] <= 0;
                wr_en[1] <= 0;
            end else begin
                wr_en[0] <= 1;
                wr_en[1] <= 1;
            end
        end else if (state == crt) begin
            if (count_f == 0 && count_g == 0 && ctr < 9/* change */) begin
                wr_en[0] <= 0;
                wr_en[1] <= 0;
            end else if (!part_shift) begin
                wr_en[0] <= 1;
                wr_en[1] <= 0;
            end else begin
                wr_en[0] <= 0;
                wr_en[1] <= 1;
            end
        end else begin
            wr_en[0] <= 0;
            wr_en[1] <= 0;
        end
    end

    // wr_addr
    always @(posedge clk ) begin
        if (state == point_mul) begin
            wr_addr[0][7 : 0] <= ctr[7 : 0];
            wr_addr[1][7 : 0] <= ctr[7 : 0];
        end else if (state == reload) begin
            wr_addr[0][7 : 0] <= data_index_wr[0];
            wr_addr[1][7 : 0] <= data_index_wr[0];
        end else if (state == crt) begin
            wr_addr[0][7 : 0] <= ctr_shift_8[7 : 0];
            wr_addr[1][7 : 0] <= ctr_shift_8[7 : 0];
        end else begin
            if (bank_index_wr[0] == 0) begin
                wr_addr[0][7 : 0] <= data_index_wr[0];
                wr_addr[1][7 : 0] <= data_index_wr[1];
            end else begin
                wr_addr[0][7 : 0] <= data_index_wr[1];
                wr_addr[1][7 : 0] <= data_index_wr[0];
            end
        end  

        if (state == idle || state == reduce) begin
            wr_addr[0][10 : 8] <= in_addr;
            wr_addr[1][10 : 8] <= in_addr;
        end else if(state == ntt || state == intt) begin
            wr_addr[0][10 : 8] <= ctr_ntt;
            wr_addr[1][10 : 8] <= ctr_ntt;
        end else if (state == point_mul) begin
            wr_addr[0][10 : 8] <= count_g + 3;
            wr_addr[1][10 : 8] <= count_g + 3;
        end else if (state == reload) begin
            wr_addr[0][10 : 8] <= count_g_shift_5;
            wr_addr[1][10 : 8] <= count_g_shift_5;
        end else if (state == crt) begin
            if (ctr_shift_8 == 0) begin
                wr_addr[0][10 : 8] <= count_g;
                wr_addr[1][10 : 8] <= count_g;
            end else begin
                wr_addr[0][10 : 8] <= wr_addr[0][10 : 8];
                wr_addr[1][10 : 8] <= wr_addr[1][10 : 8];
            end
        end else begin
            wr_addr[0][10 : 8] <= 0;
            wr_addr[1][10 : 8] <= 0;
        end     
    end

    // wr_din
    always @(posedge clk ) begin
        if (state == idle) begin
            wr_din[0][13 : 0] <= {din_shift_3[12], din_shift_3};
            wr_din[1][13 : 0] <= {din_shift_3[12], din_shift_3};
        end else if (state == reload) begin
            wr_din[0][13 : 0] <= rd_dout[2][13 : 0];
            wr_din[1][13 : 0] <= rd_dout[2][13 : 0];
        end else if (state == crt) begin
            wr_din[0][13 : 0] <= out_a[0];
            wr_din[1][13 : 0] <= out_a[0];
            if (count_f == 0 || (count_f == 1 && count_g == 0 && ctr < 9)) begin
                wr_din[0][13 : 0] <= out_a[0];
                wr_din[1][13 : 0] <= out_a[0];
            end else begin
                wr_din[0][13 : 0] <= mod4591_out;
                wr_din[1][13 : 0] <= mod4591_out;
            end
        end else begin
            if (bank_index_wr[0] == 0) begin
                wr_din[0][13 : 0] <= out_a[0];
                wr_din[1][13 : 0] <= out_b[0];
            end else begin
                wr_din[0][13 : 0] <= out_b[0];
                wr_din[1][13 : 0] <= out_a[0];
            end
        end

        if (state == idle) begin
            wr_din[0][27 : 14] <= {din_shift_3[12], din_shift_3};
            wr_din[1][27 : 14] <= {din_shift_3[12], din_shift_3};
        end else if (state == reload) begin
            wr_din[0][27 : 14] <= rd_dout[2][27 : 14];
            wr_din[1][27 : 14] <= rd_dout[2][27 : 14];
        end else if (state == crt) begin
            wr_din[0][27 : 14] <= out_a[1];
            wr_din[1][27 : 14] <= out_a[1];
        end else begin
            if (bank_index_wr[0] == 0) begin
                wr_din[0][27 : 14] <= out_a[1];
                wr_din[1][27 : 14] <= out_b[1];
            end else begin
                wr_din[0][27 : 14] <= out_b[1];
                wr_din[1][27 : 14] <= out_a[1];
            end
        end        
    end

    // bank_index_rd_shift
    always @(posedge clk ) begin
        bank_index_rd_shift_1 <= bank_index_rd[0];
        bank_index_rd_shift_2 <= bank_index_rd_shift_1;
    end

    // ntt_state
    always @(posedge clk ) begin
        if (state == intt) begin
            ntt_state <= 1;
        end else begin
            ntt_state <= 0;
        end
    end

    // in_a, in_b
    always @(posedge clk ) begin
        if (state == point_mul || state == crt) begin
            if (!part) begin
                in_b[0] <= rd_dout[0][13 : 0];
                in_b[1] <= rd_dout[0][27 : 14];
            end else begin
                in_b[0] <= rd_dout[1][13 : 0];
                in_b[1] <= rd_dout[1][27 : 14];
            end
        end else begin
            if (bank_index_rd_shift_2 == 0) begin
                in_b[0] <= rd_dout[1][13 : 0];
                in_b[1] <= rd_dout[1][27 : 14];
            end else begin
                in_b[0] <= rd_dout[0][13 : 0];
                in_b[1] <= rd_dout[0][27 : 14];
            end
        end

        if (state == point_mul) begin
            if (count_f_shift_2 == 0) begin
                in_a[0] <= 0;
                in_a[1] <= 0;
            end else begin
                in_a[0] <= rd_dout[2][13 : 0];
                in_a[1] <= rd_dout[2][27 : 14];
            end
        end else if (state == crt) begin
            in_a[0] <= 0;
            in_a[1] <= 0;
        end else begin
            if (bank_index_rd_shift_2 == 0) begin
                in_a[0] <= rd_dout[0][13 : 0];
                in_a[1] <= rd_dout[0][27 : 14];
            end else begin
                in_a[0] <= rd_dout[1][13 : 0];
                in_a[1] <= rd_dout[1][27 : 14];
            end
        end
    end

    // w_addr_in, w
    always @(posedge clk ) begin
        if (state == ntt) begin
            w_addr_in <= {1'b0, w_addr};
        end else begin
            w_addr_in <= 512 - w_addr;
        end

        if (state == point_mul) begin
            if (!part) begin
                w[0] <= {wr_dout[0][13], wr_dout[0][13 : 0]};
                w[1] <= {wr_dout[0][27], wr_dout[0][27 : 14]};
            end else begin
                w[0] <= {wr_dout[1][13], wr_dout[1][13 : 0]};
                w[1] <= {wr_dout[1][27], wr_dout[1][27 : 14]};
            end
        end else if (state == crt) begin
            if (count_f_shift_2 == 0) begin
                w[0] <= 3838;
                w[1] <= -5373;
            end else begin
                w[0] <= 10753;
                w[1] <= 7681;
            end
        end else begin
            w[0] <= w_dout[0];
            w[1] <= w_dout[1];
        end
    end

    // ctr, ctr_shift_7
    always @(posedge clk ) begin
        if (state == ntt || state == intt || state == point_mul || state == crt) begin
            if (ntt_end || point_mul_end) begin
                ctr <= 0;
            end else begin
                ctr <= ctr + 1;
            end
        end else if (state == reload) begin
            if (reload_end) begin
                ctr <= 0;
            end else begin
                ctr <= ctr + 1;
            end
        end else if (state == reduce) begin
            if (reduce_end) begin
                ctr <= 0;
            end else begin
                ctr <= ctr + 1;
            end
        end else begin
            ctr <= 0;
        end

        //change ctr_shift_7 <= ctr - 5;
        ctr_shift_7 <= ctr - 7;
        ctr_shift_8 <= ctr_shift_7;
        ctr_shift_1 <= ctr;
        ctr_shift_2 <= ctr_shift_1;
    end

    // stage, stage_wr
    always @(posedge clk ) begin
        if (state == ntt || state == intt) begin
            if (ntt_end) begin
                stage <= 0;
            end else if (ctr_end) begin
                stage <= stage + 1;
            end else begin
                stage <= stage;
            end
        end else begin
            stage <= 0;
        end

        if (state == ntt || state == intt) begin
            if (ntt_end) begin
                stage_wr <= 0;
            end else if (ctr_shift_7[7 : 0] == 0 && stage != 0) begin
               stage_wr <= stage_wr + 1;
            end else begin
                stage_wr <= stage_wr;
            end
        end else begin
            stage_wr <= 0;
        end        
    end

    // stage_bit
    always @(posedge clk ) begin
        if (state == ntt || state == intt) begin
            if (ntt_end) begin
                stage_bit <= 0;
            end else if (ctr_end) begin
                stage_bit[0] <= 1'b1;
                stage_bit[7 : 1] <= stage_bit[6 : 0];
            end else begin
                stage_bit <= stage_bit;
            end
        end else begin
            stage_bit <= 8'b0;
        end
    end

    // valid
    always @(* ) begin
        if (state == finish) begin
            valid = 1;
        end else begin
            valid = 0;
        end
    end

    // state
	always @(posedge clk ) begin
		if(rst) begin
            state <= 0;
        end else begin
            state <= next_state;
        end
	end
	always @(*) begin
		case(state)
		idle:
		begin
			if(start)
				next_state = ntt;
			else
				next_state = idle;
		end
		ntt:
		begin
			if(ntt_end && ctr_ntt == 5)
				next_state = point_mul;
			else
				next_state = ntt;
		end
        point_mul:
        begin
            if (point_mul_end) begin
                next_state = reload;
            end else begin
                next_state = point_mul;
            end
        end
        reload:
        begin
            if (reload_end) begin
                next_state = intt;
            end else begin
                next_state = reload;
            end
        end
        intt:
        begin
            if(ntt_end && ctr_ntt == 2)
				next_state = crt;
			else
				next_state = intt;
        end
        crt:
        begin
            if(count_f == 2 && ctr == 8)
				next_state = reduce;
			else
				next_state = crt;
        end
        reduce:
        begin
            if(reduce_end)
				next_state = finish;
			else
				next_state = reduce;
        end
		finish:
		begin
            /*
			if(!start)
				next_state = finish;
			else
				next_state = idle;
                */
            next_state = finish;
		end
		default: next_state = state;
		endcase
	end

endmodule

module mod_3 (clk, addr, fg, out);

    input               clk;
    input               fg;
    input      [10 : 0] addr;
    output reg [2  : 0] out;

    reg [2 : 0] even, odd;
    reg signed [2 : 0] even_minus_odd;
    reg fg_shift_1;
    reg [1 : 0] const;

    always @(posedge clk ) begin
        fg_shift_1 <= fg;

        if (fg_shift_1) begin
            const <= 3;
        end else begin
            const <= 0;
        end

        even <= addr[0] + addr[2] + addr[4] + addr[6] + addr[8] + addr[10];
        odd  <= addr[1] + addr[3] + addr[5] + addr[7] + addr[9];
        even_minus_odd <= even[2] - even[1] + even[0] - odd[2] + odd[1] - odd[0];

        if (even_minus_odd == 3) begin
            out <= 0 + const;
        end else begin
            out <= even_minus_odd[1 : 0] - even_minus_odd[2] + const;
        end
    end

endmodule

module w_addr_gen (clk, stage_bit, ctr, w_addr);

    input              clk;
    input      [7 : 0] stage_bit;  // 0 - 8
    input      [7 : 0] ctr;        // 0 - 255
    output reg [7 : 0] w_addr;

    wire [7 : 0] w;

    assign w[0] = (stage_bit[0]) ? ctr[0] : 0;
    assign w[1] = (stage_bit[1]) ? ctr[1] : 0;
    assign w[2] = (stage_bit[2]) ? ctr[2] : 0;
    assign w[3] = (stage_bit[3]) ? ctr[3] : 0;
    assign w[4] = (stage_bit[4]) ? ctr[4] : 0;
    assign w[5] = (stage_bit[5]) ? ctr[5] : 0;
    assign w[6] = (stage_bit[6]) ? ctr[6] : 0;
    assign w[7] = (stage_bit[7]) ? ctr[7] : 0;

    always @(posedge clk ) begin
        w_addr <= {w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7]};
    end
    
endmodule
/*
module bfu_7681 (clk, state, in_a, in_b, w, bw, out_a, out_b);

    parameter P_WIDTH = 14;
    parameter PP_WIDTH = 25;
    parameter Q = 7681;

    input                                clk;
    input                                state;
    input      signed [13 : 0] in_a;
    input      signed [13 : 0] in_b;
    input      signed [14 : 0] w;
    output reg signed [28 : 0] bw;
    output reg signed [13 : 0] out_a;
    output reg signed [13 : 0] out_b;

    reg signed [13 : 0] mod_bw;
    reg signed [14 : 0] a, b;
    reg signed [13 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

    reg signed [28 : 0] bwQ_0, bwQ_1, bwQ_2;
    wire signed [14  : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

    //assign bwQ = bw % Q;
    assign a_add_q = a + Q;
    assign a_sub_q = a - Q;
    assign b_add_q = b + Q;
    assign b_sub_q = b - Q;
    
    
    // in_a shift
    always @(posedge clk ) begin
        in_a_s1 <= in_a;
        in_a_s2 <= in_a_s1;
        in_a_s3 <= in_a_s2;
        in_a_s4 <= in_a_s3;
        in_a_s5 <= in_a_s4;
    end

    // b * w
    always @(posedge clk ) begin
        bw <= in_b * w;
        bwQ_0 <= bw % Q;
        bwQ_1 <= bwQ_0;

        if (bwQ_1 > 3840) begin
            mod_bw <= bwQ_1 - Q;
        end else if (bwQ_1 < -3840) begin
            mod_bw <= bwQ_1 + Q;
        end else begin
            mod_bw <= bwQ_1;
        end        
    end

    // out_a, out_b
    always @(posedge clk ) begin
        //a <= in_a_s2 + mod_bw;
        //b <= in_a_s2 - mod_bw;

        a <= in_a_s4 + mod_bw;
        b <= in_a_s4 - mod_bw;

        if (state == 0) begin
            if (a > 3840) begin
                out_a <= a_sub_q;
            end else if (a < -3840) begin
                out_a <= a_add_q;
            end else begin
                out_a <= a;
            end
        end else begin
            if (a[0] == 0) begin
                out_a <= a[P_WIDTH : 1];
            end else if (a[P_WIDTH] == 0) begin   // a > 0
                out_a <= a_sub_q[P_WIDTH : 1];
            end else begin                        // a < 0
                out_a <= a_add_q[P_WIDTH : 1];
            end
        end


        if (state == 0) begin
            if (b > 3840) begin
                out_b <= b - Q;
            end else if (b < -3840) begin
                out_b <= b + Q;
            end else begin
                out_b <= b;
            end
        end else begin
            if (b[0] == 0) begin
                out_b <= b[P_WIDTH : 1];
            end else if (b[P_WIDTH] == 0) begin   // b > 0
                out_b <= b_sub_q[P_WIDTH : 1];
            end else begin                        // b < 0
                out_b <= b_add_q[P_WIDTH : 1];
            end
        end
    end

endmodule

module bfu_10753 (clk, state, in_a, in_b, w, bw, out_a, out_b);

    parameter P_WIDTH = 14;
    parameter PP_WIDTH = 25;
    parameter Q = 10753;

    input                                clk;
    input                                state;
    input      signed [13 : 0] in_a;
    input      signed [13 : 0] in_b;
    input      signed [14 : 0] w;
    output reg signed [28 : 0] bw;
    output reg signed [13 : 0] out_a;
    output reg signed [13 : 0] out_b;

    reg signed [13 : 0] mod_bw;
    reg signed [14 : 0] a, b;
    reg signed [13 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

    reg signed [28 : 0] bwQ_0, bwQ_1, bwQ_2;
    wire signed [14  : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

    //assign bwQ = bw % Q;
    assign a_add_q = a + Q;
    assign a_sub_q = a - Q;
    assign b_add_q = b + Q;
    assign b_sub_q = b - Q;
    
    
    // in_a shift
    always @(posedge clk ) begin
        in_a_s1 <= in_a;
        in_a_s2 <= in_a_s1;
        in_a_s3 <= in_a_s2;
        in_a_s4 <= in_a_s3;
        in_a_s5 <= in_a_s4;
    end

    // b * w
    always @(posedge clk ) begin
        bw <= in_b * w;
        bwQ_0 <= bw % Q;
        bwQ_1 <= bwQ_0;
        bwQ_2 <= bwQ_1;

        if (bwQ_1 > 5376) begin
            mod_bw <= bwQ_1 - Q;
        end else if (bwQ_1 < -5376) begin
            mod_bw <= bwQ_1 + Q;
        end else begin
            mod_bw <= bwQ_1;
        end        
    end

    // out_a, out_b
    always @(posedge clk ) begin
        //a <= in_a_s2 + mod_bw;
        //b <= in_a_s2 - mod_bw;

        a <= in_a_s4 + mod_bw;
        b <= in_a_s4 - mod_bw;

        if (state == 0) begin
            if (a > 5376) begin
                out_a <= a_sub_q;
            end else if (a < -5376) begin
                out_a <= a_add_q;
            end else begin
                out_a <= a;
            end
        end else begin
            if (a[0] == 0) begin
                out_a <= a[P_WIDTH : 1];
            end else if (a[P_WIDTH] == 0) begin   // a > 0
                out_a <= a_sub_q[P_WIDTH : 1];
            end else begin                        // a < 0
                out_a <= a_add_q[P_WIDTH : 1];
            end
        end


        if (state == 0) begin
            if (b > 5376) begin
                out_b <= b - Q;
            end else if (b < -5376) begin
                out_b <= b + Q;
            end else begin
                out_b <= b;
            end
        end else begin
            if (b[0] == 0) begin
                out_b <= b[P_WIDTH : 1];
            end else if (b[P_WIDTH] == 0) begin   // b > 0
                out_b <= b_sub_q[P_WIDTH : 1];
            end else begin                        // b < 0
                out_b <= b_add_q[P_WIDTH : 1];
            end
        end
    end

endmodule
*/

module bfu_7681 (clk, state, in_a, in_b, w, bw, out_a, out_b);

    parameter P_WIDTH = 14;
    parameter PP_WIDTH = 25;
    parameter Q = 7681;

    input                      clk;
    input                      state;
    input      signed [13 : 0] in_a;
    input      signed [13 : 0] in_b;
    input      signed [14 : 0] w;
    output reg signed [28 : 0] bw;
    output reg signed [13 : 0] out_a;
    output reg signed [13 : 0] out_b;

    wire signed [12 : 0] mod_bw;
    reg signed [14 : 0] a, b;
    reg signed [13 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

    reg signed [28 : 0] bwQ_0, bwQ_1, bwQ_2;
    wire signed [14  : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

    //wire signed [12 : 0] mod_bw_test;

    modmul7681s mod7681 (clk, bw, mod_bw);

    //wire test;
    //assign test = (mod_bw == mod_bw_test) ? 0 : 1;

    //assign bwQ = bw % Q;
    assign a_add_q = a + Q;
    assign a_sub_q = a - Q;
    assign b_add_q = b + Q;
    assign b_sub_q = b - Q;
    
    
    // in_a shift
    always @(posedge clk ) begin
        in_a_s1 <= in_a;
        in_a_s2 <= in_a_s1;
        in_a_s3 <= in_a_s2;
        in_a_s4 <= in_a_s3;
        in_a_s5 <= in_a_s4;
    end

    // b * w
    always @(posedge clk ) begin
        bw <= in_b * w;
        
        /*
        bwQ_0 <= bw % Q;
        bwQ_1 <= bwQ_0;
        
        if (bwQ_1 > 3840) begin
            mod_bw <= bwQ_1 - Q;
        end else if (bwQ_1 < -3840) begin
            mod_bw <= bwQ_1 + Q;
        end else begin
            mod_bw <= bwQ_1;
        end    
        */
    end

    // out_a, out_b
    always @(posedge clk ) begin
        //a <= in_a_s2 + mod_bw;
        //b <= in_a_s2 - mod_bw;

        a <= in_a_s4 + mod_bw;
        b <= in_a_s4 - mod_bw;

        if (state == 0) begin
            if (a > 3840) begin
                out_a <= a_sub_q;
            end else if (a < -3840) begin
                out_a <= a_add_q;
            end else begin
                out_a <= a;
            end
        end else begin
            if (a[0] == 0) begin
                out_a <= a[P_WIDTH : 1];
            end else if (a[P_WIDTH] == 0) begin   // a > 0
                out_a <= a_sub_q[P_WIDTH : 1];
            end else begin                        // a < 0
                out_a <= a_add_q[P_WIDTH : 1];
            end
        end


        if (state == 0) begin
            if (b > 3840) begin
                out_b <= b - Q;
            end else if (b < -3840) begin
                out_b <= b + Q;
            end else begin
                out_b <= b;
            end
        end else begin
            if (b[0] == 0) begin
                out_b <= b[P_WIDTH : 1];
            end else if (b[P_WIDTH] == 0) begin   // b > 0
                out_b <= b_sub_q[P_WIDTH : 1];
            end else begin                        // b < 0
                out_b <= b_add_q[P_WIDTH : 1];
            end
        end
    end

endmodule

module bfu_10753 (clk, state, in_a, in_b, w, bw, out_a, out_b);

    parameter P_WIDTH = 14;
    parameter PP_WIDTH = 25;
    parameter Q = 10753;

    input                                clk;
    input                                state;
    input      signed [13 : 0] in_a;
    input      signed [13 : 0] in_b;
    input      signed [14 : 0] w;
    output reg signed [28 : 0] bw;
    output reg signed [13 : 0] out_a;
    output reg signed [13 : 0] out_b;

    wire signed [13 : 0] mod_bw;
    reg signed [14 : 0] a, b;
    reg signed [13 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

    reg signed [28 : 0] bwQ_0, bwQ_1, bwQ_2;
    wire signed [14  : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

    modmul10753s mod10753 (clk, bw, mod_bw);

    //assign bwQ = bw % Q;
    assign a_add_q = a + Q;
    assign a_sub_q = a - Q;
    assign b_add_q = b + Q;
    assign b_sub_q = b - Q;
    
    
    // in_a shift
    always @(posedge clk ) begin
        in_a_s1 <= in_a;
        in_a_s2 <= in_a_s1;
        in_a_s3 <= in_a_s2;
        in_a_s4 <= in_a_s3;
        in_a_s5 <= in_a_s4;
    end

    // b * w
    always @(posedge clk ) begin
        bw <= in_b * w;
        /*
        bwQ_0 <= bw % Q;
        bwQ_1 <= bwQ_0;
        bwQ_2 <= bwQ_1;

        if (bwQ_1 > 5376) begin
            mod_bw <= bwQ_1 - Q;
        end else if (bwQ_1 < -5376) begin
            mod_bw <= bwQ_1 + Q;
        end else begin
            mod_bw <= bwQ_1;
        end     
        */   
    end

    // out_a, out_b
    always @(posedge clk ) begin
        //a <= in_a_s2 + mod_bw;
        //b <= in_a_s2 - mod_bw;

        a <= in_a_s4 + mod_bw;
        b <= in_a_s4 - mod_bw;

        if (state == 0) begin
            if (a > 5376) begin
                out_a <= a_sub_q;
            end else if (a < -5376) begin
                out_a <= a_add_q;
            end else begin
                out_a <= a;
            end
        end else begin
            if (a[0] == 0) begin
                out_a <= a[P_WIDTH : 1];
            end else if (a[P_WIDTH] == 0) begin   // a > 0
                out_a <= a_sub_q[P_WIDTH : 1];
            end else begin                        // a < 0
                out_a <= a_add_q[P_WIDTH : 1];
            end
        end


        if (state == 0) begin
            if (b > 5376) begin
                out_b <= b - Q;
            end else if (b < -5376) begin
                out_b <= b + Q;
            end else begin
                out_b <= b;
            end
        end else begin
            if (b[0] == 0) begin
                out_b <= b[P_WIDTH : 1];
            end else if (b[P_WIDTH] == 0) begin   // b > 0
                out_b <= b_sub_q[P_WIDTH : 1];
            end else begin                        // b < 0
                out_b <= b_add_q[P_WIDTH : 1];
            end
        end
    end

endmodule

module addr_gen (clk, stage, ctr, bank_index, data_index);
    
    input              clk;
    input      [3 : 0] stage;  // 0 - 8
    input      [8 : 0] ctr;    // 0 - 511
    output reg         bank_index; // 0 - 1
    output reg [7 : 0] data_index; // 0 - 255

    wire [8 : 0] bs_out;

    barrel_shifter bs (clk, ctr, stage, bs_out);

    // bank_index
    always @(posedge clk ) begin
        bank_index <= ^bs_out;
    end

    // data_index
    always @(posedge clk ) begin
        data_index <= bs_out[8 : 1];
    end

endmodule

module barrel_shifter (clk, in, shift, out);
    
    input              clk;
    input      [8 : 0] in;
    input      [3 : 0] shift;
    output reg [8 : 0] out;

    reg [8 : 0] in_s0, in_s1, in_s2;

    // shift 4
    always @(* ) begin
        if (shift[2]) begin
            in_s2 = {in[3:0], in[8:4]};
        end else begin
            in_s2 = in;
        end
    end

    // shift 2
    always @(* ) begin
        if (shift[1]) begin
            in_s1 = {in_s2[1:0], in_s2[8:2]};
        end else begin
            in_s1 = in_s2;
        end
    end

    // shift 1
    always @(* ) begin
        if (shift[0]) begin
            in_s0 = {in_s1[0], in_s1[8:1]};
        end else begin
            in_s0 = in_s1;
        end
    end

    // out
    always @(posedge clk ) begin
        if (shift[3]) begin
            out <= {in[7:0], in[8]};
        end else begin
            out <= in_s0;
        end
    end
    
endmodule

module w_7681 ( clk, addr, dout);
    
    input  clk;
    input  [8 : 0] addr;
    output [13 : 0] dout;

    reg [8 : 0] a;
    (* rom_style = "block" *) reg [13 : 0] data [0 : 511];

    assign dout = data[a];

    always @(posedge clk) begin
        a <= addr;
    end

    always @(posedge clk) begin
        data[0] <= 1;
        data[1] <= 62;
        data[2] <= -3837;
        data[3] <= 217;
        data[4] <= -1908;
        data[5] <= -3081;
        data[6] <= 1003;
        data[7] <= 738;
        data[8] <= -330;
        data[9] <= 2583;
        data[10] <= -1155;
        data[11] <= -2481;
        data[12] <= -202;
        data[13] <= 2838;
        data[14] <= -707;
        data[15] <= 2252;
        data[16] <= 1366;
        data[17] <= 201;
        data[18] <= -2900;
        data[19] <= -3137;
        data[20] <= -2469;
        data[21] <= 542;
        data[22] <= 2880;
        data[23] <= 1897;
        data[24] <= 2399;
        data[25] <= 2799;
        data[26] <= -3125;
        data[27] <= -1725;
        data[28] <= 584;
        data[29] <= -2197;
        data[30] <= 2044;
        data[31] <= 3832;
        data[32] <= -527;
        data[33] <= -1950;
        data[34] <= 1996;
        data[35] <= 856;
        data[36] <= -695;
        data[37] <= 2996;
        data[38] <= 1408;
        data[39] <= 2805;
        data[40] <= -2753;
        data[41] <= -1704;
        data[42] <= 1886;
        data[43] <= 1717;
        data[44] <= -1080;
        data[45] <= 2169;
        data[46] <= -3780;
        data[47] <= 3751;
        data[48] <= 2132;
        data[49] <= 1607;
        data[50] <= -219;
        data[51] <= 1784;
        data[52] <= 3074;
        data[53] <= -1437;
        data[54] <= 3078;
        data[55] <= -1189;
        data[56] <= 3092;
        data[57] <= -321;
        data[58] <= 3141;
        data[59] <= 2717;
        data[60] <= -528;
        data[61] <= -2012;
        data[62] <= -1848;
        data[63] <= 639;
        data[64] <= 1213;
        data[65] <= -1604;
        data[66] <= 405;
        data[67] <= 2067;
        data[68] <= -2423;
        data[69] <= 3394;
        data[70] <= 3041;
        data[71] <= -3483;
        data[72] <= -878;
        data[73] <= -669;
        data[74] <= -3073;
        data[75] <= 1499;
        data[76] <= 766;
        data[77] <= 1406;
        data[78] <= 2681;
        data[79] <= -2760;
        data[80] <= -2138;
        data[81] <= -1979;
        data[82] <= 198;
        data[83] <= -3086;
        data[84] <= 693;
        data[85] <= -3120;
        data[86] <= -1415;
        data[87] <= -3239;
        data[88] <= -1112;
        data[89] <= 185;
        data[90] <= 3789;
        data[91] <= -3193;
        data[92] <= 1740;
        data[93] <= 346;
        data[94] <= -1591;
        data[95] <= 1211;
        data[96] <= -1728;
        data[97] <= 398;
        data[98] <= 1633;
        data[99] <= 1393;
        data[100] <= 1875;
        data[101] <= 1035;
        data[102] <= 2722;
        data[103] <= -218;
        data[104] <= 1846;
        data[105] <= -763;
        data[106] <= -1220;
        data[107] <= 1170;
        data[108] <= 3411;
        data[109] <= -3586;
        data[110] <= 417;
        data[111] <= 2811;
        data[112] <= -2381;
        data[113] <= -1683;
        data[114] <= 3188;
        data[115] <= -2050;
        data[116] <= 3477;
        data[117] <= 506;
        data[118] <= 648;
        data[119] <= 1771;
        data[120] <= 2268;
        data[121] <= 2358;
        data[122] <= 257;
        data[123] <= 572;
        data[124] <= -2941;
        data[125] <= 2002;
        data[126] <= 1228;
        data[127] <= -674;
        data[128] <= -3383;
        data[129] <= -2359;
        data[130] <= -319;
        data[131] <= 3265;
        data[132] <= 2724;
        data[133] <= -94;
        data[134] <= 1853;
        data[135] <= -329;
        data[136] <= 2645;
        data[137] <= 2689;
        data[138] <= -2264;
        data[139] <= -2110;
        data[140] <= -243;
        data[141] <= 296;
        data[142] <= 2990;
        data[143] <= 1036;
        data[144] <= 2784;
        data[145] <= 3626;
        data[146] <= 2063;
        data[147] <= -2671;
        data[148] <= 3380;
        data[149] <= 2173;
        data[150] <= -3532;
        data[151] <= 3765;
        data[152] <= 3000;
        data[153] <= 1656;
        data[154] <= 2819;
        data[155] <= -1885;
        data[156] <= -1655;
        data[157] <= -2757;
        data[158] <= -1952;
        data[159] <= 1872;
        data[160] <= 849;
        data[161] <= -1129;
        data[162] <= -869;
        data[163] <= -111;
        data[164] <= 799;
        data[165] <= 3452;
        data[166] <= -1044;
        data[167] <= -3280;
        data[168] <= -3654;
        data[169] <= -3799;
        data[170] <= 2573;
        data[171] <= -1775;
        data[172] <= -2516;
        data[173] <= -2372;
        data[174] <= -1125;
        data[175] <= -621;
        data[176] <= -97;
        data[177] <= 1667;
        data[178] <= 3501;
        data[179] <= 1994;
        data[180] <= 732;
        data[181] <= -702;
        data[182] <= 2562;
        data[183] <= -2457;
        data[184] <= 1286;
        data[185] <= 2922;
        data[186] <= -3180;
        data[187] <= 2546;
        data[188] <= -3449;
        data[189] <= 1230;
        data[190] <= -550;
        data[191] <= -3376;
        data[192] <= -1925;
        data[193] <= 3546;
        data[194] <= -2897;
        data[195] <= -2951;
        data[196] <= 1382;
        data[197] <= 1193;
        data[198] <= -2844;
        data[199] <= 335;
        data[200] <= -2273;
        data[201] <= -2668;
        data[202] <= 3566;
        data[203] <= -1657;
        data[204] <= -2881;
        data[205] <= -1959;
        data[206] <= 1438;
        data[207] <= -3016;
        data[208] <= -2648;
        data[209] <= -2875;
        data[210] <= -1587;
        data[211] <= 1459;
        data[212] <= -1714;
        data[213] <= 1266;
        data[214] <= 1682;
        data[215] <= -3250;
        data[216] <= -1794;
        data[217] <= -3694;
        data[218] <= 1402;
        data[219] <= 2433;
        data[220] <= -2774;
        data[221] <= -3006;
        data[222] <= -2028;
        data[223] <= -2840;
        data[224] <= 583;
        data[225] <= -2259;
        data[226] <= -1800;
        data[227] <= 3615;
        data[228] <= 1381;
        data[229] <= 1131;
        data[230] <= 993;
        data[231] <= 118;
        data[232] <= -365;
        data[233] <= 413;
        data[234] <= 2563;
        data[235] <= -2395;
        data[236] <= -2551;
        data[237] <= 3139;
        data[238] <= 2593;
        data[239] <= -535;
        data[240] <= -2446;
        data[241] <= 1968;
        data[242] <= -880;
        data[243] <= -793;
        data[244] <= -3080;
        data[245] <= 1065;
        data[246] <= -3099;
        data[247] <= -113;
        data[248] <= 675;
        data[249] <= 3445;
        data[250] <= -1478;
        data[251] <= 536;
        data[252] <= 2508;
        data[253] <= 1876;
        data[254] <= 1097;
        data[255] <= -1115;
        data[256] <= -1;
        data[257] <= -62;
        data[258] <= 3837;
        data[259] <= -217;
        data[260] <= 1908;
        data[261] <= 3081;
        data[262] <= -1003;
        data[263] <= -738;
        data[264] <= 330;
        data[265] <= -2583;
        data[266] <= 1155;
        data[267] <= 2481;
        data[268] <= 202;
        data[269] <= -2838;
        data[270] <= 707;
        data[271] <= -2252;
        data[272] <= -1366;
        data[273] <= -201;
        data[274] <= 2900;
        data[275] <= 3137;
        data[276] <= 2469;
        data[277] <= -542;
        data[278] <= -2880;
        data[279] <= -1897;
        data[280] <= -2399;
        data[281] <= -2799;
        data[282] <= 3125;
        data[283] <= 1725;
        data[284] <= -584;
        data[285] <= 2197;
        data[286] <= -2044;
        data[287] <= -3832;
        data[288] <= 527;
        data[289] <= 1950;
        data[290] <= -1996;
        data[291] <= -856;
        data[292] <= 695;
        data[293] <= -2996;
        data[294] <= -1408;
        data[295] <= -2805;
        data[296] <= 2753;
        data[297] <= 1704;
        data[298] <= -1886;
        data[299] <= -1717;
        data[300] <= 1080;
        data[301] <= -2169;
        data[302] <= 3780;
        data[303] <= -3751;
        data[304] <= -2132;
        data[305] <= -1607;
        data[306] <= 219;
        data[307] <= -1784;
        data[308] <= -3074;
        data[309] <= 1437;
        data[310] <= -3078;
        data[311] <= 1189;
        data[312] <= -3092;
        data[313] <= 321;
        data[314] <= -3141;
        data[315] <= -2717;
        data[316] <= 528;
        data[317] <= 2012;
        data[318] <= 1848;
        data[319] <= -639;
        data[320] <= -1213;
        data[321] <= 1604;
        data[322] <= -405;
        data[323] <= -2067;
        data[324] <= 2423;
        data[325] <= -3394;
        data[326] <= -3041;
        data[327] <= 3483;
        data[328] <= 878;
        data[329] <= 669;
        data[330] <= 3073;
        data[331] <= -1499;
        data[332] <= -766;
        data[333] <= -1406;
        data[334] <= -2681;
        data[335] <= 2760;
        data[336] <= 2138;
        data[337] <= 1979;
        data[338] <= -198;
        data[339] <= 3086;
        data[340] <= -693;
        data[341] <= 3120;
        data[342] <= 1415;
        data[343] <= 3239;
        data[344] <= 1112;
        data[345] <= -185;
        data[346] <= -3789;
        data[347] <= 3193;
        data[348] <= -1740;
        data[349] <= -346;
        data[350] <= 1591;
        data[351] <= -1211;
        data[352] <= 1728;
        data[353] <= -398;
        data[354] <= -1633;
        data[355] <= -1393;
        data[356] <= -1875;
        data[357] <= -1035;
        data[358] <= -2722;
        data[359] <= 218;
        data[360] <= -1846;
        data[361] <= 763;
        data[362] <= 1220;
        data[363] <= -1170;
        data[364] <= -3411;
        data[365] <= 3586;
        data[366] <= -417;
        data[367] <= -2811;
        data[368] <= 2381;
        data[369] <= 1683;
        data[370] <= -3188;
        data[371] <= 2050;
        data[372] <= -3477;
        data[373] <= -506;
        data[374] <= -648;
        data[375] <= -1771;
        data[376] <= -2268;
        data[377] <= -2358;
        data[378] <= -257;
        data[379] <= -572;
        data[380] <= 2941;
        data[381] <= -2002;
        data[382] <= -1228;
        data[383] <= 674;
        data[384] <= 3383;
        data[385] <= 2359;
        data[386] <= 319;
        data[387] <= -3265;
        data[388] <= -2724;
        data[389] <= 94;
        data[390] <= -1853;
        data[391] <= 329;
        data[392] <= -2645;
        data[393] <= -2689;
        data[394] <= 2264;
        data[395] <= 2110;
        data[396] <= 243;
        data[397] <= -296;
        data[398] <= -2990;
        data[399] <= -1036;
        data[400] <= -2784;
        data[401] <= -3626;
        data[402] <= -2063;
        data[403] <= 2671;
        data[404] <= -3380;
        data[405] <= -2173;
        data[406] <= 3532;
        data[407] <= -3765;
        data[408] <= -3000;
        data[409] <= -1656;
        data[410] <= -2819;
        data[411] <= 1885;
        data[412] <= 1655;
        data[413] <= 2757;
        data[414] <= 1952;
        data[415] <= -1872;
        data[416] <= -849;
        data[417] <= 1129;
        data[418] <= 869;
        data[419] <= 111;
        data[420] <= -799;
        data[421] <= -3452;
        data[422] <= 1044;
        data[423] <= 3280;
        data[424] <= 3654;
        data[425] <= 3799;
        data[426] <= -2573;
        data[427] <= 1775;
        data[428] <= 2516;
        data[429] <= 2372;
        data[430] <= 1125;
        data[431] <= 621;
        data[432] <= 97;
        data[433] <= -1667;
        data[434] <= -3501;
        data[435] <= -1994;
        data[436] <= -732;
        data[437] <= 702;
        data[438] <= -2562;
        data[439] <= 2457;
        data[440] <= -1286;
        data[441] <= -2922;
        data[442] <= 3180;
        data[443] <= -2546;
        data[444] <= 3449;
        data[445] <= -1230;
        data[446] <= 550;
        data[447] <= 3376;
        data[448] <= 1925;
        data[449] <= -3546;
        data[450] <= 2897;
        data[451] <= 2951;
        data[452] <= -1382;
        data[453] <= -1193;
        data[454] <= 2844;
        data[455] <= -335;
        data[456] <= 2273;
        data[457] <= 2668;
        data[458] <= -3566;
        data[459] <= 1657;
        data[460] <= 2881;
        data[461] <= 1959;
        data[462] <= -1438;
        data[463] <= 3016;
        data[464] <= 2648;
        data[465] <= 2875;
        data[466] <= 1587;
        data[467] <= -1459;
        data[468] <= 1714;
        data[469] <= -1266;
        data[470] <= -1682;
        data[471] <= 3250;
        data[472] <= 1794;
        data[473] <= 3694;
        data[474] <= -1402;
        data[475] <= -2433;
        data[476] <= 2774;
        data[477] <= 3006;
        data[478] <= 2028;
        data[479] <= 2840;
        data[480] <= -583;
        data[481] <= 2259;
        data[482] <= 1800;
        data[483] <= -3615;
        data[484] <= -1381;
        data[485] <= -1131;
        data[486] <= -993;
        data[487] <= -118;
        data[488] <= 365;
        data[489] <= -413;
        data[490] <= -2563;
        data[491] <= 2395;
        data[492] <= 2551;
        data[493] <= -3139;
        data[494] <= -2593;
        data[495] <= 535;
        data[496] <= 2446;
        data[497] <= -1968;
        data[498] <= 880;
        data[499] <= 793;
        data[500] <= 3080;
        data[501] <= -1065;
        data[502] <= 3099;
        data[503] <= 113;
        data[504] <= -675;
        data[505] <= -3445;
        data[506] <= 1478;
        data[507] <= -536;
        data[508] <= -2508;
        data[509] <= -1876;
        data[510] <= -1097;
        data[511] <= 1115;
    end

endmodule

module w_10753 ( clk, addr, dout);
    
    input  clk;
    input  [8 : 0] addr;
    output [13 : 0] dout;

    reg [8 : 0] a;
    (* rom_style = "block" *) reg [13 : 0] data [0 : 511];

    assign dout = data[a];

    always @(posedge clk) begin
        a <= addr;
    end

    always @(posedge clk) begin
        data[0] <= 1;
        data[1] <= 10;
        data[2] <= 100;
        data[3] <= 1000;
        data[4] <= -753;
        data[5] <= 3223;
        data[6] <= -29;
        data[7] <= -290;
        data[8] <= -2900;
        data[9] <= 3259;
        data[10] <= 331;
        data[11] <= 3310;
        data[12] <= 841;
        data[13] <= -2343;
        data[14] <= -1924;
        data[15] <= 2266;
        data[16] <= 1154;
        data[17] <= 787;
        data[18] <= -2883;
        data[19] <= 3429;
        data[20] <= 2031;
        data[21] <= -1196;
        data[22] <= -1207;
        data[23] <= -1317;
        data[24] <= -2417;
        data[25] <= -2664;
        data[26] <= -5134;
        data[27] <= 2425;
        data[28] <= 2744;
        data[29] <= -4819;
        data[30] <= -5178;
        data[31] <= 1985;
        data[32] <= -1656;
        data[33] <= 4946;
        data[34] <= -4305;
        data[35] <= -38;
        data[36] <= -380;
        data[37] <= -3800;
        data[38] <= 5012;
        data[39] <= -3645;
        data[40] <= -4191;
        data[41] <= 1102;
        data[42] <= 267;
        data[43] <= 2670;
        data[44] <= 5194;
        data[45] <= -1825;
        data[46] <= 3256;
        data[47] <= 301;
        data[48] <= 3010;
        data[49] <= -2159;
        data[50] <= -84;
        data[51] <= -840;
        data[52] <= 2353;
        data[53] <= 2024;
        data[54] <= -1266;
        data[55] <= -1907;
        data[56] <= 2436;
        data[57] <= 2854;
        data[58] <= -3719;
        data[59] <= -4931;
        data[60] <= 4455;
        data[61] <= 1538;
        data[62] <= 4627;
        data[63] <= 3258;
        data[64] <= 321;
        data[65] <= 3210;
        data[66] <= -159;
        data[67] <= -1590;
        data[68] <= -5147;
        data[69] <= 2295;
        data[70] <= 1444;
        data[71] <= 3687;
        data[72] <= 4611;
        data[73] <= 3098;
        data[74] <= -1279;
        data[75] <= -2037;
        data[76] <= 1136;
        data[77] <= 607;
        data[78] <= -4683;
        data[79] <= -3818;
        data[80] <= 4832;
        data[81] <= 5308;
        data[82] <= -685;
        data[83] <= 3903;
        data[84] <= -3982;
        data[85] <= 3192;
        data[86] <= -339;
        data[87] <= -3390;
        data[88] <= -1641;
        data[89] <= 5096;
        data[90] <= -2805;
        data[91] <= 4209;
        data[92] <= -922;
        data[93] <= 1533;
        data[94] <= 4577;
        data[95] <= 2758;
        data[96] <= -4679;
        data[97] <= -3778;
        data[98] <= 5232;
        data[99] <= -1445;
        data[100] <= -3697;
        data[101] <= -4711;
        data[102] <= -4098;
        data[103] <= 2032;
        data[104] <= -1186;
        data[105] <= -1107;
        data[106] <= -317;
        data[107] <= -3170;
        data[108] <= 559;
        data[109] <= -5163;
        data[110] <= 2135;
        data[111] <= -156;
        data[112] <= -1560;
        data[113] <= -4847;
        data[114] <= 5295;
        data[115] <= -815;
        data[116] <= 2603;
        data[117] <= 4524;
        data[118] <= 2228;
        data[119] <= 774;
        data[120] <= -3013;
        data[121] <= 2129;
        data[122] <= -216;
        data[123] <= -2160;
        data[124] <= -94;
        data[125] <= -940;
        data[126] <= 1353;
        data[127] <= 2777;
        data[128] <= -4489;
        data[129] <= -1878;
        data[130] <= 2726;
        data[131] <= -4999;
        data[132] <= 3775;
        data[133] <= -5262;
        data[134] <= 1145;
        data[135] <= 697;
        data[136] <= -3783;
        data[137] <= 5182;
        data[138] <= -1945;
        data[139] <= 2056;
        data[140] <= -946;
        data[141] <= 1293;
        data[142] <= 2177;
        data[143] <= 264;
        data[144] <= 2640;
        data[145] <= 4894;
        data[146] <= -4825;
        data[147] <= -5238;
        data[148] <= 1385;
        data[149] <= 3097;
        data[150] <= -1289;
        data[151] <= -2137;
        data[152] <= 136;
        data[153] <= 1360;
        data[154] <= 2847;
        data[155] <= -3789;
        data[156] <= 5122;
        data[157] <= -2545;
        data[158] <= -3944;
        data[159] <= 3572;
        data[160] <= 3461;
        data[161] <= 2351;
        data[162] <= 2004;
        data[163] <= -1466;
        data[164] <= -3907;
        data[165] <= 3942;
        data[166] <= -3592;
        data[167] <= -3661;
        data[168] <= -4351;
        data[169] <= -498;
        data[170] <= -4980;
        data[171] <= 3965;
        data[172] <= -3362;
        data[173] <= -1361;
        data[174] <= -2857;
        data[175] <= 3689;
        data[176] <= 4631;
        data[177] <= 3298;
        data[178] <= 721;
        data[179] <= -3543;
        data[180] <= -3171;
        data[181] <= 549;
        data[182] <= -5263;
        data[183] <= 1135;
        data[184] <= 597;
        data[185] <= -4783;
        data[186] <= -4818;
        data[187] <= -5168;
        data[188] <= 2085;
        data[189] <= -656;
        data[190] <= 4193;
        data[191] <= -1082;
        data[192] <= -67;
        data[193] <= -670;
        data[194] <= 4053;
        data[195] <= -2482;
        data[196] <= -3314;
        data[197] <= -881;
        data[198] <= 1943;
        data[199] <= -2076;
        data[200] <= 746;
        data[201] <= -3293;
        data[202] <= -671;
        data[203] <= 4043;
        data[204] <= -2582;
        data[205] <= -4314;
        data[206] <= -128;
        data[207] <= -1280;
        data[208] <= -2047;
        data[209] <= 1036;
        data[210] <= -393;
        data[211] <= -3930;
        data[212] <= 3712;
        data[213] <= 4861;
        data[214] <= -5155;
        data[215] <= 2215;
        data[216] <= 644;
        data[217] <= -4313;
        data[218] <= -118;
        data[219] <= -1180;
        data[220] <= -1047;
        data[221] <= 283;
        data[222] <= 2830;
        data[223] <= -3959;
        data[224] <= 3422;
        data[225] <= 1961;
        data[226] <= -1896;
        data[227] <= 2546;
        data[228] <= 3954;
        data[229] <= -3472;
        data[230] <= -2461;
        data[231] <= -3104;
        data[232] <= 1219;
        data[233] <= 1437;
        data[234] <= 3617;
        data[235] <= 3911;
        data[236] <= -3902;
        data[237] <= 3992;
        data[238] <= -3092;
        data[239] <= 1339;
        data[240] <= 2637;
        data[241] <= 4864;
        data[242] <= -5125;
        data[243] <= 2515;
        data[244] <= 3644;
        data[245] <= 4181;
        data[246] <= -1202;
        data[247] <= -1267;
        data[248] <= -1917;
        data[249] <= 2336;
        data[250] <= 1854;
        data[251] <= -2966;
        data[252] <= 2599;
        data[253] <= 4484;
        data[254] <= 1828;
        data[255] <= -3226;
        data[256] <= -1;
        data[257] <= -10;
        data[258] <= -100;
        data[259] <= -1000;
        data[260] <= 753;
        data[261] <= -3223;
        data[262] <= 29;
        data[263] <= 290;
        data[264] <= 2900;
        data[265] <= -3259;
        data[266] <= -331;
        data[267] <= -3310;
        data[268] <= -841;
        data[269] <= 2343;
        data[270] <= 1924;
        data[271] <= -2266;
        data[272] <= -1154;
        data[273] <= -787;
        data[274] <= 2883;
        data[275] <= -3429;
        data[276] <= -2031;
        data[277] <= 1196;
        data[278] <= 1207;
        data[279] <= 1317;
        data[280] <= 2417;
        data[281] <= 2664;
        data[282] <= 5134;
        data[283] <= -2425;
        data[284] <= -2744;
        data[285] <= 4819;
        data[286] <= 5178;
        data[287] <= -1985;
        data[288] <= 1656;
        data[289] <= -4946;
        data[290] <= 4305;
        data[291] <= 38;
        data[292] <= 380;
        data[293] <= 3800;
        data[294] <= -5012;
        data[295] <= 3645;
        data[296] <= 4191;
        data[297] <= -1102;
        data[298] <= -267;
        data[299] <= -2670;
        data[300] <= -5194;
        data[301] <= 1825;
        data[302] <= -3256;
        data[303] <= -301;
        data[304] <= -3010;
        data[305] <= 2159;
        data[306] <= 84;
        data[307] <= 840;
        data[308] <= -2353;
        data[309] <= -2024;
        data[310] <= 1266;
        data[311] <= 1907;
        data[312] <= -2436;
        data[313] <= -2854;
        data[314] <= 3719;
        data[315] <= 4931;
        data[316] <= -4455;
        data[317] <= -1538;
        data[318] <= -4627;
        data[319] <= -3258;
        data[320] <= -321;
        data[321] <= -3210;
        data[322] <= 159;
        data[323] <= 1590;
        data[324] <= 5147;
        data[325] <= -2295;
        data[326] <= -1444;
        data[327] <= -3687;
        data[328] <= -4611;
        data[329] <= -3098;
        data[330] <= 1279;
        data[331] <= 2037;
        data[332] <= -1136;
        data[333] <= -607;
        data[334] <= 4683;
        data[335] <= 3818;
        data[336] <= -4832;
        data[337] <= -5308;
        data[338] <= 685;
        data[339] <= -3903;
        data[340] <= 3982;
        data[341] <= -3192;
        data[342] <= 339;
        data[343] <= 3390;
        data[344] <= 1641;
        data[345] <= -5096;
        data[346] <= 2805;
        data[347] <= -4209;
        data[348] <= 922;
        data[349] <= -1533;
        data[350] <= -4577;
        data[351] <= -2758;
        data[352] <= 4679;
        data[353] <= 3778;
        data[354] <= -5232;
        data[355] <= 1445;
        data[356] <= 3697;
        data[357] <= 4711;
        data[358] <= 4098;
        data[359] <= -2032;
        data[360] <= 1186;
        data[361] <= 1107;
        data[362] <= 317;
        data[363] <= 3170;
        data[364] <= -559;
        data[365] <= 5163;
        data[366] <= -2135;
        data[367] <= 156;
        data[368] <= 1560;
        data[369] <= 4847;
        data[370] <= -5295;
        data[371] <= 815;
        data[372] <= -2603;
        data[373] <= -4524;
        data[374] <= -2228;
        data[375] <= -774;
        data[376] <= 3013;
        data[377] <= -2129;
        data[378] <= 216;
        data[379] <= 2160;
        data[380] <= 94;
        data[381] <= 940;
        data[382] <= -1353;
        data[383] <= -2777;
        data[384] <= 4489;
        data[385] <= 1878;
        data[386] <= -2726;
        data[387] <= 4999;
        data[388] <= -3775;
        data[389] <= 5262;
        data[390] <= -1145;
        data[391] <= -697;
        data[392] <= 3783;
        data[393] <= -5182;
        data[394] <= 1945;
        data[395] <= -2056;
        data[396] <= 946;
        data[397] <= -1293;
        data[398] <= -2177;
        data[399] <= -264;
        data[400] <= -2640;
        data[401] <= -4894;
        data[402] <= 4825;
        data[403] <= 5238;
        data[404] <= -1385;
        data[405] <= -3097;
        data[406] <= 1289;
        data[407] <= 2137;
        data[408] <= -136;
        data[409] <= -1360;
        data[410] <= -2847;
        data[411] <= 3789;
        data[412] <= -5122;
        data[413] <= 2545;
        data[414] <= 3944;
        data[415] <= -3572;
        data[416] <= -3461;
        data[417] <= -2351;
        data[418] <= -2004;
        data[419] <= 1466;
        data[420] <= 3907;
        data[421] <= -3942;
        data[422] <= 3592;
        data[423] <= 3661;
        data[424] <= 4351;
        data[425] <= 498;
        data[426] <= 4980;
        data[427] <= -3965;
        data[428] <= 3362;
        data[429] <= 1361;
        data[430] <= 2857;
        data[431] <= -3689;
        data[432] <= -4631;
        data[433] <= -3298;
        data[434] <= -721;
        data[435] <= 3543;
        data[436] <= 3171;
        data[437] <= -549;
        data[438] <= 5263;
        data[439] <= -1135;
        data[440] <= -597;
        data[441] <= 4783;
        data[442] <= 4818;
        data[443] <= 5168;
        data[444] <= -2085;
        data[445] <= 656;
        data[446] <= -4193;
        data[447] <= 1082;
        data[448] <= 67;
        data[449] <= 670;
        data[450] <= -4053;
        data[451] <= 2482;
        data[452] <= 3314;
        data[453] <= 881;
        data[454] <= -1943;
        data[455] <= 2076;
        data[456] <= -746;
        data[457] <= 3293;
        data[458] <= 671;
        data[459] <= -4043;
        data[460] <= 2582;
        data[461] <= 4314;
        data[462] <= 128;
        data[463] <= 1280;
        data[464] <= 2047;
        data[465] <= -1036;
        data[466] <= 393;
        data[467] <= 3930;
        data[468] <= -3712;
        data[469] <= -4861;
        data[470] <= 5155;
        data[471] <= -2215;
        data[472] <= -644;
        data[473] <= 4313;
        data[474] <= 118;
        data[475] <= 1180;
        data[476] <= 1047;
        data[477] <= -283;
        data[478] <= -2830;
        data[479] <= 3959;
        data[480] <= -3422;
        data[481] <= -1961;
        data[482] <= 1896;
        data[483] <= -2546;
        data[484] <= -3954;
        data[485] <= 3472;
        data[486] <= 2461;
        data[487] <= 3104;
        data[488] <= -1219;
        data[489] <= -1437;
        data[490] <= -3617;
        data[491] <= -3911;
        data[492] <= 3902;
        data[493] <= -3992;
        data[494] <= 3092;
        data[495] <= -1339;
        data[496] <= -2637;
        data[497] <= -4864;
        data[498] <= 5125;
        data[499] <= -2515;
        data[500] <= -3644;
        data[501] <= -4181;
        data[502] <= 1202;
        data[503] <= 1267;
        data[504] <= 1917;
        data[505] <= -2336;
        data[506] <= -1854;
        data[507] <= 2966;
        data[508] <= -2599;
        data[509] <= -4484;
        data[510] <= -1828;
        data[511] <= 3226;
    end

endmodule
