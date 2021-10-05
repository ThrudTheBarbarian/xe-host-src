///////////////////////////////////////////////////////////////////////////////
// Useful stuff shared across modules
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ns

//`default_nettype 	none		// Try to catch error early...

`define OP_NONE		2'b00
`define OP_ADD		2'b01
`define OP_DEL		2'b10

// Location of configuration page in A8 memory
`define CFG_PAGE    8'hD6

// XIO interface

`define XIO_STATE_IDLE          4'h0
`define XIO_STATE_WRTS          4'h1
`define XIO_STATE_WCTS          4'h2
`define XIO_STATE_CMD           4'h3
`define XIO_STATE_CLK           4'h4
`define XIO_STATE_B3            4'h5
`define XIO_STATE_B2            4'h6
`define XIO_STATE_B1            4'h7
`define XIO_STATE_B0            4'h8
`define XIO_STATE_DONE          4'h9

`define XIO_CMD_SDRAM_READ      4'h1
