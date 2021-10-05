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
 
    // XIO interface
   	input	    [7:0]   xio_data_IN,    // XIO data bus inputs
    output      [7:0]   xio_data_OUT,   // XIO data bus output values when..
    output      [7:0]   xio_data_OE,    // XIO data bus output-enables are high
  
    output              xio_host_clk,   // XIO host data strobe
    output              xio_host_rts,   // XIO host is ready to send
    input               xio_host_cts,   // XIO host is clear to send
    
    input               xio_box_clk,    // XIO box data strobe
    input               xio_box_rts,    // XIO box is ready to send
    output              xio_box_cts,    // XIO box is clear to send
 
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
	wire [31:0] apBase [0:ANUM-1];		// SDRAM addresses
	
	generate for (i=0; i<ANUM; i=i+1)
		begin		
			Aperture aperture
				(
				.clk(sysclk),
				.a8_rst_n(a8_rst_n_IN),
				.a8_rw_n(a8_rw_IN),
				.a8_data(a8_d_IN),
				.a8_addr(a8_a_IN),
				.wValid(a8_write_strobe),
				.aValid(a8_addr_strobe),
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
    // Handle /MPD and /EXTSEL
    ///////////////////////////////////////////////////////////////////////////
	reg 		extAccessValid;
	
	always @(posedge sysclk)
		if (a8_rst_n_IN == 1'b0)
			extAccessValid	<= 1'b0;
		
        // If the high-bit is set, that's a flag for 'not in range'
		else if (apIndex[3] == 1'b0) 
			extAccessValid	<= 1'b1;
 
        // and if the a8 clock is falling we need to reset
        else if  (a8_clk_falling == 1'b1)
			extAccessValid	<= 1'b0;
		
    wire sdramRead 	        = (a8_rw_IN == 1'b1) & extAccessValid;
    assign a8_mpd_n		    = ~sdramRead;
    assign a8_extsel_n	    = ~sdramRead;

    ///////////////////////////////////////////////////////////////////////////
    // Determine and save the aperture's S address
    ///////////////////////////////////////////////////////////////////////////
    reg     [31:0]  sdramBase;
	reg 	    	sdramValid;

	
	always @(posedge sysclk)
		if (a8_rst_n_IN == 1'b0)
			begin
				sdramBase 	<= 32'b0;
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
					3'h0    : sdramBase  <= apBase[0];                        
					3'h1    : sdramBase  <= apBase[1];                        
					3'h2    : sdramBase  <= apBase[2];                        
					3'h3    : sdramBase  <= apBase[3];                        
					3'h4    : sdramBase  <= apBase[4];                        
					3'h5    : sdramBase  <= apBase[5];                        
					3'h6    : sdramBase  <= apBase[6];                        
					3'h7    : sdramBase  <= apBase[7];                        
				endcase
			end
    
    wire [31:0] sdramAddr = sdramBase + {24'b0,a8_a_IN[7:0]};

       
    ///////////////////////////////////////////////////////////////////////////
    // If we have a valid SDRAM request, then send it off to the bus to xmit
    ///////////////////////////////////////////////////////////////////////////
    reg             sdramLast;
    
    always @ (posedge sysclk)
        if (a8_rst_n == 1'b0)
            begin
                sdramLast       <= 1'b0;
            end
        else
            sdramLast <= sdramValid;
     
    ///////////////////////////////////////////////////////////////////////////
    // Instantiate the bus to talk to the Zynq FPGA
    ///////////////////////////////////////////////////////////////////////////
    reg     [31:0]  xData;
    reg     [3:0]   xCmd;
    reg             xCmdValid;
    
    xio_bus xio
        (
		.clk(sysclk),
		.rst_n(a8_rst_n),
        .rData(xio_data_IN),
        .rRts(xio_box_rts),
        .rClk(xio_box_clk),
        .rCts(xio_box_cts),
        .wData(xio_data_OUT),
        .wEn(xio_data_OE),
        .wRts(xio_host_rts),
        .wClk(xio_host_clk),
        .wCts(xio_host_cts),
        .data(xData),
        .cmd(xCmd),
        .cmdValid(xCmdValid)
        );

     
       
    ///////////////////////////////////////////////////////////////////////////
    // If we have a valid SDRAM request, then send it off to the bus to xmit
    ///////////////////////////////////////////////////////////////////////////
    always @ (posedge sysclk)
        begin
            if (a8_rst_n == 1'b0)
                begin
                    xCmdValid       <= 1'b0;
                    xCmd            <= 4'h0;
                    xData           <= 31'h0;
                end
            else if (xCmdValid == 1'b1)
                xCmdValid <= 1'b0;
            else if ((sdramValid == 1'b1) && (sdramLast == 1'b0))
                begin
                    xCmdValid       <= 1'b1;
                    xData           <= sdramAddr;
                    xCmd            <= `XIO_CMD_SDRAM_READ;
                end
        end
        
endmodule
