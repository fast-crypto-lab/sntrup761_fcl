/*******************************************************************
  Polynomial Inversion Module on R_4591.
 
  Author: Bo-Yuan Peng       bypeng@crypto.tw
          Ming-Han Tsai      r08943151@ntu.edu.tw
  Copyright 2021 Academia Sinica

  Version Info:
     May.15,2021: 0.1.0 Degisn ready.

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

module poly_inverse(
	Clk,
	Reset,
	Cmd,
	Addr,
	DI,
	DO,
	Valid
	);
    parameter P_WIDTH = 13;
	parameter Q_DEPTH = 10;
    parameter NTRU_Q = 4591;
	integer	  i;

	//state
	parameter IDLE = 0;
	parameter DATA_PUT = 1;
	parameter INVERSE = 2;
	parameter FINISH = 3;

	//Cmd
	parameter input_data = 1;
	parameter write_f = 2;
	parameter write_g = 3;
	parameter start = 4;
    
    //IO
    input						Clk;
	input						Reset;
	input		[2 : 0]			Cmd;
	input		[Q_DEPTH-1 : 0]	Addr;
	input		[P_WIDTH-1 : 0]	DI;
	output		[P_WIDTH-1 : 0]	DO;
	output reg					Valid;

    reg                         wr_en_f, wr_en_g;
    reg         [Q_DEPTH-1 : 0] wr_addr_f, wr_addr_g;
    reg  signed [P_WIDTH-1 : 0] wr_di_f, wr_di_g;
    reg         [Q_DEPTH-1 : 0] rd_addr_f, rd_addr_g;
    wire signed [P_WIDTH-1 : 0] wr_dout_f, wr_dout_g;
    wire signed [P_WIDTH-1 : 0] rd_dout_f, rd_dout_g;
    
    reg                    wr_en_vr;
    reg  [Q_DEPTH-1   : 0] wr_addr_vr;
    reg  [2*P_WIDTH-1 : 0] wr_di_vr;
    reg  [Q_DEPTH-1   : 0] rd_addr_vr;
    wire [2*P_WIDTH-1 : 0] wr_dout_vr;
    wire [2*P_WIDTH-1 : 0] rd_dout_vr;
    
    reg         [ 1 : 0]        state, next_state;
    reg         [ 9 : 0]        counter, counter_w;
    reg         [10 : 0]        counter_t, counter_vr, counter_vr_w;
    wire                        counter_end, counter_t_end;
    reg                         case1, case1_shift;
    wire                        case1_w;
    reg  signed [P_WIDTH-1 : 0] delta; 
    wire signed [P_WIDTH-1 : 0] g_out, r_out;
    reg  signed [P_WIDTH-1 : 0] f0, g0;
    reg  signed [P_WIDTH-1 : 0] g_temp, f_temp, f_shift_1, f_shift_2;
    reg  signed [P_WIDTH-1 : 0] f_shift_3, f_shift_4, f_shift_5, f_shift_6;
    reg  signed [23 : 0]        fg0, gf0;
    reg  signed [24 : 0]        fg, g;
    reg  signed [P_WIDTH-1 : 0] r_temp, v_temp, v_shift_1, v_shift_2;
    reg  signed [P_WIDTH-1 : 0] v_shift_3, v_shift_4, v_shift_5, v_shift_6;
    reg  signed [23 : 0]        vg0, rf0;
    reg  signed [24 : 0]        vr, r;
    reg                         v0, r0;
    reg                         inverse_en;
    wire                        inverse_valid;
    wire signed [P_WIDTH-1 : 0] inverse_out;
    wire signed [P_WIDTH-1 : 0] g00, f00;
    reg  signed [P_WIDTH-1 : 0] next_f0;


    bram_p #(.Q_DEPTH(Q_DEPTH),.D_SIZE(P_WIDTH))
		bram_f (.clk(Clk), .wr_en(wr_en_f), .wr_addr(wr_addr_f), .rd_addr(rd_addr_f), .wr_din(wr_di_f), .wr_dout(wr_dout_f), .rd_dout(rd_dout_f));
	bram_p #(.Q_DEPTH(Q_DEPTH),.D_SIZE(P_WIDTH))
		bram_g (.clk(Clk), .wr_en(wr_en_g), .wr_addr(wr_addr_g), .rd_addr(rd_addr_g), .wr_din(wr_di_g), .wr_dout(wr_dout_g), .rd_dout(rd_dout_g));
    
    bram_p #(.Q_DEPTH(Q_DEPTH),.D_SIZE(2*P_WIDTH))
		bram_vr (.clk(Clk), .wr_en(wr_en_vr), .wr_addr(wr_addr_vr), .rd_addr(rd_addr_vr), .wr_din(wr_di_vr), .wr_dout(wr_dout_vr), .rd_dout(rd_dout_vr));
	
	modmul4591S g_mod(.Clk(Clk), .Reset(Reset), .In(g), .Out(g_out));
    modmul4591S r_mod(.Clk(Clk), .Reset(Reset), .In(r), .Out(r_out));

    inverse4591 inv0(.Clk(Clk), .Reset(Reset), .In(next_f0), .En(inverse_en), .Out(inverse_out), .Valid(inverse_valid));


    assign counter_end = (counter == 763) ? 1 : 0;
    assign counter_t_end = (counter_t == 1522) ? 1 : 0;
    assign case1_w = (delta > 0 && g0 != 0) ? 1 : 0;

    always@(posedge Clk)begin
        if (wr_addr_f == 0) begin
            next_f0 <= wr_di_f;
        end else begin
            next_f0 <= next_f0;
        end
    end

    //case
    always@(posedge Clk)begin
        case1 <= case1_w;
        case1_shift <= case1;
    end

    //counter, counter_t, counter_w
    always@(posedge Clk)begin
        if(state == INVERSE)begin
            if(counter_end)begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
        end else begin 
            counter <= 0;
        end

        if (counter == 7) begin
            counter_w <= 0;
        end else begin
            counter_w <= counter_w + 1;
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

        if (counter == 0) begin
            if (counter_t > 761) begin
                counter_vr <= 1;
            end else begin
                counter_vr <= 0;
            end
        end else begin
            counter_vr <= counter_vr + 1;
        end

        if (counter == 7) begin
            if (counter_t > 761) begin
                counter_vr_w <= 1;
            end else begin
                counter_vr_w <= 1;
            end
        end else begin
            counter_vr_w <= counter_vr_w + 1;
        end
    end

    //wr_en_f, wr_en_g
    always@(posedge Clk)begin
        if(next_state == DATA_PUT && Cmd == write_f)begin
            wr_en_f <= 1;
        end else if(state == INVERSE)begin
            if (counter == 7 && counter_t == 0) begin
                wr_en_f <= !wr_en_f;
            end else begin
                wr_en_f <= wr_en_f;
            end 
        end else begin
            wr_en_f <= 0;
        end

        if(next_state == DATA_PUT && Cmd == write_g)begin
            wr_en_g <= 1;
        end else if(state == INVERSE)begin
            if (counter == 7 && counter_t == 0) begin
                wr_en_g <= !wr_en_g;
            end else begin
                wr_en_g <= wr_en_g;
            end 
        end else begin
            wr_en_g <= 0;
        end
    end

    //wr_addr_f, wr_addr_g
    always@(*)begin
        if(state == DATA_PUT)begin
            wr_addr_f = Addr;
        end else begin 
            wr_addr_f = counter_w;
        end

        if(state == DATA_PUT)begin
            wr_addr_g = Addr;
        end else begin
            wr_addr_g = counter_w;
        end
    end

    //wr_di_f, wr_di_g
    always@(*)begin
        if(state == DATA_PUT)begin
            wr_di_f = DI;
        end else begin 
            wr_di_f = f_shift_6;
        end

        if(state == DATA_PUT)begin
            wr_di_g = DI;
        end else if (counter_w == 761) begin
            wr_di_g = 0;
        end else begin
            wr_di_g = g_out;
        end
    end

    //rd_addr_f, rd_addr_g
    always@(*)begin
        if(state == INVERSE)begin
            rd_addr_f = counter;
        end else begin
            rd_addr_f = Addr;
        end

        if(state == INVERSE)begin
            rd_addr_g = counter;
        end else begin
            rd_addr_g = Addr;
        end
    end

    //delta
    always@(posedge Clk)begin
        if (state == INVERSE) begin
            if (counter_end) begin
                if (case1) begin
                    delta <= 1 - delta;         //case1
                end else begin
                    delta <= 1 + delta;         //case2
                end
            end else begin
                delta <= delta;
            end
        end else begin
            delta <= 1;
        end
    end

    //f0, g0
    always@(posedge Clk)begin
        if (state == INVERSE && counter == 1) begin
            f0 <= rd_dout_f;
        end else begin
            f0 <= f0;
        end

        if (state == INVERSE && counter == 1) begin
            g0 <= rd_dout_g;
        end else begin
            g0 <= g0;
        end
    end

    //case1 : g = f*g0 - g*f0, f = g;   case2 : g = - (f*g0 - g*f0), f = f
    always@(posedge Clk)begin
        fg0 <= rd_dout_f * g0;
        gf0 <= rd_dout_g * f0;
        fg <= fg0 - gf0;
        if (case1) begin
            g <= fg;
        end else begin
            g <= -fg;
        end
        g_temp <= rd_dout_g;
        f_temp <= rd_dout_f;
        if (case1_w) begin
            f_shift_1 <= g_temp;
        end else begin
            f_shift_1 <= f_temp;
        end
        f_shift_2 <= f_shift_1;
        f_shift_3 <= f_shift_2;
        f_shift_4 <= f_shift_3;
        f_shift_5 <= f_shift_4;
        f_shift_6 <= f_shift_5;
    end

    //wr_en_vr
    always@(posedge Clk)begin
        if(state == INVERSE)begin
            if (counter == 7 && counter_t == 0) begin
                wr_en_vr <= !wr_en_vr;
            end else begin
                wr_en_vr <= wr_en_vr;
            end
        end else begin
            wr_en_vr <= 0;
        end
    end

    //wr_addr_vr
    always@(*)begin
        wr_addr_vr = counter_vr_w;
    end

    //wr_di_vr
    always@(*)begin
        wr_di_vr = {v_shift_5, r_out};
    end
    //rd_addr_vr
    always@(*)begin
        if (state == FINISH) begin
            rd_addr_vr = Addr;    
        end else begin
            rd_addr_vr = counter_vr;
        end
    end

    //v0, r0
    always@(posedge Clk)begin
        if (state == INVERSE) begin
            if (case1 && counter == 3) begin
                v0 <= r0;
            end else begin
                v0 <= v0;
            end
        end else begin
            v0 <= 0;
        end

        if (state == INVERSE) begin
            if (counter == 3) begin
                r0 <= 0;
            end else begin
                r0 <= r0;
            end
        end else begin
            r0 <= 1;
        end
    end

    assign g00 = (counter_t == 1521) ? inverse_out : g0;
    assign f00 = (counter_t == 1521) ? 0           : f0;

    //case1 : r = v*g0 - r*f0, v = r;   case2 : r = - (v*g0 - r*f0), v = v
    always@(posedge Clk)begin
        if (counter_t < 762 && counter == 2) begin
            if (v0) begin
                vg0 <= g0;
            end else begin
                vg0 <= 0;
            end
        end else begin
            vg0 <= $signed(rd_dout_vr[2*P_WIDTH-1 : P_WIDTH]) * g00;
        end

        if (counter_t < 762 && counter == 2) begin
            if (r0) begin
                rf0 <= f0;
            end else begin
                rf0 <= 0;
            end
        end else begin
            rf0 <= $signed(rd_dout_vr[P_WIDTH-1 : 0]) * f00;
        end

        vr <= vg0 - rf0;

        if (case1_shift || (counter_t == 1521 && counter > 3) || counter_t_end) begin
            r <= vr;
        end else begin
            r <= -vr;
        end
        
        if (case1) begin
            if (counter == counter_t + 3 || counter == 0 ) begin
                v_shift_1 <= 0;
            end else begin
                v_shift_1 <= rd_dout_vr[P_WIDTH-1 : 0];
            end
        end else begin
            if (counter == counter_t + 3 || counter == 0) begin
                v_shift_1 <= 0;
            end else begin
                v_shift_1 <= rd_dout_vr[2*P_WIDTH-1 : P_WIDTH];
            end
        end

        v_shift_2 <= v_shift_1;
        v_shift_3 <= v_shift_2;
        v_shift_4 <= v_shift_3;
        v_shift_5 <= v_shift_4;
    end

    //inverse4591
    always@(*)begin
        if (counter_t == 1520 && counter == 100) begin
            inverse_en = 1;
        end else begin
            inverse_en = 0;
        end
    end



    //DO
    assign DO = rd_dout_vr[P_WIDTH-1 : 0];

    //Vaild
    always@(posedge Clk)begin
        if (state == FINISH) begin
            Valid <= 1;
        end else begin
            Valid <= 0;
        end
    end

    // state
	always@(posedge Clk)begin
		if(Reset) begin
            state <= 3'd0;
        end else begin
            state <= next_state;
        end
	end
	always@(*)begin
		case(state)
		IDLE: 
		begin
			if(Cmd == input_data)
				next_state = DATA_PUT;
			else
				next_state = IDLE;
		end
		DATA_PUT:
		begin
			if(Cmd == start)
				next_state = INVERSE;
			else
				next_state = DATA_PUT;
		end
		INVERSE: 
		begin
			if(counter == 5 && counter_t_end)
				next_state = FINISH;
			else
				next_state = INVERSE;
		end
		FINISH:
		begin
			next_state = FINISH;
		end
		default: next_state = state;
		endcase
	end

endmodule
