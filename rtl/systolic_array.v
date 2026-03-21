
`timescale 1 ns / 1 ps

	module SYSTOLIC_ARRAY_v1_0_M00_AXI #
	(
		// Users to add parameters here
	parameter SYSTOLIC_SIZE     = 16      ,
	parameter DATA_WIDTH_RAM    = 128      ,
	parameter DATA_WIDTH        = 16      ,
	parameter INOUT_WIDTH       = 256     ,
	parameter IFM_RAM_SIZE      = 524172  ,
	parameter WGT_RAM_SIZE      = 8845488 ,
	parameter OFM_RAM_SIZE_1    = 2205619 ,
  parameter OFM_RAM_SIZE_2    = 259584  ,
	parameter MAX_WGT_FIFO_SIZE = 4608    ,
	parameter RELU_PARAM        = 0       ,
  parameter Q                 = 9       ,
  parameter NUM_LAYER         = 1       ,

  parameter ID_WIDTH          = 4 ,
  parameter ADDR_WIDTH        = 16,
  parameter LEN_WIDTH         = 8 ,


		// User parameters ends
		// Do not modify the parameters beyond this line

		// Base address of targeted slave
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
		// Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		parameter integer C_M_AXI_BURST_LEN	= 256,
		// Thread ID Width
		parameter integer C_M_AXI_ID_WIDTH	= 1,
		// Width of Address Bus
		parameter integer C_M_AXI_ADDR_WIDTH	= 32,
		// Width of Data Bus
		parameter integer C_M_AXI_DATA_WIDTH	= 128,
		// Width of User Write Address Bus
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		// Width of User Read Address Bus
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		// Width of User Write Data Bus
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		// Width of User Read Data Bus
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		// Width of User Response Bus
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Initiate AXI transactions
		input wire  INIT_AXI_TXN, // start transacsison
		// Asserts when transaction is complete
		output wire  TXN_DONE,
		// Asserts when ERROR is detected
		output reg  ERROR,
		// Global Clock Signal.
		input wire  M_AXI_ACLK,
		// Global Reset Singal. This Signal is Active Low
		input wire  M_AXI_ARESETN,
		// Master Interface Write Address ID
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		// Master Interface Write Address
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		output wire [7 : 0] M_AXI_AWLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		output wire [2 : 0] M_AXI_AWSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		output wire [1 : 0] M_AXI_AWBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		output wire  M_AXI_AWLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		output wire [3 : 0] M_AXI_AWCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_AWPROT,
		// Quality of Service, QoS identifier sent for each write transaction.
		output wire [3 : 0] M_AXI_AWQOS,
		// Optional User-defined signal in the write address channel.
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid write address and control information.
		output wire  M_AXI_AWVALID,
		// Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
		input wire  M_AXI_AWREADY,
		// Master Interface Write Data.
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		// Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		// Write last. This signal indicates the last transfer in a write burst.
		output wire  M_AXI_WLAST,
		// Optional User-defined signal in the write data channel.
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		// Write valid. This signal indicates that valid write
    // data and strobes are available
		output wire  M_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    // can accept the write data.
		input wire  M_AXI_WREADY,
		// Master Interface Write Response.
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		// Write response. This signal indicates the status of the write transaction.
		input wire [1 : 0] M_AXI_BRESP,
		// Optional User-defined signal in the write response channel
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		// Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
		input wire  M_AXI_BVALID,
		// Response ready. This signal indicates that the master
    // can accept a write response.
		output wire  M_AXI_BREADY,
		// Master Interface Read Address.
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		// Read address. This signal indicates the initial
    // address of a read burst transaction.
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		output wire [7 : 0] M_AXI_ARLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		output wire [2 : 0] M_AXI_ARSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		output wire [1 : 0] M_AXI_ARBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		output wire  M_AXI_ARLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		output wire [3 : 0] M_AXI_ARCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_ARPROT,
		// Quality of Service, QoS identifier sent for each read transaction
		output wire [3 : 0] M_AXI_ARQOS,
		// Optional User-defined signal in the read address channel.
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid read address and control information
		output wire  M_AXI_ARVALID,
		// Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
		input wire  M_AXI_ARREADY,
		// Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		// Master Read Data
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		// Read response. This signal indicates the status of the read transfer
		input wire [1 : 0] M_AXI_RRESP,
		// Read last. This signal indicates the last transfer in a read burst
		input wire  M_AXI_RLAST,
		// Optional User-defined signal in the read address channel.
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		// Read valid. This signal indicates that the channel
    // is signaling the required read data.
		input wire  M_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    // accept the read data and response information.
		output wire  M_AXI_RREADY                 , 
    input  wire                   start       ,
    input  wire [INOUT_WIDTH-1:0] ifm_data_in ,
    output wire [18 : 0]          ifm_addr_a  ,
    output wire                   ifm_read_en ,
    output wire                   upsample_mode         ,
    output wire                   done
	);
		localparam DATA_WIDTH_TEST = 128;
		wire done_CNN;
	

    wire [3 : 0] count_layer        ;
    wire [8 : 0] ifm_size           ;
    wire [8 : 0] ofm_size_conv      ;
    wire [8 : 0] ofm_size           ;
    wire [8 : 0] ofm_size_ofm_ram_2 ;
    wire [10: 0] ifm_channel        ;
    wire [1 : 0] kernel_size        ;
    wire [10: 0] num_filter         ;
    wire         maxpool_mode       ;
    wire [1 : 0] maxpool_stride     ;

    wire [$clog2(OFM_RAM_SIZE_1) - 1 : 0] start_write_addr_1 ;
    wire [$clog2(OFM_RAM_SIZE_1) - 1 : 0] start_read_addr_1  ;
    wire [$clog2(OFM_RAM_SIZE_2) - 1 : 0] start_write_addr_2 ;
    wire [$clog2(OFM_RAM_SIZE_2) - 1 : 0] start_read_addr_2  ;
    wire [17: 0]                          ifm_channel_size   ;
    wire [15: 0]                          ofm_channel_size_1 ;
    wire [$clog2(OFM_RAM_SIZE_1) - 1 : 0] write_addr_incr_1  ;
    wire [4 : 0]                          last_write_size_1  ;
    wire [15: 0]                          ofm_channel_size_2 ;
    wire [$clog2(OFM_RAM_SIZE_2) - 1 : 0] write_addr_incr_2  ;
    wire [4 : 0]                          last_write_size_2  ;


    wire [12: 0] num_cycle_load    ;
    wire [12: 0] num_cycle_compute ;
    wire [6 : 0] num_load_filter   ;
    wire [13: 0] num_tiling	       ;

		wire start_layer;

Functional_Unit #(
    .SYSTOLIC_SIZE     ( SYSTOLIC_SIZE     ) ,
    .DATA_WIDTH        ( DATA_WIDTH        ) ,
    .INOUT_WIDTH       ( INOUT_WIDTH       ) ,
    .IFM_RAM_SIZE      ( IFM_RAM_SIZE      ) ,
    .WGT_RAM_SIZE      ( WGT_RAM_SIZE      ) ,
    .OFM_RAM_SIZE_1    ( OFM_RAM_SIZE_1    ) ,
    .OFM_RAM_SIZE_2    ( OFM_RAM_SIZE_2    ) ,
    .MAX_WGT_FIFO_SIZE ( MAX_WGT_FIFO_SIZE ) ,
    .RELU_PARAM        ( RELU_PARAM        ) ,
    .Q                 ( Q                 )
) F_U (
    .clk                ( M_AXI_ACLK         ) ,
    .rst_n              ( M_AXI_ARESETN      ) ,
    .start              ( start_layer        ) ,
    .done               ( done               ) ,

    //Layer config
    .count_layer        ( count_layer        ) ,
    .ifm_size           ( ifm_size           ) ,
    .ofm_size_conv      ( ofm_size_conv      ) ,
    .ofm_size           ( ofm_size           ) ,
    .ofm_size_ofm_ram_2 ( ofm_size_ofm_ram_2 ) ,
    .ifm_channel        ( ifm_channel        ) ,
    .kernel_size        ( kernel_size        ) ,
    .num_filter         ( num_filter         ) ,
    .maxpool_mode       ( maxpool_mode       ) ,
    .maxpool_stride     ( maxpool_stride     ) ,
    .upsample_mode      ( upsample_mode      ) ,

    .start_write_addr_1 ( start_write_addr_1 ) ,
    .start_read_addr_1  ( start_read_addr_1  ) ,
    .start_write_addr_2 ( start_write_addr_2 ) ,
    .start_read_addr_2  ( start_read_addr_2  ) ,
    .ifm_channel_size   ( ifm_channel_size   ) ,
    .ofm_channel_size_1 ( ofm_channel_size_1 ) ,
    .write_addr_incr_1  ( write_addr_incr_1  ) ,
    .last_write_size_1  ( last_write_size_1  ) ,
    .ofm_channel_size_2 ( ofm_channel_size_2 ) ,
    .write_addr_incr_2  ( write_addr_incr_2  ) ,
    .last_write_size_2  ( last_write_size_2  ) ,
    
  	.num_cycle_load     ( num_cycle_load     ) ,
  	.num_cycle_compute  ( num_cycle_compute  ) ,
  	.num_load_filter    ( num_load_filter    ) ,
  	.num_tiling         ( num_tiling         ) ,
	// to ifm bram
    .ifm_read_en        (ifm_read_en         ) ,   
    .ifm_addr_a         (ifm_addr_a          ) ,
  	.ifm_data_in        (ifm_data_in         )                                              
 
);

Control_Unit #(.NUM_LAYER (NUM_LAYER), .OFM_RAM_SIZE_1 (OFM_RAM_SIZE_1), .OFM_RAM_SIZE_2 (OFM_RAM_SIZE_2)) C_U (
    .clk                ( M_AXI_ACLK         ) ,
    .rst_n              ( M_AXI_ARESETN      ) ,
    .start_CNN          ( start              ) ,
    .done_layer         ( done               ) ,
    .start_layer        ( start_layer        ) ,
    .done_CNN           ( done_CNN           ) ,
    
    //Layer config
    .count_layer        ( count_layer        ) ,
    .ifm_size           ( ifm_size           ) ,
    .ofm_size_conv      ( ofm_size_conv      ) ,
    .ofm_size           ( ofm_size           ) ,
    .ofm_size_ofm_ram_2 ( ofm_size_ofm_ram_2 ) ,    
    .ifm_channel        ( ifm_channel        ) ,
    .kernel_size        ( kernel_size        ) ,
    .num_filter         ( num_filter         ) ,
    .maxpool_mode       ( maxpool_mode       ) ,
    .maxpool_stride     ( maxpool_stride     ) ,
    .upsample_mode      ( upsample_mode      ) ,
    
    .start_write_addr_1 ( start_write_addr_1 ) ,
    .start_read_addr_1  ( start_read_addr_1  ) ,
    .start_write_addr_2 ( start_write_addr_2 ) ,
    .start_read_addr_2  ( start_read_addr_2  ) ,
    .ifm_channel_size   ( ifm_channel_size   ) ,
    .ofm_channel_size_1 ( ofm_channel_size_1 ) ,
    .write_addr_incr_1  ( write_addr_incr_1  ) ,
    .last_write_size_1  ( last_write_size_1  ) ,
    .ofm_channel_size_2 ( ofm_channel_size_2 ) ,
    .write_addr_incr_2  ( write_addr_incr_2  ) ,
    .last_write_size_2  ( last_write_size_2  ) ,

  	.num_cycle_load     ( num_cycle_load     ) ,
  	.num_cycle_compute  ( num_cycle_compute  ) ,
  	.num_load_filter    ( num_load_filter    ) ,
  	.num_tiling         ( num_tiling         )
);

endmodule


