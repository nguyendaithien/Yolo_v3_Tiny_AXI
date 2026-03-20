module top_axi_master_slave #(
  parameter ADDR_WIDTH        = 32  , 
  parameter DATA_WIDTH        = 16  , 
  parameter ID_WIDTH          = 4   ,
  parameter LEN_WIDTH         = 8   , 
  parameter INOUT_WIDTH       = 256 ,
  parameter BUFFER_ADDR_WIDTH = 19  ,
  parameter IFM_WIDTH         = 418 ,
  parameter AXI_WIDTH         = 128 ,
	parameter NUM_LAYER         = 1   ,

	// additional 

parameter SYSTOLIC_SIZE = 16
) (
  output [AXI_WIDTH-1:0]      rdata        ,
  output                      busy_r       ,
  output                      busy_w       ,
  input                       ACLK         ,
  input                       ARESETN      ,
	output wire                 done_wr_layer,
  input                       start_read   ,
	output wire                 done_CNN                          
);
  localparam OFM_SIZE_PACK     = 26;
  localparam IFM_RAM_SIZE      = 524172  ;
  localparam WGT_RAM_SIZE      = 8845488 ;
  localparam OFM_RAM_SIZE_1    = 2205619 ;
  localparam OFM_RAM_SIZE_2    = 259584  ;
  localparam MAX_WGT_FIFO_SIZE = 4608    ;
  localparam RELU_PARAM        = 0       ;
  localparam ADDR_WIDTH_OFM    = ADDR_WIDTH;

  // AXI interconnect wires
  wire [ID_WIDTH-1:0]       AWID     ;
  wire [ADDR_WIDTH_OFM-1:0]     AWADDR   ;
  wire [LEN_WIDTH-1:0]      AWLEN    ;
  wire [2:0]                AWSIZE   ; // kich thuoc 1 tranfer = 2 bytes
  wire [1:0]                AWBURST  ; // loai bnus ( = 01)
  wire                      AWVALID  ;
	wire                      AWREADY  ; 
  wire [8:0]                ifm_size ;
  wire                 read_en_out   ;

  wire [INOUT_WIDTH-1:0]      WDATA ;
  wire [(AXI_WIDTH/8)-1:0] WSTRB    ;
  wire                      WLAST   ;
  wire                      WVALID  ;
  wire                      WREADY  ;
	reg ready_1, ready_2;
	wire wready;
	always @(posedge ACLK or negedge ARESETN) begin
		if(!ARESETN) begin
			ready_1 <= 0;
			ready_2<= 0;
		end else begin
			ready_1 <= WREADY;
			ready_2<= ready_1;
		end
	end
		assign wready = ready_2;


  wire [1:0]                BRESP   ;
  wire                      BVALID  ;
  wire                      BREADY  ;
  wire [ID_WIDTH-1:0]       ARID    ;
  wire [ADDR_WIDTH_OFM-1:0]     ARADDR  ;
  wire [LEN_WIDTH-1:0]      ARLEN   ;
  wire [2:0]                ARSIZE  ;
  wire [1:0]                ARBURST ;
  wire                      ARVALID ;
  wire                      ARREADY ;
  wire [AXI_WIDTH-1:0]      RDATA   ;
  wire [1:0]                RRESP   ;
  wire                      RLAST   ;
  wire                      RVALID  ;
  wire                      RREADY  ;

	reg [AXI_WIDTH-1:0] data_1;
	reg [AXI_WIDTH-1:0] data_2;
	reg [AXI_WIDTH-1:0] data_3;

	reg valid_1;
	reg valid_2;
	reg valid_3;
	reg rlast_1;
	reg rlast_2;
	reg rlast_3;

  wire [ 8:0]                            ofm_size      ;  
	assign ofm_size = OFM_SIZE_PACK;
  wire                                   ofm_read_en   ;  
  wire [ $clog2(OFM_RAM_SIZE_1) - 1 : 0] ofm_addr_read ;  
	wire [ INOUT_WIDTH-1:0]                ofm_data_read ;  
  wire                                   ofm_write_en  ;  
  wire [ $clog2(OFM_RAM_SIZE_1) - 1 : 0] ofm_addr_write;  
  wire [ INOUT_WIDTH-1:0]                ofm_data_write;  
	wire [10:0] num_filter;
	wire [AXI_WIDTH-1:0] WDATA_AXI;

	always @(posedge ACLK or negedge ARESETN) begin
		if(!ARESETN) begin
			data_1  <= '0;  
      data_2  <= '0; 
      data_3  <= '0; 
			valid_1 <= '0;  
      valid_2 <= '0;       
      valid_3 <= '0;

			rlast_1 <= '0;  
      rlast_2 <= '0;       
      rlast_3 <= '0;       
		end else begin
			data_1  <= RDATA   ;
			data_2  <= data_1  ;
			data_3  <= data_2  ;
			valid_1 <= RVALID  ;
			valid_2 <= valid_1 ;
			valid_3 <= valid_2 ;
			rlast_1 <= RLAST   ;
			rlast_2 <= rlast_1 ;
			rlast_3 <= rlast_2 ;
		end
	end
	wire [AXI_WIDTH-1:0] data_4 = data_3;
	wire valid_4 = valid_3;
	wire rlast_4 = rlast_3;
	wire WR_EN;
	wire [BUFFER_ADDR_WIDTH-1:0] ADDR_B;
  wire [INOUT_WIDTH-1:0] data_in; // from bram to IP
	wire start_CNN;
	wire ifm_read_en;
	wire [BUFFER_ADDR_WIDTH-1:0] ifm_addr_a ;
	wire [BUFFER_ADDR_WIDTH-1:0] ADDRB ;


  // ================= Slave =================
  axi_ram #(

    .DATA_WIDTH     (AXI_WIDTH      ), 
    .ADDR_WIDTH     (ADDR_WIDTH     ), 
    .STRB_WIDTH     (1              ), 
    .ID_WIDTH       (ID_WIDTH       ), 
		.TEST_SIZE      (524288         ),
    .PIPELINE_OUTPUT(0) 
  ) u_slave (
    .clk(ACLK),
    .rst(!ARESETN),

    // Write addr
    .s_axi_awid       ( AWID    ) ,// ok
    .s_axi_awaddr     ( AWADDR  ) ,// ok ok
    .s_axi_awlen      ( AWLEN   ) ,// ok
    .s_axi_awsize     ( AWSIZE  ) ,// ok
    .s_axi_awburst    ( AWBURST ) ,// ok

    .s_axi_awvalid    ( AWVALID ) ,
    .s_axi_awready    ( AWREADY ) ,

    // Write data
    .s_axi_wdata      ( WDATA_AXI) ,
    .s_axi_wstrb      ( WSTRB    ) ,
    .s_axi_wlast      ( WLAST    ) ,
    .s_axi_wvalid     ( WVALID   ) ,
    .s_axi_wready     ( WREADY   ) ,

    // Write response
    .s_axi_bresp      ( BRESP   ) ,
    .s_axi_bvalid     ( BVALID  ) ,
    .s_axi_bready     ( BREADY  ) ,

    // Read addr
    .s_axi_arid       ( ARID    ) ,
    .s_axi_araddr     ( ARADDR  ) ,
    .s_axi_arlen      ( ARLEN   ) ,
    .s_axi_arsize     ( ARSIZE  ) ,
    .s_axi_arburst    ( ARBURST ) ,
    .s_axi_arvalid    ( ARVALID ) ,
    .s_axi_arready    ( ARREADY ) ,


    // Read data
    .s_axi_rdata      ( RDATA   ) ,
    .s_axi_rresp      ( RRESP   ) ,
    .s_axi_rlast      ( RLAST   ) ,
    .s_axi_rvalid     ( RVALID  ) ,
    .s_axi_rready     ( RREADY  )

  );

	
  SYSTOLIC_ARRAY_v1_0 #
	(
    .SYSTOLIC_SIZE     ( SYSTOLIC_SIZE      )  ,
    .DATA_WIDTH        ( DATA_WIDTH         )  ,
    .INOUT_WIDTH       ( INOUT_WIDTH        )  ,
    .IFM_RAM_SIZE      ( IFM_RAM_SIZE       )  ,
    .WGT_RAM_SIZE      ( WGT_RAM_SIZE       )  ,
    .OFM_RAM_SIZE_1    ( OFM_RAM_SIZE_1     )  ,
    .OFM_RAM_SIZE_2    ( OFM_RAM_SIZE_2     )  ,
    .MAX_WGT_FIFO_SIZE ( MAX_WGT_FIFO_SIZE  )  ,
    .RELU_PARAM        ( RELU_PARAM         )  ,
    .Q                 ( 9                  )  ,
    .NUM_LAYER         ( NUM_LAYER          )  ,
    .ID_WIDTH          ( 4                  )  ,
    .ADDR_WIDTH        ( 16                 )  ,
    .LEN_WIDTH         ( LEN_WIDTH          )  ,
		.C_M00_AXI_TARGET_SLAVE_BASE_ADDR ( 32'h40000000) ,
		.C_M00_AXI_BURST_LEN              ( 256         ) ,
		.C_M00_AXI_ID_WIDTH               ( 1           ) ,
		.C_M00_AXI_ADDR_WIDTH             ( ADDR_WIDTH          ) ,
		.C_M00_AXI_DATA_WIDTH             ( 128         ) ,
		.C_M00_AXI_AWUSER_WIDTH           ( 0           ) ,
		.C_M00_AXI_ARUSER_WIDTH           ( 0           ) ,
		.C_M00_AXI_WUSER_WIDTH            ( 0           ) ,
		.C_M00_AXI_RUSER_WIDTH            ( 0           ) ,
		.C_M00_AXI_BUSER_WIDTH            ( 0           )
	) wrapper_ip
	(
		.m00_axi_init_axi_txn() ,
		.m00_axi_txn_done    () ,
		.m00_axi_error       () ,
		.m00_axi_aclk        (ACLK) ,
		.m00_axi_aresetn     (ARESETN) ,

		.m00_axi_awid        (AWID    ) ,
		.m00_axi_awaddr      (AWADDR  ) ,
		.m00_axi_awlen       (AWLEN   ) ,
		.m00_axi_awsize      (AWSIZE  ) ,
		.m00_axi_awburst     (AWBURST ) ,
		.m00_axi_awlock      () ,
		.m00_axi_awcache     () ,
		.m00_axi_awprot      () ,
		.m00_axi_awqos       () ,
		.m00_axi_awuser      () ,
		.m00_axi_awvalid     (AWVALID) ,
		.m00_axi_awready     (AWREADY) ,
		.m00_axi_wdata       (WDATA_AXI  ) ,
		.m00_axi_wstrb       (WSTRB  ) ,
		.m00_axi_wlast       (WLAST  ) ,
		.m00_axi_wvalid      (WVALID ) ,
		.m00_axi_wready      (wready ) ,
		.m00_axi_wuser       () ,

		.m00_axi_bid         () ,
		.m00_axi_bresp       (BRESP ) ,
		.m00_axi_bvalid      (BVALID) ,
		.m00_axi_bready      (BREADY) ,
		.m00_axi_buser       () ,

		.m00_axi_arid        (ARID   ) ,
		.m00_axi_araddr      (ARADDR ) ,
		.m00_axi_arlen       (ARLEN  ) ,
		.m00_axi_arsize      (ARSIZE ) ,
		.m00_axi_arburst     (ARBURST) ,
		.m00_axi_arvalid     (ARVALID) ,
		.m00_axi_arready     (ARREADY) ,
		.m00_axi_arlock      () ,
		.m00_axi_arcache     () ,
		.m00_axi_arprot      () ,
		.m00_axi_arqos       () ,
		.m00_axi_aruser      () ,

		.m00_axi_rid         () ,
		.m00_axi_rdata       (data_4) ,
		.m00_axi_rresp       (RRESP ) ,
		.m00_axi_rlast       (rlast_4 ) ,
		.m00_axi_rvalid      (valid_4) ,
		.m00_axi_rready      (RREADY) ,
		.m00_axi_ruser       () ,
		.start               (start_read  ) ,
	  .done_wr_layer       (done_CNN   )	
	);

endmodule
