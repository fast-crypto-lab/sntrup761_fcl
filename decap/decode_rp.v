/******************************************************************* 
  NTRU Prime General R/q[x] / x^p - x - 1 Decoder

  Author: Bo-Yuan Peng bypeng@crypto.tw
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

`include "params.v"

module decode_rp ( clk, start, done, state_l, state_s,
    rp_rd_addr, rp_rd_data,
    cd_wr_addr, cd_wr_data, cd_wr_en,
    state_max, param_r_max, param_ro_max,
    param_ri_offset, param_ro_offset,
    param_m0, param_m0inv,
    param_r_s1, param_r_sl,
    param_outs1, param_outsl, param_outsl_first, param_outoffset 
) ; 

    input                           clk;
    input                           start;
    output                          done;
    output      [4:0]               state_l;
    output      [4:0]               state_s;

    output      [`OUT_DEPTH-1:0]    rp_rd_addr;
    input       [`OUT_D_SIZE-1:0]   rp_rd_data;
    output      [`RP_DEPTH-1:0]     cd_wr_addr;
    output reg  [`RP_D_SIZE-1:0]    cd_wr_data;
    output                          cd_wr_en;

    input       [4:0]               state_max;
    input       [`RP_DEPTH-2:0]     param_r_max;
    input       [`RP_DEPTH-1:0]     param_ro_max;

    input       [`RP_D_SIZE-1:0]    param_m0;
    input       [`RP_INV_SIZE-1:0]  param_m0inv;
    input       [`RP_DEPTH-2:0]     param_ri_offset;
    input       [`RP_DEPTH-2:0]     param_ro_offset;
    input       [1:0]               param_outs1;
    input       [1:0]               param_outsl;
    input       [1:0]               param_outsl_first;
    input       [1:0]               param_r_s1;
    input       [1:0]               param_r_sl;
    input       [`OUT_DEPTH-1:0]    param_outoffset;

    wire                            rb_wr_en;
    wire        [`RP_DEPTH-2:0]     rb_wr_addr;
    reg         [`RP_D_SIZE-1:0]    rb_wr_data;
    wire        [`RP_DEPTH-2:0]     rb_rd_addr;
    wire        [`RP_D_SIZE-1:0]    rb_rd_data;

    reg         [4:0]               state[4:0];
    reg         [4:0]               state_next;
    reg         [1:0]               state_ct[3:0];
    wire        [1:0]               sc_l;
    wire        [1:0]               sc_s;

    reg         [`RP_DEPTH-2:0]     state_l_addr;
    reg         [`OUT_DEPTH-1:0]    o_addr;
    reg         [`RP_DEPTH-1:0]     r_addr;

    wire                            state_s_ismax;
    wire                            state_s_isnotmax;
    wire                            state_s_final;
    wire                            rb_rd_addr_max;
    wire                            rb_wr_addr_max;
    wire                            cd_wr_addr_max;
    wire                            wr_addr_max;
    wire                            load_o0;
    wire                            load_o1;
    wire                            write_r0;
    wire                            write_r1;

    reg         [`OUT_D_SIZE-1:0]   o0;
    reg         [`OUT_D_SIZE-1:0]   o1;
    reg         [`RP_D_SIZE-1:0]    r_prev;

    wire        [`RP_D_SIZE-1:0]    s0_o0;
    wire        [`RP_D_SIZE-1:0]    s0_o1o0;
    wire        [`RP_D_SIZE-1:0]    s0_r;
    wire        [`RP_D_SIZE2-1:0]   sl_rp_o0;
    wire        [`RP_D_SIZE2-1:0]   sl_rp_o1o0;
    wire        [`RP_D_SIZE2-1:0]   sl1_r;
    wire        [`RP_D_SIZE2-1:0]   sll_r;
    reg         [`RP_D_SIZE2-1:0]   sl_r;

    wire        [`RP_D_SIZE-1:0]    r0_next;
    wire        [`RP_D_SIZE-1:0]    r1_next;

    bram_n # ( .D_SIZE(`RP_D_SIZE), .Q_DEPTH(`RP_DEPTH-1) ) r_buffer (
        .clk(clk),
        .wr_en(rb_wr_en),
        .wr_addr(rb_wr_addr),
        .wr_din(rb_wr_data),
        .rd_addr(rb_rd_addr),
        .rd_dout(rb_rd_data)
    ) ;

    always @ ( posedge clk ) begin
        if(start) begin
            state[4] <= 5'd0;
            state[3] <= 5'd0;
            state[2] <= 5'd0;
            state[1] <= 5'd0;
            state[0] <= 5'd0;
        end else begin
            state[4] <= state_next;
            state[3] <= state[4];
            state[2] <= state[3];
            state[1] <= state[2];
            state[0] <= state[1];
        end
    end
    assign state_l = state[4];
    //assign state_l1 = state[3];
    assign state_s = state[1];
    //assign state_s1 = state[0];

    assign done = (state_l == 5'd31);

    always @ (*) begin
        if( ~|sc_l && rb_rd_addr_max ) begin
            if( (state_l == state_max) || done ) begin
                state_next = 5'd31;
            end else begin
                state_next = state_l + 5'd1;
            end
        end else begin
            state_next = state_l;
        end
    end

    always @ ( posedge clk ) begin
        if(start || ~|(state_ct[3])) begin
            state_ct[3] <= 2'd2;
        end else begin
            state_ct[3] <= state_ct[3] - 2'd1;
        end
        if(start) begin
            state_ct[2] <= 2'd2;
            state_ct[1] <= 2'd2;
            state_ct[0] <= 2'd2;
        end else begin
            state_ct[2] <= state_ct[3];
            state_ct[1] <= state_ct[2];
            state_ct[0] <= state_ct[1];
        end
    end
    assign sc_l = state_ct[3];
    assign sc_s = state_ct[0];

    always @ ( posedge clk ) begin
        if(start) begin
            state_l_addr <= { (`RP_DEPTH-1) {1'b0} };
        end else if(sc_l == 2'd0) begin
            if(rb_rd_addr_max) begin
                state_l_addr <= { (`RP_DEPTH-1) {1'b0} };
            end else begin
                state_l_addr <= state_l_addr + { { (`RP_DEPTH-2) {1'b0} }, 1'b1 };
            end
        end
    end
    assign rb_rd_addr = state_l_addr + param_ri_offset;
    assign rb_rd_addr_max = (rb_rd_addr == param_r_max);

    assign load_o0 = (sc_l == 2'd2) &&
                     (rb_rd_addr_max ? |param_outsl : |param_outs1 );
    assign load_o1 = (sc_l == 2'd1) &&
                     (rb_rd_addr_max ? (param_outsl == 2'd2) : (param_outs1 == 2'd2) );
    always @ ( posedge clk ) begin
        if(start || (rb_rd_addr_max && (sc_l == 2'b0))) begin
            o_addr <= { (`RP_DEPTH) {1'b0} };
        end else if(load_o0 || load_o1) begin
            o_addr <= o_addr + { { (`RP_DEPTH - 1) {1'b0} }, 1'b1 };
        end
    end
    assign rp_rd_addr = param_outoffset + o_addr;

    always @ ( posedge clk ) begin
        if(start) begin
            o0 <= { `OUT_D_SIZE {1'b0} };
            o1 <= { `OUT_D_SIZE {1'b0} };
            r_prev <= { `RP_D_SIZE {1'b0} };
        end else begin
            if(load_o0) begin
                o0 <= rp_rd_data;
            end
            if(load_o1) begin
                o1 <= rp_rd_data;
            end
            if(sc_l == 2'd1) begin
                r_prev <= rb_rd_data;
            end
        end
    end

    assign state_s_ismax = (state_s == state_max);
    assign state_s_isnotmax = !state_s_ismax;
    assign state_s_final = (state_s == 5'd31);
    assign write_r0 = (sc_s == 2'd1) &&
                      (wr_addr_max ? |param_r_sl : |param_r_s1 );
    assign write_r1 = (sc_s == 2'd0) &&
                      (wr_addr_max ? (param_r_sl == 2'd2) : (param_r_s1 == 2'd2) );
    assign rb_wr_en = state_s_isnotmax && (write_r0 || write_r1);
    assign cd_wr_en = state_s_ismax && (write_r0 || write_r1);
    always @ ( posedge clk ) begin
        if(start || (wr_addr_max && (sc_s == 2'b0))) begin
            r_addr <= { (`RP_DEPTH) {1'b0} };
        end else if(write_r0 || write_r1) begin
            r_addr <= r_addr + { { (`RP_DEPTH - 1) {1'b0} }, 1'b1 };
        end
    end
    assign rb_wr_addr = param_ro_offset + r_addr;
    assign rb_wr_addr_max = (rb_wr_addr == param_r_max) ||
                            (rb_wr_addr == param_r_max + 'd1);
    assign cd_wr_addr = r_addr;
    assign cd_wr_addr_max = (cd_wr_addr == param_ro_max) ||
                            (cd_wr_addr == param_ro_max + 'd1);
    assign wr_addr_max = state_s_ismax ? cd_wr_addr_max : rb_wr_addr_max;

    assign s0_o0      = { { (`RP_D_SIZE - `OUT_D_SIZE) {1'b0} }, o0 };
    assign s0_o1o0    = { o1[0 +: (`RP_D_SIZE - `OUT_D_SIZE)]  , o0 };
    assign s0_r       = param_outsl_first[1] ? s0_o1o0 : s0_o0;
    assign sl_rp_o0   = { { (`RP_D_SIZE - `OUT_D_SIZE) {1'b0} }, r_prev, o0 };
    assign sl_rp_o1o0 = { r_prev[0 +: (`RP_D_SIZE2 - 2*`OUT_D_SIZE)], o1, o0 };
    assign sl1_r      = param_outs1[1] ? sl_rp_o1o0 : sl_rp_o0;
    assign sll_r      = param_outsl[1] ? sl_rp_o1o0 : sl_rp_o0;

    always @ ( posedge clk ) begin
        if(start) begin
            sl_r <= { `RP_D_SIZE2 {1'b0} };        
        end else begin
            if(sc_l == 2'd0) begin
                if(rb_rd_addr_max) begin
                    sl_r <= sll_r;
                end else begin
                    sl_r <= sl1_r;
                end
            end
        end
    end

    barrett barrett0 (
        .dividend(sl_r),
        .m0(param_m0),
        .m0_inverse(param_m0inv),
        .quotient(r1_next),
        .remainder(r0_next)
    ) ;

    always @ ( posedge clk ) begin
        if(start) begin
            rb_wr_data <= { `RP_D_SIZE {1'b0} };
        end else begin
            if((state_s == 5'd0) && (sc_s == 2'd2)) begin
                rb_wr_data <= s0_r;
            end else if(state_s_isnotmax) begin
                if(sc_s == 2'd2) begin
                    if(rb_wr_addr != param_r_max) begin
                        rb_wr_data <= r0_next;
                    end else begin
                        rb_wr_data <= r_prev;
                    end
                end else if(sc_s == 2'd1) begin
                    rb_wr_data <= r1_next;
                end
            end
        end
    end

    always @ ( posedge clk ) begin
        if(start) begin
            cd_wr_data <= { `RP_D_SIZE {1'b0} };
        end else begin
            if(state_s_ismax) begin
                if(sc_s == 2'd2) begin
                    if( cd_wr_addr != param_ro_max ) begin
                        cd_wr_data <= r0_next;
                    end else begin
                        cd_wr_data <= r_prev;
                    end
                end else if(sc_s == 2'd1) begin
                    cd_wr_data <= r1_next;
                end
            end
        end
    end

endmodule
