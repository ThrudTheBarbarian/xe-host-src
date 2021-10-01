`include "defines.v"

///////////////////////////////////////////////////////////////////////////////
// Top module. 
//
// This is an interface to the far-more-capable FPGA at the other end of the
// link. The goal here is to quickly respond to any local signals that need
// attention, and to push any request up to the large FPGA at the other end
// of the link.
//
// Need to decide:
// 
//  o When clock-fall happens, signal that to zynq
//      - Also reset local A8 bus
// 
//  o When address becomes valid, is this a DDR access. 
//      - If so, set /EXTSEL (and /MPD if appropriate)
//      - Send address up as address packet to Zynq
//      - Or send DDR-read request packet to Zynq
//  
//  o When get incoming packet from Zynq
//      - If current access is 'read' and we're sourcing from DDR3, store datum
//
//  o If we have a 'read' and we're sourcing from DDR
//      - Wait until time expires
//      - Drive bus with stored datum
//
//  o If we have a 'write'... Is this a DDR access ?
//      - If so, send write packet/DDR address up to Zynq
//      - if not, send write packet/64k adress up to Zynq
//
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
// Note that there can be 7-10ns taken for level translation so we have ~30ns
// of actual response time for /MPD to be asserted
//
///////////////////////////////////////////////////////////////////////////////
module xe_host
	#(parameter ANUM=8)					// Number of Apertures
    (
    // A8 bus signals
	input				a8_clk,			// A8 clock @ ~1.8MHz
	input				a8_rd5,			// A8 rd5 cartridge signal
	input				a8_rd4,			// A8 rd4 cartridge signal
	output reg			a8_irq_n,		// A8 /IRQ signal
	output   			a8_mpd_n,		// A8 Math-Pak Disable (/MPD) signal
	output   			a8_extsel_n,	// A8 external selection signal
    
    // A8 bi-directional bus signals
	input	    [15:0]	a8_a_IN,	    // A8 address bus inputs
    output  reg [15:0]  a8_a_OUT,       // A8 address bus output values when..
    output  reg [15:0]  a8_a_OE,        // A8 address bus output-enables are high          

   	input	    [7:0]   a8_d_IN,	    // A8 data bus inputs
    output  reg [7:0]   a8_d_OUT,       // A8 data bus output values when..
    output  reg [7:0]   a8_d_OE,        // A8 data bus output-enables are high
  
	input				a8_halt_n_IN,	// A8 /HALT signal input
	output	reg			a8_halt_n_OUT,	// A8 /HALT signal output value when..
	output	reg			a8_halt_n_OE,	// A8 /HALT signal output-enable is high
  
  	input				a8_ref_n_IN,	// A8 Dram refresh (/REF) signal input
  	output	reg			a8_ref_n_OUT,	// A8 Dram refresh (/REF) output value when..
  	output	reg			a8_ref_n_OE,	// A8 Dram refresh (/REF) output-enable is high

    input				a8_rst_n_IN,	// A8 /RST signal input
    output	reg			a8_rst_n_OUT,	// A8 /RST signal output value when..
    output	reg			a8_rst_n_OE,	// A8 /RST signal output-enable is high

 	input				a8_rw_IN,		// A8 read/write signal input
	output	reg			a8_rw_OUT,		// A8 read/write signal output value when..
	output	reg			a8_rw_OE,		// A8 read/write signal output-enable is high
   
    // A8 bus controls
    output  reg         a8_a_dir,       // Directionality of A8 address bus
    output  reg         a8_d_dir,       // Directionality of A8 data bus
    output  reg         a8_halt_dir,    // Directionality of A8 /HALT
    output  reg         a8_ref_dir,     // Directionality of A8 /REF
    output  reg         a8_rst_dir,     // Directionality of A8 /RST
    output  reg         a8_rw_dir,      // Directionality of A8 R/W
 
	input	            sysclk,         // system clock         
    input               pll0_locked     // PLL has locked and we're ready to go
 );

    ///////////////////////////////////////////////////////////////////////////
    // Generate variables
    ///////////////////////////////////////////////////////////////////////////
	genvar i;
	
    ///////////////////////////////////////////////////////////////////////////
    // Instantiate a bus-monitor
    ///////////////////////////////////////////////////////////////////////////
    wire 		a8_addr_strobe;
    wire		a8_read_strobe;
    wire		a8_write_strobe;		
	wire		a8_clk_falling;
	
	BusMonitor busMon
		(
		.clk(sysclk),
		.a8_clk(a8_clk),
		.a8_rst_n(a8_rst_n_IN),
		.a8_addr_strobe(a8_addr_strobe),
		.a8_write_strobe(a8_write_strobe),
		.a8_read_strobe(a8_read_strobe),
		.a8_clk_falling(a8_clk_falling)
		);

		
    ///////////////////////////////////////////////////////////////////////////
    // Instantiate ANUM memory apertures
    ///////////////////////////////////////////////////////////////////////////
	wire [ANUM-1:0] inRange;			// Flags from each of the apertures
	wire [7:0] apCfg [0:ANUM-1];		// Configuration data from aperture
	wire apCfgValid[ANUM-1:0];			// If config is valid
	wire [23:0] apBase [0:ANUM-1];		// SDRAM addresses
	
	generate for (i=0; i<ANUM; i=i+1)
		begin		
			Aperture aperture
				(
				.clk(sysclk),
				.a8_rst_n(a8_rst_n_IN),
				.a8_rw_n(a8_rw_IN),
				.a8_data(a8_d_IN),
				.wValid(a8_write_strobe),
				.aValid(a8_addr_strobe),
				.addr(a8_a_IN),
				.index(i[3:0]),
				.inRange(inRange[i]),
				.apCfg(apCfg[i]),
				.apCfgValid(apCfgValid[i]),
				.baseAddr(apBase[i])
				);
		end
	endgenerate
	
    ///////////////////////////////////////////////////////////////////////////
    // Figure out which aperture is currently signalling that it's in range.
    // Note that the priority encoder is not parameterised... 
    ///////////////////////////////////////////////////////////////////////////
   	wire [$clog2(ANUM):0] apIndex;
    PriorityEncoder pEnc
    	(
    	.bits(inRange),
    	.index(apIndex)
    	);
    	
    ///////////////////////////////////////////////////////////////////////////
    // Determine and save the aperture's effective address
    ///////////////////////////////////////////////////////////////////////////
	reg [31:0] 	sdramAddr;
	reg 		sdramValid;
	
	always @(posedge sysclk)
		if (a8_rst_n_IN == 1'b0)
			begin
				sdramAddr 	<= 32'b0;
				sdramValid	<= 1'b0;
			end
			
		else if (apIndex[3] == 1'b1)
			begin
				if (a8_clk_falling)
					sdramValid		<= 1'b0;
			end
		else
			begin
				sdramValid 	<= 1'b1;
				case (apIndex[2:0])
					3'h0	: sdramAddr <= {apBase[0],a8_a_IN[7:0]};
					3'h1	: sdramAddr <= {apBase[1],a8_a_IN[7:0]};
					3'h2	: sdramAddr <= {apBase[2],a8_a_IN[7:0]};
					3'h3	: sdramAddr <= {apBase[3],a8_a_IN[7:0]};
					3'h4	: sdramAddr <= {apBase[4],a8_a_IN[7:0]};
					3'h5	: sdramAddr <= {apBase[5],a8_a_IN[7:0]};
					3'h6	: sdramAddr <= {apBase[6],a8_a_IN[7:0]};
					3'h7	: sdramAddr <= {apBase[7],a8_a_IN[7:0]};
				endcase
			end


    ///////////////////////////////////////////////////////////////////////////
    // Handle /MPD and /EXTSEL
    ///////////////////////////////////////////////////////////////////////////
	reg 		extAccessValid;
	
	always @(posedge sysclk)
		if (a8_rst_n_IN == 1'b0)
			extAccessValid	<= 1'b0;
			
		else if (apIndex[3] == 1'b1)
			begin
				if (a8_write_strobe)
					extAccessValid	<= 1'b0;
			end
		else
			extAccessValid  <= 1'b1;
			
    wire sdramRead 	        = (a8_rw_IN == 1'b1) & extAccessValid;
    assign a8_mpd_n		    = ~sdramRead;
    assign a8_extsel_n	    = ~sdramRead;

    wire sdramWrite         = (a8_rw_IN == 1'b0) & extAccessValid;
	
    	
endmodule
