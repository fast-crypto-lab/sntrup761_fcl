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

module f0_adds_g0(f0,f1,g0,g1,c0,c1);

input f0;
input f1;
input g0;
input g1;

output c0;
output c1;




assign c0 = (f0 ^ g0) | (f1 & g1) | ((!f1) & f0 & (!g1));
assign c1 = ((!f0) & g1) | ((!f1) & f0 & (!g1) & g0) | (f1 & (!g0));

endmodule
