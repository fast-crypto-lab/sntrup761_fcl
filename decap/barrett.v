/******************************************************************* 
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

module barrett ( dividend, m0, m0_inverse, quotient, remainder ) ;

    parameter M0LEN = 14;
    parameter SHIFT = 27;

    localparam M0LEN2 = M0LEN * 2;

    input   [M0LEN2-1:0]    dividend;
    input   [M0LEN-1:0]     m0;
    input   [SHIFT-1:0]     m0_inverse;
    output  [M0LEN-1:0]     quotient;
    output  [M0LEN-1:0]     remainder;

    wire    [M0LEN2+SHIFT-1:0]  quo2;
    wire    [M0LEN-1:0]         q0;
    wire    [M0LEN-1:0]         q1;
    wire    [M0LEN-1:0]         r0;
    wire    [M0LEN:0]           r1;

    assign quo2 = { { SHIFT {1'b0} }, dividend } * { { M0LEN2 {1'b0} }, m0_inverse };

    assign q0 = quo2[SHIFT +: M0LEN];
    assign q1 = q0 + { { (M0LEN - 1) {1'b0} }, {1'b1} };
    assign r0 = dividend - { { M0LEN {1'b0} }, q0 } * { { M0LEN {1'b0} }, m0 };
    assign r1 = { 1'b0, r0 } - { 1'b0, m0 };

    assign quotient = r1[M0LEN] ? q0 : q1;
    assign remainder = r1[M0LEN] ? r0 : r1[M0LEN-1:0];

endmodule

