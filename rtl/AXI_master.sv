
`timescale 1 ns / 1 ps

module AXI_MASTER_IF #(
    parameter ADDR_WIDTH = 16  ,
    parameter DATA_WIDTH = 16 ,
		parameter AXI_WIDTH = 128,
    parameter INOUT_WIDTH= 256 ,
	  parameter BUFFER_ADDR_WIDTH = 19,
    parameter ID_WIDTH   = 4   ,
    parameter LEN_WIDTH  = 8
)(
    input                       ACLK   ,
    input                       ARESETN,

    // Control from CNN IP
    input                       RD_EN     ,
    input                       WR_EN     ,
    input  [ADDR_WIDTH-1:0]     ADDR_R    ,
    input  [ADDR_WIDTH-1:0]     ADDR_W    ,
    input  [AXI_WIDTH-1:0]     WDATA_IN  ,
    output reg [AXI_WIDTH-1:0] RDATA_OUT ,
    output reg                  BUSY_R    ,
    output reg                  BUSY_W    ,

    //---------------------------------
    // AXI4 Master Interface
    //---------------------------------

    // Write address channel
    output reg [ID_WIDTH-1:0]   M_AXI_AWID    ,
    output reg [ADDR_WIDTH-1:0] M_AXI_AWADDR  ,
    output reg [LEN_WIDTH-1:0]  M_AXI_AWLEN   , 
    output reg [2:0]            M_AXI_AWSIZE  , 
    output reg [1:0]            M_AXI_AWBURST , 
    output reg                  M_AXI_AWVALID ,
    input                       M_AXI_AWREADY ,

    // Write data channel
    output reg [AXI_WIDTH-1:0]      M_AXI_WDATA     ,
    output reg [(AXI_WIDTH/8)-1:0]  M_AXI_WSTRB     ,
    output reg                      M_AXI_WLAST     ,
    output reg                      M_AXI_WVALID    ,
    input                           M_AXI_WREADY    ,

    // Write response channel
    input  [1:0]                M_AXI_BRESP  ,
    input                       M_AXI_BVALID ,
    output reg                  M_AXI_BREADY ,

    // Read address channel
    output reg [ID_WIDTH-1:0]   M_AXI_ARID    ,
    output reg [ADDR_WIDTH-1:0] M_AXI_ARADDR  ,
    output reg [LEN_WIDTH-1:0]  M_AXI_ARLEN   ,
    output reg [2:0]            M_AXI_ARSIZE  ,
    output reg [1:0]            M_AXI_ARBURST ,
    output reg                  M_AXI_ARVALID ,
    input                       M_AXI_ARREADY ,

    // Read data channel
    input  [AXI_WIDTH-1:0]      M_AXI_RDATA  ,
    input  [1:0]                M_AXI_RRESP  ,
    input                       M_AXI_RLAST  ,
    input                       M_AXI_RVALID ,
    output reg                  M_AXI_RREADY ,
    input [10:0]                num_channel  ,
    output wire                 read_en_out  ,
    input                       start_read   ,
    input [8:0]                 ifm_size     ,
	// to IFM buffer
	  output wire [BUFFER_ADDR_WIDTH-1:0] ifm_address_buffer,
		output wire wr_en_ifm_buffer,
		output wire start_CNN

);
	
	reg read_en;
	assign read_en_out = read_en;
	localparam IFM_SIZE = 21841; 
	localparam IFM_WIDTH = 418; 
	wire [9:0] num_tile ;
  assign num_tile= 86;
	reg start;

    // beat counter
    reg [LEN_WIDTH-1:0] beat_cnt_r;
    reg [LEN_WIDTH-1:0] beat_cnt_w;
    // FSM states
    typedef enum logic [2:0] {
        IDLE_R     ,
        READ_ADDR  ,
        READ_DATA
    } state_r;
    typedef enum logic [2:0] {
				IDLE_W     ,
        WRITE_ADDR ,
        WRITE_DATA ,
        WRITE_RESP 
		} state_w;
    typedef enum logic [2:0] {
        IDLE     ,
        FIRST_CHANNEL,
        FIRST_TILING,
				NEXT_CHANNEL,
				LOAD_DATA
    } state;

    typedef enum logic [2:0] {
        BRAM_IDLE     ,
        BRAM_FIRST_CHANNEL,
        BRAM_FIRST_TILING,
        BRAM_FIRST_TILING_NEXT_CHANNEL,
				BRAM_NEXT_CHANNEL,
				BRAM_LOAD_DATA
    } state_bram;

		state_bram c_state_bram, next_state_bram; // fsm for store data from DRAM to BRAM on chip
    state_r c_state_r, next_state_r;
    state_w c_state_w, next_state_w;
	  state c_state, next_state;

	reg [9:0]cnt_channel;
	reg [9:0]cnt_tiling;
	reg [9:0]cnt_tiling_1;
	reg start_d;

	reg [ADDR_WIDTH-1:0] m_axi_araddr_1; 
	reg [ADDR_WIDTH-1:0] m_axi_araddr_2; 
	reg [BUFFER_ADDR_WIDTH-1:0] m_axi_araddr_3; 
	assign ifm_address_buffer = m_axi_araddr_3;

	always @(posedge ACLK or negedge ARESETN) begin
		if(!ARESETN) begin
			start <= 0;
			start_d <= 0;
		end else begin
			start <= (cnt_tiling == 70) ? 1 : 0;
			start_d <= start;
		end
	end
	assign start_CNN = (start & ~(start_d));


	// geberate address for BRAM on chip ifm 
	always @(*) begin
	//	m_axi_araddr_3 = 0; 
    next_state_bram = c_state_bram ;
	case(next_state_bram)
		BRAM_IDLE: begin
	//	m_axi_araddr_3 = '0;
		if(M_AXI_RVALID) begin
		//	m_axi_araddr_3 = (cnt_tiling == num_tile) ? '0 : (M_AXI_ARLEN * cnt_tiling);
			next_state_bram = BRAM_FIRST_TILING;
		end
	end

	BRAM_FIRST_TILING_NEXT_CHANNEL: begin
	//		m_axi_araddr_3 = (cnt_tiling == num_tile+1) ? '0 : (M_AXI_ARLEN * (cnt_tiling-1));
			next_state_bram = BRAM_LOAD_DATA;
		end
	BRAM_FIRST_TILING: begin
	//		m_axi_araddr_3 = (cnt_tiling == num_tile+1) ? '0 : (M_AXI_ARLEN * (cnt_tiling-1));
			next_state_bram = BRAM_LOAD_DATA;
		end

	BRAM_FIRST_CHANNEL: begin
	//		m_axi_araddr_3 = (cnt_tiling == num_tile+1) ? '0 : (M_AXI_ARLEN * (cnt_tiling-1));
			next_state_bram = BRAM_LOAD_DATA;
		end
	BRAM_NEXT_CHANNEL: begin
//		m_axi_araddr_3 = m_axi_araddr_3  +  ((cnt_tiling - 1) * (M_AXI_ARLEN+1)) + (cnt_channel+1)*IFM_SIZE; // one tranfer = 8 value of ifm
		next_state_bram = BRAM_LOAD_DATA;
		end
	BRAM_LOAD_DATA: begin
//		m_axi_araddr_3 = m_axi_araddr_3 + 8;
		if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel == num_channel) && (cnt_tiling == num_tile)) next_state_bram = BRAM_IDLE; // 86 = (418 x 418)/(8x256)
		else if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel < num_channel-1) && (cnt_tiling == 0)) begin
			next_state_bram = BRAM_FIRST_TILING_NEXT_CHANNEL;
		end else if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel < num_channel-1) && (cnt_tiling > 0)) begin
			next_state_bram = BRAM_NEXT_CHANNEL;
		end else if ((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel == num_channel-1) && (cnt_tiling <= num_tile)) begin
				next_state_bram = BRAM_FIRST_CHANNEL;
		end else begin
				next_state_bram = BRAM_LOAD_DATA;
		end
	end
	default: next_state_bram = BRAM_IDLE;
	endcase
	end

	always @(posedge ACLK or negedge ARESETN) begin
		if(!ARESETN) begin
			m_axi_araddr_3 <= '0;
		end else begin case(next_state_bram) 
			BRAM_FIRST_TILING_NEXT_CHANNEL: 
				m_axi_araddr_3 <= (cnt_channel+1)*IFM_WIDTH*IFM_WIDTH;
			BRAM_FIRST_TILING: 
				m_axi_araddr_3 <= 8;
			BRAM_FIRST_CHANNEL:
		//		m_axi_araddr_3 <= (cnt_tiling == num_tile+1) ? '0 : (M_AXI_ARLEN * (cnt_tiling-1)+8);
				m_axi_araddr_3 <= (M_AXI_ARLEN+1)*(cnt_tiling+1)*8;
			BRAM_NEXT_CHANNEL:
		    m_axi_araddr_3 <= (cnt_tiling)*(M_AXI_ARLEN+1)* 8 + ((cnt_channel+1)*IFM_WIDTH*IFM_WIDTH); // one tranfer = 8 value of ifm
			BRAM_LOAD_DATA:
 		    m_axi_araddr_3 <= (M_AXI_RVALID && (m_axi_araddr_3 <= IFM_WIDTH * IFM_WIDTH * (cnt_channel +1 )-4)) ? m_axi_araddr_3 + 8 : m_axi_araddr_3;
			default: 
   	  	m_axi_araddr_3 = '0;
		endcase
		end
		end




//	always @(posedge ACLK or negedge ARESETN) begin
//
//
//		if(!ARESETN) begin
//			m_axi_araddr_3 <= '0;
//		end else if(c_state_bram == BRAM_LOAD_DATA) begin
//			m_axi_araddr_3 <=	m_axi_araddr_3 + 8 ;
//		end else begin
//			m_axi_araddr_3 <=	m_axi_araddr_3;  
//		end
//	end



	always @(*) begin
		m_axi_araddr_1 = 0; // address for DRAM off chip address 
    next_state    = c_state ;
	  read_en = 0;
  case(c_state)
	IDLE: begin
		if(start_read) begin
			m_axi_araddr_1 = '0;
			next_state = FIRST_TILING;
		end
	end
	FIRST_TILING: begin
			m_axi_araddr_1 = '0;
			read_en = 1;
			next_state = LOAD_DATA;
		end
	FIRST_CHANNEL: begin
			m_axi_araddr_1 = (cnt_tiling == num_tile) ? '0 : ((M_AXI_ARLEN+1) * (cnt_tiling));
			read_en = 1;
			next_state = LOAD_DATA;
		end
	NEXT_CHANNEL: begin
		read_en = 1;
		m_axi_araddr_1 = m_axi_araddr_1  +  ((cnt_tiling ) * (M_AXI_ARLEN+1)) + (cnt_channel)*IFM_SIZE;
		if(cnt_channel == num_channel) begin
			next_state = FIRST_CHANNEL; 
		end else begin
			next_state = LOAD_DATA;
		end
	end
	LOAD_DATA: begin 
		m_axi_araddr_1 = m_axi_araddr_1; 
		if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel == num_channel-1) && (cnt_tiling >= (num_tile-1))) begin
			next_state = IDLE;
		end
		else if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel < num_channel-1)) begin
			next_state = NEXT_CHANNEL;
		end else if ((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel == num_channel-1) && (cnt_tiling < (num_tile-1))) begin
		  next_state = FIRST_CHANNEL;
		end else begin
			next_state = LOAD_DATA;
		end
	end
	endcase
	end
	always @(posedge ACLK or negedge ARESETN) begin
			if(!ARESETN) begin
				cnt_channel <= '0;
				cnt_tiling  <= '0;
			end else begin case(next_state)
				NEXT_CHANNEL: cnt_channel <= (cnt_channel == num_channel-1) ? 0 : cnt_channel + 1; 
				FIRST_CHANNEL: begin 
					cnt_tiling  <= (cnt_tiling == (num_tile+1)) ? 0 : cnt_tiling + 1; 
					cnt_channel <= '0;
				end
				IDLE: cnt_tiling <= '0;
				FIRST_TILING: begin
					cnt_tiling  <= 0; 
					cnt_channel <= '0;
				end
				default: begin
					cnt_channel <= cnt_channel;
					cnt_tiling  <= cnt_tiling;
				end
			endcase
			end
	end

	always @(posedge ACLK or negedge ARESETN) begin
		if(!ARESETN) begin
			m_axi_araddr_1 <= '0; 
		end else begin
			M_AXI_ARADDR <= m_axi_araddr_1; 
		end
	end



    // State register
    always @(posedge ACLK or negedge ARESETN) begin
			if (!ARESETN) begin
            c_state_r <= IDLE_R;
            c_state_w <= IDLE_W;
						c_state   <= IDLE;
						c_state_bram   <= BRAM_IDLE;
			end else begin
            c_state_r <= next_state_r;
            c_state_w <= next_state_w;
            c_state   <= next_state  ;
						c_state_bram   <= next_state_bram;
			end
    end

    // Beat counter
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN)
            beat_cnt_r <= 0;
        else begin
            case (c_state_r)
              READ_DATA : if (M_AXI_RVALID && M_AXI_RREADY) beat_cnt_r <= (beat_cnt_r == 255) ? 0:  beat_cnt_r + 1;
                default   : beat_cnt_r <= 0;
            endcase
        end
    end
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN)
            beat_cnt_w <= 0;
        else begin
            case (c_state_w)
              READ_DATA : if (M_AXI_WVALID && M_AXI_WREADY) beat_cnt_w <= (beat_cnt_w == 15) ? 0:  beat_cnt_w + 1;
                default   : beat_cnt_w <= 0;
            endcase
        end
    end

    // FSM logic
    always @(*) begin
        // defaults
        next_state_r    = c_state_r ;
        BUSY_R          = 1'b1      ;
        M_AXI_ARVALID   = 0         ; 
        M_AXI_RREADY    = 0         ;
        // Address/control signals
        M_AXI_ARID      = '0                   ; 
        M_AXI_ARLEN     = 8'd255                ; 
        M_AXI_ARSIZE    = $clog2(AXI_WIDTH/8) ; 
        M_AXI_ARBURST   = 2'b01                ; 
      //  M_AXI_ARADDR    = ADDR_R               ; 
        case (c_state_r)
            IDLE_R: begin
                BUSY_R = 0;
                  if (read_en) next_state_r = READ_ADDR;
									else next_state_r = IDLE_R;
            end
            READ_ADDR: begin
                M_AXI_ARVALID = 1;
                //if (M_AXI_ARREADY)
                if (M_AXI_ARREADY)
                    next_state_r = READ_DATA;
            end
            READ_DATA: begin
                M_AXI_RREADY = 1;
                if (M_AXI_RVALID) begin
                    RDATA_OUT = M_AXI_RDATA;
                    if (M_AXI_RLAST)
                        next_state_r = IDLE_R;
                end
            end
        endcase
    end

    always @(*) begin
        next_state_w    = c_state_w              ;
        BUSY_W          = 1'b1                   ;
        M_AXI_AWVALID   = 0                      ;
        M_AXI_WVALID    = 0                      ;
        M_AXI_WLAST     = 0                      ;
        M_AXI_BREADY    = 0                      ;
        M_AXI_WSTRB     = {(AXI_WIDTH/8){1'b1}} ;

        // Address/control signals
        M_AXI_AWID      = '0                   ;
        M_AXI_AWLEN     = 8'd255                ;
        M_AXI_AWSIZE    = $clog2(AXI_WIDTH/8) ;
        M_AXI_AWBURST   = 2'b01                ;
        M_AXI_AWADDR    = ADDR_W               ;
        M_AXI_WDATA     = WDATA_IN             ;
        case (c_state_w)
            IDLE_W: begin
            	BUSY_W = 0;
              if (WR_EN) next_state_w = WRITE_ADDR;
            end
            WRITE_ADDR: begin
            	M_AXI_AWVALID = 1;
              if (M_AXI_AWREADY)
              	next_state_w = WRITE_DATA;
            end
            WRITE_DATA: begin
            	M_AXI_WVALID = 1;
            	M_AXI_WLAST  = (beat_cnt_w == 8'd15);
              if (M_AXI_WVALID && M_AXI_WREADY && M_AXI_WLAST)
              	next_state_w = WRITE_RESP;
            end

            WRITE_RESP: begin
            	M_AXI_BREADY = 1;
              if (M_AXI_BVALID)
              	next_state_w = IDLE_W;
            end
				endcase
		end

reg end_read_ifm;

reg RLAST_prev;
always @(posedge ACLK) begin
  RLAST_prev <= M_AXI_RLAST;
end
always @(posedge ACLK or negedge ARESETN) begin
  if (!ARESETN)
    end_read_ifm <= 1'b0;
  else
    end_read_ifm <= (cnt_tiling == (num_tile-1) ) && (M_AXI_RLAST == 1) && (RLAST_prev != 1) && (cnt_channel == num_channel-1); 
end

// wr-en iffm bram
	assign wr_en_ifm_buffer = (m_axi_araddr_3 <=( IFM_WIDTH * IFM_WIDTH * (cnt_channel +1 )-4)) ? M_AXI_RVALID : 0;  




//property check_address_1;
//  @(posedge ACLK)
//    (read_en && (cnt_tiling > 0))  |-> (m_axi_araddr_1 == (cnt_channel == 0) ?  $past(m_axi_araddr_1, 3 , read_en) + 256 : $past(m_axi_araddr_1, 1, read_en) + 21841 );
//endproperty
//  address_1: assert property(check_address_1) 
//  begin
//    $display( "PASS ADDRESS OFF CHIP"  ); end
//    else begin
//    $display ("CHECK ADDRESS OFF CHIP FAIL : past address: %d , current address: %d", $past(m_axi_araddr_1, 3, read_en), m_axi_araddr_1);
//  end
//
//
//property check_address_3;
//  @(posedge ACLK)
//    ($rose(M_AXI_RVALID) && cnt_channel >= 1) |-> 
//       (m_axi_araddr_3 == $past(m_axi_araddr_3, 1, $rose(M_AXI_RVALID)) + 418*418);
//endproperty
//
//addr_3: assert property (check_address_3)
//  begin
//    $display( "PASS ADDRESS ON CHIP"  ); end
//    else begin
//    $display ("CHECK ADDRESS ON CHIP FAIL : past address: %d , current address: %d", $past(m_axi_araddr_3, 1, $rose(M_AXI_RVALID)), m_axi_araddr_3);
//  end
//
//property check_address_3_1;
//  @(posedge ACLK)
//    ($rose(M_AXI_RVALID) && (cnt_channel ==0) && (cnt_tiling >= 1)) |-> 
//       (m_axi_araddr_3 == $past(m_axi_araddr_3, 3, $rose(M_AXI_RVALID)) + 2048);
//endproperty
//
//addr_3_1: assert property (check_address_3_1)
//  begin
//    $display( "PASS ADDRESS ON CHIP 1"  ); end
//    else begin
//    $display ("CHECK ADDRESS ON CHIP 1 FAIL : past address: %d , current address: %d", $past(m_axi_araddr_3, 3, $rose(M_AXI_RVALID)), m_axi_araddr_3);
//end
//
//
//property check_address;
//    @(posedge ACLK) 
//		(c_state == NEXT_CHANNEL) |-> (m_axi_araddr_1 == ($past(m_axi_araddr_1) + 21841)); 
//  endproperty
//
	// check ofm addr
//property check_address_ofm;
//  @(posedge ACLK)
//    (M_AXI_RVALID) && cnt_channel >= 1) |-> 
//       (m_axi_araddr_3 == $past(m_axi_araddr_3, 1, $rose(M_AXI_RVALID)) + 418*418);
//endproperty

//addr_3: assert property (check_address_3)
//  begin
//    $display( "PASS ADDRESS ON CHIP"  ); end
//    else begin
//    $display ("CHECK ADDRESS ON CHIP FAIL : past address: %d , current address: %d", $past(m_axi_araddr_3, 1, $rose(M_AXI_RVALID)), m_axi_araddr_3);
//  end
endmodule
