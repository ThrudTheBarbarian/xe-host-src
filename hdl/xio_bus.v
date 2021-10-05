`include "defines.v"

///////////////////////////////////////////////////////////////////////////////
// xio bus 
//
// Basically a parallel bus with dual rts/cts/clk signals
///////////////////////////////////////////////////////////////////////////////


module xio_bus 
	(
    input   wire            clk,                // System clock
    input   wire            rst_n,              // System reset
    
  	input   wire 	[7:0] 	rData,				// Input from bus
    input   wire            rRts,               // Input is ready to send
    input   wire            rClk,               // Input data strobe
    output  reg             rCts,               // Input is clear to send
    
  	output  reg 	[7:0] 	wData, 				// Output to bus
    output  reg     [7:0]   wEn,                // Toggles between input (0) and output(1)
    output  reg             wRts,               // Output is ready to send
    output  reg             wClk,               // Output data strobe
    input   wire            wCts,               // Output is clear to send
    
    input   wire    [31:0]  data,               // Data to transmit
    input   wire    [3:0]   cmd,                // Data command 
    input   wire            cmdValid            // Data command strobe, 0=idle
  	);

    reg [3:0]   xioState;                       // State machine
    reg [3:0]   xioNext;                        // Next state
    reg [31:0]  xioData;                        // Data to send
    reg [3:0]   xioCmd;                         // Command to send
    
    
    always @ (posedge clk)
        begin
            if (rst_n == 1'b0)
                begin
                    rCts        <= 1'b0;            // Not clear to send to us
                    wData       <= 8'b0;            // write-data = 0
                    wEn         <= 8'b0;            // output disabled
                    wRts        <= 1'b0;            // We are not ready to send
                    wClk        <= 1'b0;            // Initialise outgoing data strobe
                    xioState    <= `XIO_STATE_IDLE; // Initialise the state machine
                    xioData     <= 32'b0;           // Start off with data = 0
                    xioCmd      <= 4'b0;            // Start off with no command
                end
            
            else
                if (cmdValid)
                    begin
                        xioData     <= data;
                        xioCmd      <= cmd;
                        xioState    <= `XIO_STATE_WRTS;
                    end
              
            else 
                case (xioState)
                    `XIO_STATE_IDLE:
                        begin
                            xioState        <= `XIO_STATE_IDLE;
                        end
                    
                    `XIO_STATE_WRTS:
                        begin
                            wRts            <= 1'b1;
                            xioState        <= `XIO_STATE_WCTS;
                        end
                    
                    `XIO_STATE_WCTS:
                        begin
                            if (wCts == 1'b1)
                                begin
                                    xioState    <= `XIO_STATE_CMD;
                                    wEn         <= 8'hff;
                                end
                        end
                 
                    `XIO_STATE_CMD:
                        begin
                            wData           <= {4'b0,cmd};
                            wClk            <= 1'b1;
                            xioState        <= `XIO_STATE_CLK;
                            case (cmd)
                                `XIO_CMD_SDRAM_READ:    xioNext     <= `XIO_STATE_B3;
                                default            :    xioNext     <= `XIO_STATE_DONE;
                            endcase;
                        end
                   
                    `XIO_STATE_CLK:
                        begin   
                            wClk            <= 1'b0;
                            xioState        <= xioNext;
                        end
                   
                    `XIO_STATE_B3:
                        begin   
                            wData           <= xioData[31:24];
                            wClk            <= 1'b1;
                            xioNext         <= `XIO_STATE_B2;
                            xioState        <= `XIO_STATE_CLK;
                        end
                   
                    `XIO_STATE_B2:
                        begin   
                            wData           <= xioData[23:16];
                            wClk            <= 1'b1;
                            xioNext         <= `XIO_STATE_B1;
                            xioState        <= `XIO_STATE_CLK;
                        end
                   
                    `XIO_STATE_B1:
                        begin   
                            wData           <= xioData[15:8];
                            wClk            <= 1'b1;
                            xioNext         <= `XIO_STATE_B0;
                            xioState        <= `XIO_STATE_CLK;
                        end
                   
                    `XIO_STATE_B0:
                        begin   
                            wData           <= xioData[7:0];
                            wClk            <= 1'b1;
                            xioNext         <= `XIO_STATE_DONE;
                            xioState        <= `XIO_STATE_CLK;
                        end
                     
                    `XIO_STATE_DONE:
                        begin
                            wEn             <= 8'h0;
                            wRts            <= 1'b0;
                            xioState        <= `XIO_STATE_IDLE;
                        end
                      
                endcase
        end
        
endmodule