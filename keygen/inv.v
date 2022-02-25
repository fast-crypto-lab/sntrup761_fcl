/*******************************************************************
  Polynomial Inversion on R3. Design with Systolic Array approach.
 
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

module r3_inverse(
    clk,
    rst,
    start,
    wr_en, wr_addr, rd_addr, wr_di, rd_dout,
	valid
);
    parameter P_WIDTH = 8;
	parameter Q_DEPTH = 10;
    parameter NTRU_Q = 4591;
	integer	  i;

    //state
	parameter IDLE = 0;
	parameter INVERSE = 1;
	parameter FINISH = 2;
    
    //IO
    input					   clk;
	input					   rst;
	input	        		   start;
    output reg                 wr_en;
    output reg [Q_DEPTH-1 : 0] wr_addr;
    output     [Q_DEPTH-1 : 0] rd_addr;
    output     [P_WIDTH-1 : 0] wr_di;
    input      [P_WIDTH-1 : 0] rd_dout;
	output reg				   valid;

    reg         [1 : 0]  state, next_state;
    reg         [9 : 0]  counter;
    reg         [10 : 0] counter_t;
    wire                 counter_end, counter_t_end;
    reg                  start_i;
    reg  signed [10 : 0] delta;
    wire                 start_in [0 : 8];
    wire signed [10 : 0] delta_in [0 : 8];
    wire [P_WIDTH-1 : 0] vrfg_in  [0 : 8];
    wire                 pass_in  [0 : 8];
    reg                  s        [0 : 7];
    reg                  counter_start;
    reg                  pass;
    

    assign counter_end   = (counter == 761)   ? 1 : 0;
    assign counter_t_end = (counter_t == 191) ? 1 : 0;
    assign rd_addr = counter;
    assign vrfg_in[0] = rd_dout;
    assign delta_in[0] = delta;
    assign start_in[0] = start_i;
    assign wr_di = vrfg_in[8];
    assign pass_in[0] = pass;

    always @(posedge clk ) begin
        s[0] <= 0;
        s[1] <= 1;
        s[2] <= 1;
        s[3] <= 1;
        s[4] <= 1;
        s[5] <= 1;
        s[6] <= 1;
        s[7] <= 1;
    end

    // pass
    always @(posedge clk ) begin
        if (counter_t == 190) begin
            pass <= 1;
        end else begin
            pass <= 0;
        end
    end

    // wr_en
    always @(posedge clk ) begin
        if (rst) begin
            wr_en <= 0;
        end else begin
            if (counter == 24 && counter_t == 0) begin
                wr_en <= 1;
            end else begin
                wr_en <= wr_en;
            end
        end
    end

    // wr_addr
    always @(posedge clk ) begin
        if(counter_start)begin
            if(wr_addr == 761)begin
                wr_addr <= 0;
            end else begin
                wr_addr <= wr_addr + 1;
            end
        end else begin
            wr_addr <= 0;
        end

        if (rst) begin
            counter_start <= 0;
        end else begin
            if (counter == 24 && counter_t == 0) begin
                counter_start <= 1;
            end else begin
                counter_start <= counter_start;
            end
        end
    end

    // counter, counter_t
    always@(posedge clk)begin
        if(state == INVERSE)begin
            if(counter_end)begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
        end else begin 
            counter <= 0;
        end

        if(state == INVERSE)begin
            if (counter_end) begin
                counter_t <= counter_t + 1;
            end else begin
                counter_t <= counter_t;
            end
        end else begin
            counter_t <= 0;
        end
    end

    // valid
    always@(*)begin
        if (state == FINISH) begin
            valid = 1;
        end else begin
            valid = 0;
        end
    end

    // state
	always@(posedge clk)begin
		if(rst) begin
            state <= 3'd0;
        end else begin
            state <= next_state;
        end
	end
	always@(*)begin
		case(state)
		IDLE: 
		begin
			if(start)
				next_state = INVERSE;
			else
				next_state = IDLE;
		end
		INVERSE: 
		begin
			if(counter_t == 191 && wr_addr == 761)
				next_state = FINISH;
			else
				next_state = INVERSE;
		end
		FINISH:
		begin
            next_state = FINISH;
            /*
			if(!start)
				next_state = FINISH;
			else
				next_state = IDLE;
            */
		end
		default: next_state = state;
		endcase
	end

    // start_i
    always @(posedge clk ) begin
        if (counter == 0) begin
            start_i <= 1;
        end else begin
            start_i <= 0;
        end
    end

    // delta
    always @(posedge clk ) begin
        if (counter_t == 0) begin
            delta <= 1;
        end else begin
            delta <= delta_in[8];
        end
    end

    inv inv_0(clk, s[0], pass_in[0], start_in[0], delta_in[0], vrfg_in[0], pass_in[1], start_in[1], delta_in[1], vrfg_in[1]);
    inv inv_1(clk, s[1], pass_in[1], start_in[1], delta_in[1], vrfg_in[1], pass_in[2], start_in[2], delta_in[2], vrfg_in[2]);
    inv inv_2(clk, s[2], pass_in[2], start_in[2], delta_in[2], vrfg_in[2], pass_in[3], start_in[3], delta_in[3], vrfg_in[3]);
    inv inv_3(clk, s[3], pass_in[3], start_in[3], delta_in[3], vrfg_in[3], pass_in[4], start_in[4], delta_in[4], vrfg_in[4]);
    inv inv_4(clk, s[4], pass_in[4], start_in[4], delta_in[4], vrfg_in[4], pass_in[5], start_in[5], delta_in[5], vrfg_in[5]);
    inv inv_5(clk, s[5], pass_in[5], start_in[5], delta_in[5], vrfg_in[5], pass_in[6], start_in[6], delta_in[6], vrfg_in[6]);
    inv inv_6(clk, s[6], pass_in[6], start_in[6], delta_in[6], vrfg_in[6], pass_in[7], start_in[7], delta_in[7], vrfg_in[7]);
    inv inv_7(clk, s[7], pass_in[7], start_in[7], delta_in[7], vrfg_in[7], pass_in[8], start_in[8], delta_in[8], vrfg_in[8]);

endmodule

module inv(
    clk,
    s,
    pass_in,
    start_in,
    delta_in,
    vrfg_in,
    pass_out,
    start_out,
    delta_out,
    vrfg_out
);
    input                    clk;
    input                    s;
    input                    pass_in;
    input                    start_in;
    input      signed [10:0] delta_in;
    input             [7:0]  vrfg_in;
    output reg               pass_out;
    output reg               start_out;
    output reg signed [10:0] delta_out;
    output            [7:0]  vrfg_out;

    wire [1:0] v, r, f, g; 
    reg        start_s1, start_s2;
    reg        case1;
    reg  [1:0] f0, g0;
    reg  [1:0] f_s1, f_s2, f_out;
    reg  [1:0] g_s1, g_s2, g_out;
    reg  [1:0] v_s1, v_s2, v_s3, v_out;
    reg  [1:0] r_s1, r_s2, r_out;
    wire [1:0] fg0, gf0, vg0, rf0;
    reg  [1:0] fg0_r, gf0_r, vg0_r, rf0_r;
    reg  [1:0] fg, vr;
    reg        pass_s1, pass_s2;

    f0_times_g0 f_times_g0 ( f[0], f[1],g0[0],g0[1],fg0[0],fg0[1]);
    f0_times_g0 f0_times_g (f0[0],f0[1], g[0],g [1],gf0[0],gf0[1]);

    f0_times_g0 v_times_g0 (v_s1[0],v_s1[1],  g0[0],  g0[1],vg0[0],vg0[1]);
    f0_times_g0 f0_times_r (  f0[0],  f0[1],r_s1[0],r_s1[1],rf0[0],rf0[1]);

    assign v = vrfg_in[7:6];
    assign r = vrfg_in[5:4];
    assign f = vrfg_in[3:2];
    assign g = vrfg_in[1:0];

    assign vrfg_out[7:6] = v_out;
    assign vrfg_out[5:4] = r_out;
    assign vrfg_out[3:2] = f_out;
    assign vrfg_out[1:0] = g_out;


    // pass_s1, pass_s2, pass_out
    always @(posedge clk ) begin
        pass_s1 <= pass_in;
        pass_s2 <= pass_s1;
        pass_out <= pass_s2;
    end

    // fg0_r, gf0_r, vg0_r, rf0_r
    always @(posedge clk ) begin
        if (start_in) begin
            fg0_r <= 0;
            gf0_r <= 0;
        end else begin
            fg0_r <= fg0;
            gf0_r <= gf0;
        end
        
        vg0_r <= vg0;
        rf0_r <= rf0;
    end

    // f - g
    always@(*)
    begin
	    case({fg0_r, gf0_r, case1})
            5'b00010: fg = 2'b01;
            5'b00110: fg = 2'b11;
            5'b01000: fg = 2'b11;
            5'b01110: fg = 2'b01;
            5'b11000: fg = 2'b01;
            5'b11010: fg = 2'b11;
            5'b00011: fg = 2'b11;
            5'b00111: fg = 2'b01;
            5'b01001: fg = 2'b01;
            5'b01111: fg = 2'b11;
            5'b11001: fg = 2'b11;
            5'b11011: fg = 2'b01;
	    	default: fg = 2'b00;
	    endcase
    end

    // v - r
    always@(*)
    begin
        case({vg0_r, rf0_r, case1})
            5'b00010: vr = 2'b01;
            5'b00110: vr = 2'b11;
            5'b01000: vr = 2'b11;
            5'b01110: vr = 2'b01;
            5'b11000: vr = 2'b01;
            5'b11010: vr = 2'b11;
            5'b00011: vr = 2'b11;
            5'b00111: vr = 2'b01;
            5'b01001: vr = 2'b01;
            5'b01111: vr = 2'b11;
            5'b11001: vr = 2'b11;
            5'b11011: vr = 2'b01;
	    	default: vr = 2'b00;
	    endcase
    end

    // f, f_s1, f_s2, f_out
    always @(posedge clk ) begin
        f_s1 <= f;
        f_s2 <= f_s1;
        if (s && pass_s2) begin
            f_out <= f_s2;
        end else if (case1) begin
            f_out <= g_s2;
        end else begin
            f_out <= f_s2;
        end
    end

    // g, g_s1, g_s2, g_out
    always @(posedge clk ) begin
        g_s1 <= g;
        g_s2 <= g_s1;
        if (s && pass_s2) begin
            g_out <= g_s2;
        end else begin
            g_out <= fg;
        end
    end

    // v, v_s1, v_s2, v_s3, v_out
    always @(posedge clk ) begin
        v_s1 <= v;
        v_s2 <= v_s1;
        if (case1) begin
            v_s3 <= r_s2;
        end else begin
            v_s3 <= v_s2;
        end

        if (s && pass_s2) begin
            v_out <= v_s2;
        end else if (start_s2) begin
            v_out <= 0;
            
        end else if (s == 0 && pass_s2 && f0 == 2'b11) begin
            if (v_s3 == 2'b01) begin
                v_out <= 2'b11;
            end else if (v_s3 == 2'b11) begin
                v_out <= 2'b01;
            end else begin
                v_out <= v_s3;
            end
            
        end else begin
            v_out <= v_s3;
        end
    end

    // r, r_s1, r_s2, r_out
    always @(posedge clk ) begin
        r_s1 <= r;
        r_s2 <= r_s1;
        if (s && pass_s2) begin
            r_out <= r_s2;
        end else begin
            r_out <= vr;
        end
    end

    // start, start_s1, start_s2, start_out
    always @(posedge clk ) begin
        start_s1 <= start_in;
        start_s2 <= start_s1;
        start_out <= start_s2;
    end

    // f0, g0
    always @(posedge clk ) begin
        if (start_in) begin
            f0 <= f;
            g0 <= g;
        end else begin
            f0 <= f0;
            g0 <= g0;
        end

    end

    // case1
    always @(posedge clk ) begin
        if (start_s1) begin
            if (delta_in > 0 && g0[0] == 1) begin
                case1 <= 1;
            end else begin
                case1 <= 0;
            end
        end else begin
            case1 <= case1;
        end
    end

    // delta_out
    always @(posedge clk ) begin
        if (start_s2) begin
            if (case1) begin
                delta_out <= 1 - delta_in;     //case1
            end else begin
                delta_out <= 1 + delta_in;     //case2
            end
        end else begin
            delta_out <= delta_out;
        end
    end

endmodule
