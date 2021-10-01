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
module BusMonitor
	(
    input 	wire		clk,				// Main FPGA clock from PLL @ 100 MHz
	input 	wire		a8_clk,				// A8 clock @ ~1.8MHz
	input	wire		a8_rst_n,			// A8 /RST signal
	output 	wire		a8_addr_strobe,		// The address is now valid
	output 	wire		a8_write_strobe,	// Write signals are now valid
	output 	wire		a8_read_strobe,		// Read signals are now valid	
	output 	wire		a8_clk_falling		// The clock cycle is resetting
	);

	
    ///////////////////////////////////////////////////////////////////////////
    // Note that the TICK_xxx compensate for the synchroniser delay in finding
    // the clock edge 
    ///////////////////////////////////////////////////////////////////////////
	localparam 	TICK_BITS				= 7;		// Bits in the counter
	localparam 	TICK_ADDRESS_VALID		= 17;		// Address now valid
	localparam 	TICK_WRITE_VALID		= 41;		// Write data valid
	localparam 	TICK_READ_VALID			= 48;		// Read data valid
	
    ///////////////////////////////////////////////////////////////////////////
    // Sync a8_clk to the FPGA clock using a 3-bit shift register to avoid
    // metastability due to the different clock rates
    ///////////////////////////////////////////////////////////////////////////
	(* async_reg = "true" *) reg [2:0] clkDetect;  
	always @(posedge clk) 
		if (a8_rst_n == 1'b0)
			clkDetect <= 3'b0;
		else
			clkDetect <= {clkDetect[1:0], a8_clk};

    ///////////////////////////////////////////////////////////////////////////
    // We want to know about rising/falling edges to handle bus traffic timing
    ///////////////////////////////////////////////////////////////////////////
	wire a8_clk_rising		= (clkDetect[2:1]==2'b01);   
	assign a8_clk_falling	= (clkDetect[2:1]==2'b10);  

    ///////////////////////////////////////////////////////////////////////////
    // a8_rst_n can be async, so look for a genuine low clock 
    ///////////////////////////////////////////////////////////////////////////
	reg  [1:0] 	validClocks;
	always @(posedge clk)
		if (a8_rst_n == 1'b0)
			validClocks <= 2'b00;
		else
			begin
				if (a8_clk_rising == 1'b1)
					validClocks[0] <= 1'b1;
				if (a8_clk_falling == 1'b1)
					validClocks[1] <= 1'b1;
			end
	assign clkValid = validClocks[0] | validClocks[1];

    ///////////////////////////////////////////////////////////////////////////
    // And validate that clock rise/fall
    ///////////////////////////////////////////////////////////////////////////
	wire a8_clk_rising_valid		= a8_clk_rising & clkValid;   
	wire a8_clk_falling_valid		= a8_clk_falling & clkValid;  
	
    ///////////////////////////////////////////////////////////////////////////
    // Create a counter for how far into the bus-cycle we are
    ///////////////////////////////////////////////////////////////////////////
	reg	[TICK_BITS-1:0]			ticks;					// How far in the cycle
		
	always @ (posedge clk)
		if (a8_rst_n == 1'b0)
			begin
				ticks	<= {TICK_BITS{1'b0}};
			end
		else
			begin
				if (a8_clk_falling_valid == 1'b1)
					begin
						ticks 	<= {TICK_BITS{1'b0}};
					end
				else
					ticks	<= ticks + 7'b1;
			end
	
    ///////////////////////////////////////////////////////////////////////////
    // Create strobes for the three states we're monitoring
    ///////////////////////////////////////////////////////////////////////////
	assign a8_addr_strobe 	= (ticks == TICK_ADDRESS_VALID);
	assign a8_write_strobe	= (ticks == TICK_WRITE_VALID);
	assign a8_read_strobe	= (ticks == TICK_READ_VALID);

endmodule
