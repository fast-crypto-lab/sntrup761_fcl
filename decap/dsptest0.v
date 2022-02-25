`timescale 1ns / 1ps
/******************************************************************* 
  DSP48E1 wrapper with P = (D +- A) * B + C
  Target Devices: Any devices with DSP Slice type DSP48E1.

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

//`define XILINX_ZEDBOARD
`define GENERAL_VERSION

module dsptest0(
    input clk,
    input signed    [24:0]  data_A,
    input signed    [17:0]  data_B,
    input signed    [47:0]  data_C,
    input signed    [24:0]  data_D,
    input                   data_crin,

    input                   DAaddsubctrl,

    output signed   [47:0]  data_P,
    output          [3:0]   data_crout
);

    wire signed     [29:0]  dsp0_A;
    wire signed     [17:0]  dsp0_B;
    wire signed     [47:0]  dsp0_C;
    wire signed     [24:0]  dsp0_D;
    wire                    dsp0_crin;
    wire signed     [47:0]  dsp0_P;
    wire            [3:0]   dsp0_crout;

    wire            [3:0]   dsp0_alumode;
    wire            [2:0]   dsp0_carryinsel;
    wire            [4:0]   dsp0_inmode;
    wire            [6:0]   dsp0_opmode;

    assign dsp0_A = { 5'b0, data_A };
    assign dsp0_B = data_B;
    assign dsp0_C = data_C;
    assign dsp0_D = data_D;
    assign dsp0_crin = data_crin;
    assign data_P = dsp0_P;
    assign data_crout = dsp0_crout;

    assign dsp0_alumode = 4'b0000;
    assign dsp0_carryinsel = 3'b000;
    assign dsp0_inmode = { 1'b0, DAaddsubctrl, 3'b100 } ;
    assign dsp0_opmode = 7'b0110101;

`ifdef GENERAL_VERSION

    wire signed [24:0] DandA;
    wire signed [49:0] DAtimesB;

    assign DandA = data_D + ( DAaddsubctrl ? ~data_A : data_A ) + { 24'b0, DAaddsubctrl };
    assign DAtimesB = DandA * data_B;

    assign data_P = DAtimesB[47:0] + data_C;

`endif

`ifdef XILINX_ZEDBOARD

    DSP48E1 #(
        // Feature Control Attributes: Data Path Selection
        .A_INPUT("DIRECT"),                  // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
        .B_INPUT("DIRECT"),                  // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
        .USE_DPORT("TRUE"),                  // Select D port usage (TRUE or FALSE)
        .USE_MULT("MULTIPLY"),               // Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
        .USE_SIMD("ONE48"),                  // SIMD selection ("ONE48", "TWO24", "FOUR12")
        // Pattern Detector Attributes: Pattern Detection Configuration
        .AUTORESET_PATDET("NO_RESET"),       // "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
        .MASK(48'h3fffffffffff),             // 48-bit mask value for pattern detect (1=ignore)
        .PATTERN(48'h000000000000),          // 48-bit pattern match for pattern detect
        .SEL_MASK("MASK"),                   // "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
        .SEL_PATTERN("PATTERN"),             // Select pattern value ("PATTERN" or "C")
        .USE_PATTERN_DETECT("NO_PATDET"),    // Enable pattern detect ("PATDET" or "NO_PATDET")
        // Register Control Attributes: Pipeline Register Configuration
        .ACASCREG(0),                        // Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
        .ADREG(0),                           // Number of pipeline stages for pre-adder (0 or 1)
        .ALUMODEREG(0),                      // Number of pipeline stages for ALUMODE (0 or 1)
        .AREG(0),                            // Number of pipeline stages for A (0, 1 or 2)
        .BCASCREG(0),                        // Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
        .BREG(0),                            // Number of pipeline stages for B (0, 1 or 2)
        .CARRYINREG(0),                      // Number of pipeline stages for CARRYIN (0 or 1)
        .CARRYINSELREG(0),                   // Number of pipeline stages for CARRYINSEL (0 or 1)
        .CREG(0),                            // Number of pipeline stages for C (0 or 1)
        .DREG(0),                            // Number of pipeline stages for D (0 or 1)
        .INMODEREG(0),                       // Number of pipeline stages for INMODE (0 or 1)
        .MREG(0),                            // Number of multiplier pipeline stages (0 or 1)
        .OPMODEREG(0),                       // Number of pipeline stages for OPMODE (0 or 1)
        .PREG(0)                             // Number of pipeline stages for P (0 or 1)
    ) dsp_inst0 (
        // Cascade: 30-bit (each) output: Cascade Ports
        ////.ACOUT(ACOUT),                   // 30-bit output: A port cascade output
        ////.BCOUT(BCOUT),                   // 18-bit output: B port cascade output
        ////.CARRYCASCOUT(CARRYCASCOUT),     // 1-bit output: Cascade carry output
        ////.MULTSIGNOUT(MULTSIGNOUT),       // 1-bit output: Multiplier sign cascade output
        ////.PCOUT(PCOUT),                   // 48-bit output: Cascade output
        // Control: 1-bit (each) output: Control Inputs/Status Bits
        ////.OVERFLOW(OVERFLOW),             // 1-bit output: Overflow in add/acc output
        ////.PATTERNBDETECT(PATTERNBDETECT), // 1-bit output: Pattern bar detect output
        ////.PATTERNDETECT(PATTERNDETECT),   // 1-bit output: Pattern detect output
        ////.UNDERFLOW(UNDERFLOW),           // 1-bit output: Underflow in add/acc output
        // Data: 4-bit (each) output: Data Ports
        .CARRYOUT(dsp0_crout),               // 4-bit output: Carry output
        .P(dsp0_P),                          // 48-bit output: Primary data output
        // Cascade: 30-bit (each) input: Cascade Ports
        ////.ACIN(ACIN),                     // 30-bit input: A cascade data input
        ////.BCIN(BCIN),                     // 18-bit input: B cascade input
        ////.CARRYCASCIN(CARRYCASCIN),       // 1-bit input: Cascade carry input
        ////.MULTSIGNIN(MULTSIGNIN),         // 1-bit input: Multiplier sign input
        ////.PCIN(PCIN),                     // 48-bit input: P cascade input
        // Control: 4-bit (each) input: Control Inputs/Status Bits
        .ALUMODE(dsp0_alumode),              // 4-bit input: ALU control input
        .CARRYINSEL(dsp0_carryinsel),        // 3-bit input: Carry select input
        .CLK(clk),                           // 1-bit input: Clock input
        .INMODE(dsp0_inmode),                // 5-bit input: INMODE control input
        .OPMODE(dsp0_opmode),                // 7-bit input: Operation mode input
        // Data: 30-bit (each) input: Data Ports
        .A(dsp0_A),                          // 30-bit input: A data input
        .B(dsp0_B),                          // 18-bit input: B data input
        .C(dsp0_C),                          // 48-bit input: C data input
        .CARRYIN(dsp0_crin),                 // 1-bit input: Carry input signal
        .D(dsp0_D)                           // 25-bit input: D data input
        // Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
        ////.CEA1(CEA1),                     // 1-bit input: Clock enable input for 1st stage AREG
        ////.CEA2(CEA2),                     // 1-bit input: Clock enable input for 2nd stage AREG
        ////.CEAD(CEAD),                     // 1-bit input: Clock enable input for ADREG
        ////.CEALUMODE(CEALUMODE),           // 1-bit input: Clock enable input for ALUMODE
        ////.CEB1(CEB1),                     // 1-bit input: Clock enable input for 1st stage BREG
        ////.CEB2(CEB2),                     // 1-bit input: Clock enable input for 2nd stage BREG
        ////.CEC(CEC),                       // 1-bit input: Clock enable input for CREG
        ////.CECARRYIN(CECARRYIN),           // 1-bit input: Clock enable input for CARRYINREG
        ////.CECTRL(CECTRL),                 // 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
        ////.CED(CED),                       // 1-bit input: Clock enable input for DREG
        ////.CEINMODE(CEINMODE),             // 1-bit input: Clock enable input for INMODEREG
        ////.CEM(CEM),                       // 1-bit input: Clock enable input for MREG
        ////.CEP(CEP),                       // 1-bit input: Clock enable input for PREG
        ////.RSTA(RSTA),                     // 1-bit input: Reset input for AREG
        ////.RSTALLCARRYIN(RSTALLCARRYIN),   // 1-bit input: Reset input for CARRYINREG
        ////.RSTALUMODE(RSTALUMODE),         // 1-bit input: Reset input for ALUMODEREG
        ////.RSTB(RSTB),                     // 1-bit input: Reset input for BREG
        ////.RSTC(RSTC),                     // 1-bit input: Reset input for CREG
        ////.RSTCTRL(RSTCTRL),               // 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
        ////.RSTD(RSTD),                     // 1-bit input: Reset input for DREG and ADREG
        ////.RSTINMODE(RSTINMODE),           // 1-bit input: Reset input for INMODEREG
        ////.RSTM(RSTM),                     // 1-bit input: Reset input for MREG
        ////.RSTP(RSTP)                      // 1-bit input: Reset input for PREG
    );

`endif

endmodule
