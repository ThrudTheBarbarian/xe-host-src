`include "defines.v"

///////////////////////////////////////////////////////////////////////////////
// Bus monitor module. 
//
// Timings are:
//
//	|<------------------------- Cycle time 558ns ---------------------->|
//
//	|__________________________________|--------------------------------|
//
//	|<---- 177ns ---->|XXXXXXXXX Valid Address XXXXXXXXXXXXXXXXXXXXXXXXXXXX|
//
// 	|<------------------------------- 422ns ----------->|XXXXXXX Write XXXXXXX|
//
// 	|<------------------------------- 486ns --------------->|XXXX Read XXXX|
//
//
//	|<------- 195ns ------->| ExtenB
//  |_______________________|-------------------------------------------|
//
//	|<---------- 225 ns ----------| MPD
//  |-----------------------------|_____________________________________|
//
// 
///////////////////////////////////////////////////////////////////////////////

module xe_host_tb;

	reg clk, a8_clk;
	
	///////////////////////////////////////////////////////////////////////////
	// Instantiate an MPD decoder
	///////////////////////////////////////////////////////////////////////////
	reg		[15:0]	a8_addr;
	reg		[7:0]	a8_data;
	reg				a8_rw_n;
	reg				a8_halt_n;
	reg				a8_rst_n;
	reg				a8_rd5;
	reg				a8_rd4;
	reg				a8_ref_n;
	
	wire			a8_irq_n;
	wire			a8_mpd_n;
	wire			a8_extsel_n;
	
	wire			mpd;
	
    wire            xio_rts;
    reg             xio_cts;
    
	xe_host dut
		(
		.sysclk(clk),
		.a8_clk(a8_clk),
		.a8_rw_IN(a8_rw_n),
		.a8_halt_n_IN(a8_halt_n),
		.a8_irq_n(a8_irq_n),
		.a8_a_IN(a8_addr),
		.a8_d_IN(a8_data),
		.a8_rst_n_IN(a8_rst_n),
		.a8_rd5(a8_rd5),
		.a8_rd4(a8_rd4),
		.a8_ref_n_IN(a8_ref_n),
		.a8_mpd_n(a8_mpd_n),
		.a8_extsel_n(a8_extsel_n),
        .xio_host_rts(xio_rts),
        .xio_host_cts(xio_cts)
		);
	
	///////////////////////////////////////////////////////////////////////////
	// Set everything going
	///////////////////////////////////////////////////////////////////////////
    initial
        begin
            $dumpfile("/tmp/wave.vcd");
            $dumpvars(0, xe_host_tb);
                
            		clk 		= 1'b0;
            		a8_clk 		= 1'b0;
					a8_rw_n		= 1'b1;
            		a8_rst_n   	= 1'b1;
            		a8_halt_n	= 1'b1;
            		a8_addr	 	= 16'h0;
            		a8_data	 	= 16'h0;
            		a8_rd5		= 1'b0;
            		a8_rd4		= 1'b0;
            		a8_ref_n	= 1'b1;
            		
			// Enter a reset cycle		
			#558 	a8_rst_n	= 1'b0;
			
			#558 	a8_rst_n	= 1'b1;
			
			
			// Write to memory-aperture 0 : set start
			#177
				 	a8_addr		= 16'hd604;
             		a8_rw_n		= 1'b0;
            #245
            		a8_data		= 8'h05;
			#136
			
			
			// Write to memory-aperture 0 : set end
			#177
				 	a8_addr		= 16'hd605;
            #245
            		a8_data		= 8'h10;
			#136
			
			// Write to memory-aperture 0 : set SDRAM start
			#177
				 	a8_addr		= 16'hd601;
             		a8_rw_n		= 1'b0;
            #245
            		a8_data		= 8'h01;
			#136


			// Disable write, will do a read			
			#177
				 	a8_rw_n		= 1'b1;
					a8_addr		= 16'hd604;
            #381


					
			// Read elsewhere			
			#177
					a8_addr		= 16'h607;
            #381
					
			// Read elsewhere			
			#177
					a8_addr		= 16'h639;
            #381

			// Finish
            #558 	$finish;
		end

	///////////////////////////////////////////////////////////////////////////
	// handle the xio rts/cts
	///////////////////////////////////////////////////////////////////////////
    always @ (posedge clk)
        begin
            xio_cts <= xio_rts;
        end
        
        
        
	///////////////////////////////////////////////////////////////////////////
	// Toggle the clocks indefinitely
	///////////////////////////////////////////////////////////////////////////
    always 
        	#5 		clk = ~clk;
    always 
			#279	a8_clk = ~a8_clk;
			
endmodule
