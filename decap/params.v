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

`ifndef PARAMS_V
`define PARAMS_V

`define RP_D_SIZE   (14)
`define RP_D_SIZE2  (`RP_D_SIZE * 2)
`define RP_INV_SIZE (27)
`define RP_DEPTH    (10) /* 1024 at most */
`define RP_DEPTH_2  (`RP_DEPTH - 1)
`define RP_SIZE     (1 << `RP_DEPTH)
`define RP_SIZE_2   (1 << `RP_DEPTH_2)
`define OUT_D_SIZE  (8)
`define OUT_DEPTH   (11) /* 2048 at most */
`define OUT_SIZE    (1 << `OUT_DEPTH)

`endif

