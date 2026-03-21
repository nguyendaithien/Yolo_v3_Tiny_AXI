module top_axi_master_slave #(
  parameter ADDR_WIDTH        = 16  , 
  parameter DATA_WIDTH        = 16  , 
  parameter ID_WIDTH          = 4   ,
  parameter LEN_WIDTH         = 8   , 
  parameter INOUT_WIDTH       = 256 ,
  parameter BUFFER_ADDR_WIDTH = 19  ,
  parameter IFM_WIDTH         = 418 ,
  parameter AXI_WIDTH         = 128 ,

	// additional 
	parameter SYSTOLIC_SIZE = 16
) (
  input                       rd_en       ,
  input                     	wr_en       ,
  input  [ADDR_WIDTH-1:0]     addr_R      ,
  input  [ADDR_WIDTH-1:0]     addr_W      ,
  input  [AXI_WIDTH-1:0]     wdata       ,
  output [AXI_WIDTH-1:0]      rdata       ,
  output                      busy_r      ,
  output                      busy_w      ,
  input                       ACLK        ,
  input                       ARESETN     ,
  input [10:0]                num_channel ,
  output wire                 read_en_out ,
  input                       start_read  ,
  input                       wr_en_test  ,
	output done_CNN                         ,
  input [8:0]                 ifm_size
);
  localparam IFM_RAM_SIZE      = 524172  ;
  localparam WGT_RAM_SIZE      = 8845488 ;
  localparam OFM_RAM_SIZE_1    = 2205619 ;
  localparam OFM_RAM_SIZE_2    = 259584  ;
  localparam MAX_WGT_FIFO_SIZE = 4608    ;
  localparam RELU_PARAM        = 0       ;

  // AXI interconnect wires
  wire [ID_WIDTH-1:0]       AWID;
  wire [ADDR_WIDTH-1:0]     AWADDR;
  wire [LEN_WIDTH-1:0]      AWLEN;
  wire [2:0]                AWSIZE; // kich thuoc 1 tranfer = 2 bytes
  wire [1:0]                AWBURST; // loai bnus ( = 01) 
  wire                      AWVALID;
  wire                      AWREADY;

  wire [AXI_WIDTH-1:0]      WDATA;
  wire [(AXI_WIDTH/8)-1:0] WSTRB;
  wire                      WLAST;
  wire                      WVALID;
  wire                      WREADY;

  wire [1:0]                BRESP;
  wire                      BVALID;
  wire                      BREADY;

  wire [ID_WIDTH-1:0]       ARID;
  wire [ADDR_WIDTH-1:0]     ARADDR;
  wire [LEN_WIDTH-1:0]      ARLEN;  // 255
  wire [2:0]                ARSIZE; // 16 byte = 128 bits => 3'b100
  wire [1:0]                ARBURST; // = 01
  wire                      ARVALID;
  wire                      ARREADY;

  wire [AXI_WIDTH-1:0]      RDATA;
  wire [1:0]                RRESP;
  wire                      RLAST;
  wire                      RVALID;
  wire                      RREADY;

	reg [AXI_WIDTH-1:0] data_1;
	reg [AXI_WIDTH-1:0] data_2;
	reg [AXI_WIDTH-1:0] data_3;

	reg valid_1;
	reg valid_2;
	reg valid_3;
	reg rlast_1;
	reg rlast_2;
	reg rlast_3;

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
			data_1 <= RDATA; 
			data_2 <= data_1;
			data_3 <= data_2;
			valid_1 <= RVALID;  
			valid_2 <= valid_1;  
			valid_3 <= valid_2;  
			rlast_1 <= RLAST;  
			rlast_2 <= rlast_1;  
			rlast_3 <= rlast_2;  
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
  // ================= Master =================
  AXI_MASTER_IF #    (
  .ADDR_WIDTH        ( ADDR_WIDTH        ) ,
  .BUFFER_ADDR_WIDTH ( BUFFER_ADDR_WIDTH ) ,
  .DATA_WIDTH        ( DATA_WIDTH        ) ,
  .ID_WIDTH          ( ID_WIDTH          ) ,
  .INOUT_WIDTH       ( INOUT_WIDTH       ) ,
  .AXI_WIDTH         ( AXI_WIDTH         ) ,
  .LEN_WIDTH         ( LEN_WIDTH         )
  ) u_master         (
    .ACLK      ( ACLK    ) ,
    .ARESETN   ( ARESETN ) ,
    .RD_EN     ( rd_en   ) ,
    .WR_EN     ( wr_en   ) ,
    .ADDR_R    ( addr_R  ) ,
    .ADDR_W    ( addr_W  ) ,
    .WDATA_IN  ( wdata   ) ,
    .RDATA_OUT ( rdata   ) ,
    .BUSY_R    ( busy_r  ) ,
    .BUSY_W    ( busy_w  ) ,

    // Write address channel
    .M_AXI_AWID           ( AWID        ) ,
    .M_AXI_AWADDR         ( AWADDR      ) ,
    .M_AXI_AWLEN          ( AWLEN       ) ,
    .M_AXI_AWSIZE         ( AWSIZE      ) ,
    .M_AXI_AWBURST        ( AWBURST     ) ,
    .M_AXI_AWVALID        ( AWVALID     ) ,
    .M_AXI_AWREADY        ( AWREADY     ) ,

    // Write data channel
    .M_AXI_WDATA          ( WDATA       ) ,
    .M_AXI_WSTRB          ( WSTRB       ) ,
    .M_AXI_WLAST          ( WLAST       ) ,
    .M_AXI_WVALID         ( WVALID      ) ,
    .M_AXI_WREADY         ( WREADY      ) ,

    // Write response
    .M_AXI_BRESP          ( BRESP       ) ,
    .M_AXI_BVALID         ( BVALID      ) ,
    .M_AXI_BREADY         ( BREADY      ) ,

    // Read address
    .M_AXI_ARID           ( ARID        ) ,
    .M_AXI_ARADDR         ( ARADDR      ) ,
    .M_AXI_ARLEN          ( ARLEN       ) ,
    .M_AXI_ARSIZE         ( ARSIZE      ) ,
    .M_AXI_ARBURST        ( ARBURST     ) ,
    .M_AXI_ARVALID        ( ARVALID     ) ,
    .M_AXI_ARREADY        ( ARREADY     ) ,

    // Read data
    .M_AXI_RDATA          ( data_4      ) ,
    .M_AXI_RRESP          ( RRESP       ) ,
    .M_AXI_RLAST          ( rlast_4     ) ,
    .M_AXI_RVALID         ( valid_4     ) ,
    .M_AXI_RREADY         ( RREADY      ) ,
    .num_channel          ( num_channel ) ,
    .read_en_out          ( read_en_out ) ,
    .start_read           ( start_read  ) ,
    .ifm_size             ( ifm_size    ) ,
    .ifm_address_buffer   ( ADDR_B      ) ,
    .wr_en_ifm_buffer     ( WR_EN       ) ,
		.start_CNN            (start_CNN    )
  );

  // ================= Slave =================
  axi_ram #(

    .DATA_WIDTH     (AXI_WIDTH      ), 
    .ADDR_WIDTH     (ADDR_WIDTH     ), 
    .STRB_WIDTH     (1              ), 
    .ID_WIDTH       (ID_WIDTH       ), 
		.TEST_SIZE      (65536          ),
    .PIPELINE_OUTPUT(0) 
  ) u_slave (
    .clk(ACLK),
    .rst(!ARESETN),

    // Write addr
    .s_axi_awid       ( AWID    ) ,
    .s_axi_awaddr     ( AWADDR  ) ,
    .s_axi_awlen      ( AWLEN   ) ,
    .s_axi_awsize     ( AWSIZE  ) ,
    .s_axi_awburst    ( AWBURST ) ,

    .s_axi_awvalid    ( AWVALID ) ,
    .s_axi_awready    ( AWREADY ) ,

    // Write data
    .s_axi_wdata      ( WDATA   ) ,
    .s_axi_wstrb      ( WSTRB   ) ,
    .s_axi_wlast      ( WLAST   ) ,
    .s_axi_wvalid     ( WVALID  ) ,
    .s_axi_wready     ( WREADY  ) ,

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

    DPRAM_IFM #(
    .RAM_SIZE          ( 524172            ) ,
    .BUFFER_ADDR_WIDTH ( BUFFER_ADDR_WIDTH ) ,
    .BUFFER_DATA_WIDTH ( 128               ) ,
    .DATA_WIDTH        ( DATA_WIDTH        ) ,
    .INOUT_WIDTH       ( INOUT_WIDTH       ) ,
		.IFM_WIDTH         ( IFM_WIDTH         ) ,
    .SYSTOLIC_SIZE     ( 16                )
) ifm_bram (
   .clk           (ACLK        ) ,
   .write_ofm_size(8           ) ,
   .re_a          (ifm_read_en ) ,
   .addr_a        (ifm_addr_a  ) ,
   .dout_a        (data_in     ) ,
   .we_b          (WR_EN       ) ,
   .addr_b        (ADDR_B      ) ,
   .din_b         (rdata       ) ,
   .upsample_mode (0           ) ,
   .ofm_size      (9'd16          )
);

  SYSTOLIC_ARRAY_v1_0 #
	(
    .SYSTOLIC_SIZE     ( SYSTOLIC_SIZE      )      ,
    .DATA_WIDTH        ( DATA_WIDTH         )      ,
    .INOUT_WIDTH       ( INOUT_WIDTH        )      ,
    .IFM_RAM_SIZE      ( IFM_RAM_SIZE       )  ,
    .WGT_RAM_SIZE      ( WGT_RAM_SIZE       )  ,
    .OFM_RAM_SIZE_1    ( OFM_RAM_SIZE_1     )  ,
    .OFM_RAM_SIZE_2    ( OFM_RAM_SIZE_2     )  ,
    .MAX_WGT_FIFO_SIZE ( MAX_WGT_FIFO_SIZE  )  ,
    .RELU_PARAM        ( RELU_PARAM         )  ,
    .Q                 ( 9                  )  ,
    .NUM_LAYER         ( 1                  )   ,
    .ID_WIDTH          ( 4                  )   ,
    .ADDR_WIDTH        ( 16                 )   ,
    .LEN_WIDTH         ( LEN_WIDTH          )        ,
		.C_M00_AXI_TARGET_SLAVE_BASE_ADDR ( 32'h40000000) ,
		.C_M00_AXI_BURST_LEN              ( 256         ) ,
		.C_M00_AXI_ID_WIDTH               ( 1           ) ,
		.C_M00_AXI_ADDR_WIDTH             ( 16          ) ,
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
		.m00_axi_awvalid     () ,
		.m00_axi_awready     () ,
		.m00_axi_wdata       (WDATA  ) ,
		.m00_axi_wstrb       (WSTRB  ) ,
		.m00_axi_wlast       (WLAST  ) ,
		.m00_axi_wvalid      (WVALID ) ,
		.m00_axi_wready      (WREADY ) ,
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
		.m00_axi_rdata       () ,
		.m00_axi_rresp       () ,
		.m00_axi_rlast       () ,
		.m00_axi_rvalid      () ,
		.m00_axi_rready      () ,
		.m00_axi_ruser       () ,
		.start               (start_CNN) ,
    .ifm_data_in         (data_in    ) , // from bram
    .ifm_addr_a          (ifm_addr_a ) ,
    .ifm_read_en         (ifm_read_en) ,
	  .done_CNN            (done_CNN   )	
	);
endmodule
