`include "defines.v"

///////////////////////////////////////////////////////////////////////////////
// Priority module testbench. 
//
// Timings are:
// 
///////////////////////////////////////////////////////////////////////////////

module priority_tb;

	
	///////////////////////////////////////////////////////////////////////////
	// Instantiate a priority encoder
	///////////////////////////////////////////////////////////////////////////
	reg [7:0] dIn;
	wire [3:0] dOut;
	
	PriorityEncoder dut
		(
		.bits(dIn),
		.index(dOut)
		);
	
	///////////////////////////////////////////////////////////////////////////
	// Set everything going
	///////////////////////////////////////////////////////////////////////////
    initial
        begin
            $dumpfile("/tmp/priority.vcd");
            $dumpvars(0, priority_tb);
                
					dIn = 8'h0;
			
			#10		dIn = 8'h01;
			
			#10		dIn = 8'h02;
			
			#10		dIn = 8'h04;
			
			#10		dIn = 8'h08;
			
			#10 	dIn = 8'h10;
			
			#10		dIn = 8'h20;
			
			#10		dIn = 8'h40;
			
			#10 	dIn = 8'h80;
			
			#40		dIn = 8'h07;
			
			#10		dIn = 8'h30;
			            		
            #10 	$finish;
		end

endmodule
