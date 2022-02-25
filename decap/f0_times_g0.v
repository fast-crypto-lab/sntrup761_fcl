/*******************************************************************
  Basic operating unit necessary in polynomial inversion on R_3.
  
  Author: Bo-Yuan Peng       bypeng@crypto.tw
          Wei-Chen Bai       go90405@yahoo.com.tw
  Copyright 2021 Academia Sinica

  Version Info:
     Jun.17,2019: 0.1.0 Design ready.

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

module f0_times_g0(f0,f1,g0,g1,c0,c1);

input f0;
input f1;
input g0;
input g1;

wire [3:0] sol = {g1,f1,g0,f0};

output reg c0;
output reg c1;

/*
assign c0 = f0 & g0;
assign c1 = (f1 ^ g1) & (f0 & g0);
*/

always@(*)
begin
	case(sol[1:0])
		3: c0 = 1;
		default: c0 = 0;
	endcase
end

always@(*)
begin
	case(sol)
		7,11: c1 = 1;
		default: c1 = 0;
	endcase
end


endmodule
