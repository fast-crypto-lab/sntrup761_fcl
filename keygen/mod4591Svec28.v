/*******************************************************************
  R_4591 signed reduction directly without using more DSP Slice.
 
  Author: Bo-Yuan Peng       bypeng@crypto.tw
  Copyright 2021 Academia Sinica
 
  Description:
  Table Looking Up Part. Use with the main module.
 
  Version Info:
     Nov.20,2019: 0.1.0 Design ready.
     Dec. 3,2019: 0.2.0 Support for 28-bit signed value.
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

module mod4591Svec28 (
    input       [27:0] z_in,
    output      [11:0] p0,
    output reg  [11:0] p1,
    output reg  [11:0] n0,
    output reg  [11:0] n1
) ;

    assign p0 = z_in[11:0];

    always @ (*) begin
        case({ z_in[24], z_in[23], z_in[22], z_in[16], z_in[12] })
            5'h00: n0 = 12'd0;
            5'h01: n0 = 12'd495;
            5'h02: n0 = 12'd3329;
            5'h03: n0 = 12'd3824;
            5'h04: n0 = 12'd1870;
            5'h05: n0 = 12'd2365;
            5'h06: n0 = 12'd608;
            5'h07: n0 = 12'd1103;
            5'h08: n0 = 12'd28;
            5'h09: n0 = 12'd523;
            5'h0a: n0 = 12'd3357;
            5'h0b: n0 = 12'd3852;
            5'h0c: n0 = 12'd1898;
            5'h0d: n0 = 12'd2393;
            5'h0e: n0 = 12'd636;
            5'h0f: n0 = 12'd1131;
            5'h10: n0 = 12'd2889;
            5'h11: n0 = 12'd3384;
            5'h12: n0 = 12'd1627;
            5'h13: n0 = 12'd2122;
            5'h14: n0 = 12'd168;
            5'h15: n0 = 12'd663;
            5'h16: n0 = 12'd3497;
            5'h17: n0 = 12'd3992;
            5'h18: n0 = 12'd2917;
            5'h19: n0 = 12'd3412;
            5'h1a: n0 = 12'd1655;
            5'h1b: n0 = 12'd2150;
            5'h1c: n0 = 12'd196;
            5'h1d: n0 = 12'd691;
            5'h1e: n0 = 12'd3525;
            5'h1f: n0 = 12'd4020;
        endcase
    end

    always @ (*) begin
        case({ z_in[25], z_in[23], z_in[21], z_in[20], z_in[19], z_in[13] })
            6'h00: n1 = 12'd0;
            6'h01: n1 = 12'd990;
            6'h02: n1 = 12'd3677;
            6'h03: n1 = 12'd76;
            6'h04: n1 = 12'd2763;
            6'h05: n1 = 12'd3753;
            6'h06: n1 = 12'd1849;
            6'h07: n1 = 12'd2839;
            6'h08: n1 = 12'd935;
            6'h09: n1 = 12'd1925;
            6'h0a: n1 = 12'd21;
            6'h0b: n1 = 12'd1011;
            6'h0c: n1 = 12'd3698;
            6'h0d: n1 = 12'd97;
            6'h0e: n1 = 12'd2784;
            6'h0f: n1 = 12'd3774;
            6'h10: n1 = 12'd3712;
            6'h11: n1 = 12'd111;
            6'h12: n1 = 12'd2798;
            6'h13: n1 = 12'd3788;
            6'h14: n1 = 12'd1884;
            6'h15: n1 = 12'd2874;
            6'h16: n1 = 12'd970;
            6'h17: n1 = 12'd1960;
            6'h18: n1 = 12'd56;
            6'h19: n1 = 12'd1046;
            6'h1a: n1 = 12'd3733;
            6'h1b: n1 = 12'd132;
            6'h1c: n1 = 12'd2819;
            6'h1d: n1 = 12'd3809;
            6'h1e: n1 = 12'd1905;
            6'h1f: n1 = 12'd2895;
            6'h20: n1 = 12'd1187;
            6'h21: n1 = 12'd2177;
            6'h22: n1 = 12'd273;
            6'h23: n1 = 12'd1263;
            6'h24: n1 = 12'd3950;
            6'h25: n1 = 12'd349;
            6'h26: n1 = 12'd3036;
            6'h27: n1 = 12'd4026;
            6'h28: n1 = 12'd2122;
            6'h29: n1 = 12'd3112;
            6'h2a: n1 = 12'd1208;
            6'h2b: n1 = 12'd2198;
            6'h2c: n1 = 12'd294;
            6'h2d: n1 = 12'd1284;
            6'h2e: n1 = 12'd3971;
            6'h2f: n1 = 12'd370;
            6'h30: n1 = 12'd308;
            6'h31: n1 = 12'd1298;
            6'h32: n1 = 12'd3985;
            6'h33: n1 = 12'd384;
            6'h34: n1 = 12'd3071;
            6'h35: n1 = 12'd4061;
            6'h36: n1 = 12'd2157;
            6'h37: n1 = 12'd3147;
            6'h38: n1 = 12'd1243;
            6'h39: n1 = 12'd2233;
            6'h3a: n1 = 12'd329;
            6'h3b: n1 = 12'd1319;
            6'h3c: n1 = 12'd4006;
            6'h3d: n1 = 12'd405;
            6'h3e: n1 = 12'd3092;
            6'h3f: n1 = 12'd4082;
        endcase
    end

    always @ (*) begin
        case({ z_in[27], z_in[26], z_in[18], z_in[17], z_in[15], z_in[14] })
            6'h00: p1 = 12'd0;
            6'h01: p1 = 12'd2611;
            6'h02: p1 = 12'd631;
            6'h03: p1 = 12'd3242;
            6'h04: p1 = 12'd2524;
            6'h05: p1 = 12'd544;
            6'h06: p1 = 12'd3155;
            6'h07: p1 = 12'd1175;
            6'h08: p1 = 12'd457;
            6'h09: p1 = 12'd3068;
            6'h0a: p1 = 12'd1088;
            6'h0b: p1 = 12'd3699;
            6'h0c: p1 = 12'd2981;
            6'h0d: p1 = 12'd1001;
            6'h0e: p1 = 12'd3612;
            6'h0f: p1 = 12'd1632;
            6'h10: p1 = 12'd2217;
            6'h11: p1 = 12'd237;
            6'h12: p1 = 12'd2848;
            6'h13: p1 = 12'd868;
            6'h14: p1 = 12'd150;
            6'h15: p1 = 12'd2761;
            6'h16: p1 = 12'd781;
            6'h17: p1 = 12'd3392;
            6'h18: p1 = 12'd2674;
            6'h19: p1 = 12'd694;
            6'h1a: p1 = 12'd3305;
            6'h1b: p1 = 12'd1325;
            6'h1c: p1 = 12'd607;
            6'h1d: p1 = 12'd3218;
            6'h1e: p1 = 12'd1238;
            6'h1f: p1 = 12'd3849;
            6'h20: p1 = 12'd157;
            6'h21: p1 = 12'd2768;
            6'h22: p1 = 12'd788;
            6'h23: p1 = 12'd3399;
            6'h24: p1 = 12'd2681;
            6'h25: p1 = 12'd701;
            6'h26: p1 = 12'd3312;
            6'h27: p1 = 12'd1332;
            6'h28: p1 = 12'd614;
            6'h29: p1 = 12'd3225;
            6'h2a: p1 = 12'd1245;
            6'h2b: p1 = 12'd3856;
            6'h2c: p1 = 12'd3138;
            6'h2d: p1 = 12'd1158;
            6'h2e: p1 = 12'd3769;
            6'h2f: p1 = 12'd1789;
            6'h30: p1 = 12'd2374;
            6'h31: p1 = 12'd394;
            6'h32: p1 = 12'd3005;
            6'h33: p1 = 12'd1025;
            6'h34: p1 = 12'd307;
            6'h35: p1 = 12'd2918;
            6'h36: p1 = 12'd938;
            6'h37: p1 = 12'd3549;
            6'h38: p1 = 12'd2831;
            6'h39: p1 = 12'd851;
            6'h3a: p1 = 12'd3462;
            6'h3b: p1 = 12'd1482;
            6'h3c: p1 = 12'd764;
            6'h3d: p1 = 12'd3375;
            6'h3e: p1 = 12'd1395;
            6'h3f: p1 = 12'd4006;
        endcase
    end

endmodule
