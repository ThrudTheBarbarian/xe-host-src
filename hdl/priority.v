`include "defines.v"

///////////////////////////////////////////////////////////////////////////////
// Priority Encoder module. 
//
// The upper bit of the index is set if none of the 'bits' are set
///////////////////////////////////////////////////////////////////////////////

module PriorityEncoder 
	(
  	input wire 	[7:0] 	bits,				// Input, expects 1 bit set
  	output reg 	[3:0] 	index				// Priority-encoded result
  	);

  	always @ * 
  		begin
  			casez (bits)
				8'b1zzzzzzz : index = 4'h7;
				8'b01zzzzzz : index = 4'h6;
				8'b001zzzzz : index = 4'h5;
				8'b0001zzzz : index = 4'h4;
				8'b00001zzz : index = 4'h3;
				8'b000001zz : index = 4'h2;
				8'b0000001z : index = 4'h1;
				8'b00000001 : index = 4'h0;
				default		: index = 4'h8;
    		endcase
  		end
endmodule