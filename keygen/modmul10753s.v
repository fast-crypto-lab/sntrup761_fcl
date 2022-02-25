/*******************************************************************
  Signed Modular Multiplication with Prime Q = 10753
 
  Author: Bo-Yuan Peng
  Copyright 2021 Academia Sinica
 
  Description:
  This is a verilog module testing signed modular multiplication
              outC == inA * inB (mod^{+-} 10753)
  
                                       Diligent          Lazy
  -- inA:  signed 14-bit integer in [-5376, 5376] or [-5122, 5631].
  -- inB:  signed 14-bit integer in [-5376, 5376] or [-5122, 5631].
  -- inZ:  signed 26-bit integer as inA * inB.
  -- outC: signed 14-bit integer in [-5376, 5376] or [-5122, 5631].
 
  Version Info:
     Mar.31,2021: 0.0.1 creation of the module.
     Apr.24,2021: 0.1.0 module design complete without critical
                        path length control.
     May 31,2021: 0.2.0 3-stage pipeline after the synchronized
                        multipliplication.

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

module modmul10753s (
  input clk,
  //input signed      [13:0]  inA,
  //input signed      [13:0]  inB,
  input signed      [25:0]  inZ,
  output reg signed [13:0]  outC
) ;

  reg signed        [25:0]  mZ;

  wire              [12:0]  part0;
  reg               [12:0]  part1;
  reg               [12:0]  part2;
  reg               [12:0]  part3;

  wire              [13:0]  part01sum;
  wire              [14:0]  part01rec;
  wire              [13:0]  part23sum;
  wire              [14:0]  part23rec;

  wire              [13:0]  part01;
  reg               [13:0]  part01_r;
  wire              [13:0]  part23;
  reg               [13:0]  part23_r;

  wire              [14:0]  partC;
  reg               [14:0]  partC_r;
  wire                      partC_inP;
  wire                      partC_in2P;
  wire              [14:0]  RedQ;

  //always @ ( posedge clk ) begin
  always @ (*) begin
    //mZ <= inA * inB;
    mZ = inZ;
  end

  assign part0 = mZ[12:0];
  // [0, 8191]

  always @ (*) begin
    case(mZ[18:15])
      4'h0: part1 = 13'd0;
      4'h1: part1 = 13'd509;
      4'h2: part1 = 13'd1018;
      4'h3: part1 = 13'd1527;
      4'h4: part1 = 13'd2036;
      4'h5: part1 = 13'd2545;
      4'h6: part1 = 13'd3054;
      4'h7: part1 = 13'd3563;
      4'h8: part1 = 13'd4072;
      4'h9: part1 = 13'd4581;
      4'ha: part1 = 13'd5090;
      4'hb: part1 = 13'd5599;
      4'hc: part1 = 13'd6108;
      4'hd: part1 = 13'd6617;
      4'he: part1 = 13'd7126;
      4'hf: part1 = 13'd7635;
      default: part1 = 13'd0;
    endcase
  end
  // [0, 7635]

  always @ (*) begin
    case({ mZ[19], mZ[13], mZ[25], mZ[20], mZ[14] })
      5'h00: part2 = 13'd0;
      5'h01: part2 = 13'd5631;
      5'h02: part2 = 13'd5535;
      5'h03: part2 = 13'd413;
      5'h04: part2 = 13'd5681;
      5'h05: part2 = 13'd559;
      5'h06: part2 = 13'd463;
      5'h07: part2 = 13'd6094;
      5'h08: part2 = 13'd7168; // -1024 when mZ[19] != mZ[13]
      5'h09: part2 = 13'd2046; // -1024 when mZ[19] != mZ[13]
      5'h0a: part2 = 13'd1950; // -1024 when mZ[19] != mZ[13]
      5'h0b: part2 = 13'd7581; // -1024 when mZ[19] != mZ[13]
      5'h0c: part2 = 13'd2096; // -1024 when mZ[19] != mZ[13]
      5'h0d: part2 = 13'd7727; // -1024 when mZ[19] != mZ[13]
      5'h0e: part2 = 13'd7631; // -1024 when mZ[19] != mZ[13]
      5'h0f: part2 = 13'd2509; // -1024 when mZ[19] != mZ[13]
      5'h10: part2 = 13'd7120; // -1024 when mZ[19] != mZ[13]
      5'h11: part2 = 13'd1998; // -1024 when mZ[19] != mZ[13]
      5'h12: part2 = 13'd1902; // -1024 when mZ[19] != mZ[13]
      5'h13: part2 = 13'd7533; // -1024 when mZ[19] != mZ[13]
      5'h14: part2 = 13'd2048; // -1024 when mZ[19] != mZ[13]
      5'h15: part2 = 13'd7679; // -1024 when mZ[19] != mZ[13]
      5'h16: part2 = 13'd7583; // -1024 when mZ[19] != mZ[13]
      5'h17: part2 = 13'd2461; // -1024 when mZ[19] != mZ[13]
      5'h18: part2 = 13'd5583;
      5'h19: part2 = 13'd461;
      5'h1a: part2 = 13'd365;
      5'h1b: part2 = 13'd5996;
      5'h1c: part2 = 13'd511;
      5'h1d: part2 = 13'd6142;
      5'h1e: part2 = 13'd6046;
      5'h1f: part2 = 13'd924;
      default: part2 = 13'd0;
    endcase
  end
  // [0, 7727]

  always @ (*) begin
    case({ mZ[19], mZ[13], mZ[24:21] })
      6'h00: part3 = 13'd0;
      6'h01: part3 = 13'd317;
      6'h02: part3 = 13'd634;
      6'h03: part3 = 13'd951;
      6'h04: part3 = 13'd1268;
      6'h05: part3 = 13'd1585;
      6'h06: part3 = 13'd1902;
      6'h07: part3 = 13'd2219;
      6'h08: part3 = 13'd2536;
      6'h09: part3 = 13'd2853;
      6'h0a: part3 = 13'd3170;
      6'h0b: part3 = 13'd3487;
      6'h0c: part3 = 13'd3804;
      6'h0d: part3 = 13'd4121;
      6'h0e: part3 = 13'd4438;
      6'h0f: part3 = 13'd4755;
      6'h10: part3 = 13'd1024; // +1024 when mZ[19] != mZ[13]
      6'h11: part3 = 13'd1341; // +1024 when mZ[19] != mZ[13]
      6'h12: part3 = 13'd1658; // +1024 when mZ[19] != mZ[13]
      6'h13: part3 = 13'd1975; // +1024 when mZ[19] != mZ[13]
      6'h14: part3 = 13'd2292; // +1024 when mZ[19] != mZ[13]
      6'h15: part3 = 13'd2609; // +1024 when mZ[19] != mZ[13]
      6'h16: part3 = 13'd2926; // +1024 when mZ[19] != mZ[13]
      6'h17: part3 = 13'd3243; // +1024 when mZ[19] != mZ[13]
      6'h18: part3 = 13'd3560; // +1024 when mZ[19] != mZ[13]
      6'h19: part3 = 13'd3877; // +1024 when mZ[19] != mZ[13]
      6'h1a: part3 = 13'd4194; // +1024 when mZ[19] != mZ[13]
      6'h1b: part3 = 13'd4511; // +1024 when mZ[19] != mZ[13]
      6'h1c: part3 = 13'd4828; // +1024 when mZ[19] != mZ[13]
      6'h1d: part3 = 13'd5145; // +1024 when mZ[19] != mZ[13]
      6'h1e: part3 = 13'd5462; // +1024 when mZ[19] != mZ[13]
      6'h1f: part3 = 13'd5779; // +1024 when mZ[19] != mZ[13]
      6'h20: part3 = 13'd1024; // +1024 when mZ[19] != mZ[13]
      6'h21: part3 = 13'd1341; // +1024 when mZ[19] != mZ[13]
      6'h22: part3 = 13'd1658; // +1024 when mZ[19] != mZ[13]
      6'h23: part3 = 13'd1975; // +1024 when mZ[19] != mZ[13]
      6'h24: part3 = 13'd2292; // +1024 when mZ[19] != mZ[13]
      6'h25: part3 = 13'd2609; // +1024 when mZ[19] != mZ[13]
      6'h26: part3 = 13'd2926; // +1024 when mZ[19] != mZ[13]
      6'h27: part3 = 13'd3243; // +1024 when mZ[19] != mZ[13]
      6'h28: part3 = 13'd3560; // +1024 when mZ[19] != mZ[13]
      6'h29: part3 = 13'd3877; // +1024 when mZ[19] != mZ[13]
      6'h2a: part3 = 13'd4194; // +1024 when mZ[19] != mZ[13]
      6'h2b: part3 = 13'd4511; // +1024 when mZ[19] != mZ[13]
      6'h2c: part3 = 13'd4828; // +1024 when mZ[19] != mZ[13]
      6'h2d: part3 = 13'd5145; // +1024 when mZ[19] != mZ[13]
      6'h2e: part3 = 13'd5462; // +1024 when mZ[19] != mZ[13]
      6'h2f: part3 = 13'd5779; // +1024 when mZ[19] != mZ[13]
      6'h30: part3 = 13'd0;
      6'h31: part3 = 13'd317;
      6'h32: part3 = 13'd634;
      6'h33: part3 = 13'd951;
      6'h34: part3 = 13'd1268;
      6'h35: part3 = 13'd1585;
      6'h36: part3 = 13'd1902;
      6'h37: part3 = 13'd2219;
      6'h38: part3 = 13'd2536;
      6'h39: part3 = 13'd2853;
      6'h3a: part3 = 13'd3170;
      6'h3b: part3 = 13'd3487;
      6'h3c: part3 = 13'd3804;
      6'h3d: part3 = 13'd4121;
      6'h3e: part3 = 13'd4438;
      6'h3f: part3 = 13'd4755;
      default: part3 = 13'd0;
    endcase
  end
  // [0, 5779]

  assign part01sum = part0 + part1;
  assign part01rec = { 1'b0, part01sum } - 15'sd10753;
  assign part01 = part01rec[14] ? part01sum : part01rec[13:0];
  always @ ( posedge clk ) begin
    part01_r <= part01;
  end

  assign part23sum = part2 + part3;
  assign part23rec = { 1'b0, part23sum } - 15'sd10753;
  assign part23 = part23rec[14] ? part23sum : part23rec[13:0];
  always @ ( posedge clk ) begin
    part23_r <= part23;
  end

  assign partC = part01_r + part23_r;
  //assign partC = part01 + part23;
  always @ ( posedge clk ) begin
    partC_r <= partC;
  end

  // Version 1: Diligent Reduction
  assign partC_in2P = (partC_r > 15'd16129);
  //assign partC_in2P = (partC > 15'd16129);
  assign partC_inP  = (partC_r > 15'd5376);
  //assign partC_inP  = (partC > 15'd5376);

  // Version 2: Lazy Reduction
  //assign partC_in2P = partC_r[14];
  //assign partC_in2P = partC[14];
  //assign partC_inP  = partC_r[13] || (partC_r[12] && (partC_r[11] || (partC_r[10] && partC_r[9])));
  //assign partC_inP  = partC[13] || (partC[12] && (partC[11] || (partC[10] && partC[9])));

  assign RedQ = partC_in2P ? 15'd21506 : ( partC_inP ? 15'd10753 : 15'd0 );

  always @ ( posedge clk ) begin
  //always @ (*) begin
    outC <= partC_r - RedQ;
    //outC <= partC - RedQ;
    //outC = partC_r - RedQ;
    //outC = partC - RedQ;
  end

endmodule

