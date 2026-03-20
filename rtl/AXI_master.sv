
`timescale 1 ns / 1 ps

module AXI_MASTER_IF #(
    parameter ADDR_WIDTH = 32  ,
    parameter ADDR_WIDTH_OFM = 32  ,
    parameter DATA_WIDTH = 16 ,
		parameter AXI_WIDTH = 128,
    parameter INOUT_WIDTH= 256 ,
  	parameter BUFFER_ADDR_WIDTH = 19,
    parameter ID_WIDTH   = 4   ,
    parameter LEN_WIDTH  = 8 ,

  	parameter BURST_LEN_R = 255,
  	parameter BURST_LEN_W = 0,
		parameter NUM_LAYER   = 4 ,
  	parameter SYSTOLIC_SIZE = 16

)(
    input                       ACLK   ,
    input                       ARESETN,

    // Control from CNN IP
    input  [AXI_WIDTH-1:0]      WDATA_IN  ,
    output reg [AXI_WIDTH-1:0]  RDATA_OUT ,
    output reg                  BUSY_R    ,
    output reg                  BUSY_W    ,

    //---------------------------------
    // AXI4 Master Interface
    //---------------------------------

    // Write address channel
    output reg [ID_WIDTH-1:0]   M_AXI_AWID    ,
    output reg [ADDR_WIDTH_OFM-1:0] M_AXI_AWADDR  ,
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
    output reg [ADDR_WIDTH_OFM-1:0] M_AXI_ARADDR  ,
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
    output wire                 read_en_out  ,
    input                       start_read   ,
    input [8:0]                 ifm_size     ,
		input wire done_layer                         ,
		input wire [6:0] num_load_filter,
	// to IFM buffer
	  output wire [BUFFER_ADDR_WIDTH-1:0] ifm_address_buffer,
		input [8:0] ofm_size_pack,
		input [8:0] ofm_size,
	  input write,
  	input [10:0] num_filter,
	  output wire done,
		output wire end_read_ifm,
  	output reg start_CNN,
		output wire wr_en_ifm_buffer

);
	localparam BASE_ADDR_OFM = 85550;
	localparam NUM_CHANNEL = 3;
	
	reg read_en;
	assign read_en_out = read_en;
	localparam IFM_SIZE = 21841; 
	localparam IFM_WIDTH = 418; 
	wire [9:0] num_tile ;

	reg done_write_layer;
  assign num_tile= 86;
	reg swapper_memory;

	always @(posedge done_layer or negedge ARESETN) begin
		if(~ARESETN) begin
			swapper_memory <= 0;
		end else begin
		swapper_memory <= ~(swapper_memory);
		end
	end


    // beat counter
    reg [LEN_WIDTH-1:0] beat_cnt_r;
    reg [LEN_WIDTH-1:0] beat_cnt_w;
    // FSM states
	typedef enum logic [1:0] {
		IDLE_FIFO,
		READ_FIFO
	} fifo_state;
    typedef enum logic [2:0] {
        IDLE_OFM     ,
        NEXT_CHANNEL_OFM  ,
        UPDATE_BASE_ADDR  ,
			  END_COLLUM,
				END_LAYER
    } state_ofm;
    typedef enum logic [2:0] {
        IDLE_R     ,
        READ_ADDR  ,
        READ_DATA  ,
				END_READ  
    } state_r;
    typedef enum logic [2:0] {
				IDLE_W     ,
				READ_FIFO_W  ,
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
		state_ofm c_state_ofm, next_state_ofm;
	  fifo_state c_state_fifo, next_state_fifo;

	reg [9:0]cnt_channel;
	reg [9:0]cnt_tiling;
	reg [9:0]cnt_tiling_1;
	reg [9:0] cnt_channel_ofm;
	reg [9:0] cnt_tiling_ofm;
	reg [9:0] cnt_height;
	reg [15:0] base_addr;
	reg [6:0] cnt_filter;
	reg [9:0] cnt_collum;
	reg [6:0] cnt_load_filter;
	
	

	reg [ADDR_WIDTH-1:0] m_axi_araddr_1; 
	reg [ADDR_WIDTH_OFM-1:0] m_axi_araddr_4; 
	reg [BUFFER_ADDR_WIDTH-1:0] m_axi_araddr_3; 
	assign ifm_address_buffer = m_axi_araddr_3;

//	reg start_d,start;
//	always @(posedge ACLK or negedge ARESETN) begin
//		if(!ARESETN) begin
//			start <= 0;
//			start_d <= 0;
//		end else begin
//			start <= (cnt_tiling == 70) ? 1 : 0;
//			start_d <= start;
//		end
//	end
//	assign start_CNN = (start & ~(start_d));

wire [AXI_WIDTH + ADDR_WIDTH - 1:0] data_out_fifo;
reg [AXI_WIDTH - 1:0] ofm;
reg [ADDR_WIDTH_OFM - 1:0] addr;
wire [AXI_WIDTH - 1:0] data_o_fifo;
wire [ADDR_WIDTH_OFM - 1:0] addr_o_fifo;

	always @(*) begin
		if(M_AXI_AWVALID) begin
			ofm  = data_o_fifo ;
      addr = addr_o_fifo   ;
		end
	end

	always @(*) begin
//		next_state_ofm = c_state_ofm;
		case(c_state_ofm)
			IDLE_OFM: begin
				if(write) begin 
					next_state_ofm = NEXT_CHANNEL_OFM;
				end else begin
				 	next_state_ofm = IDLE_OFM;
				end
			end
			NEXT_CHANNEL_OFM: begin
				if((cnt_height == (ofm_size-1)) && (cnt_channel_ofm == SYSTOLIC_SIZE - 1)) begin
					next_state_ofm = END_COLLUM;	
				end else if(cnt_channel_ofm == SYSTOLIC_SIZE - 1) begin
					next_state_ofm = UPDATE_BASE_ADDR;
				end else begin 
					next_state_ofm = NEXT_CHANNEL_OFM;
			  end
			end
			UPDATE_BASE_ADDR: begin
				if(write) begin
					next_state_ofm = NEXT_CHANNEL_OFM;
				end else begin
					next_state_ofm = IDLE_OFM;
				end
			end
			END_COLLUM: begin
				if(cnt_collum == ofm_size_pack ) next_state_ofm = END_LAYER;
				else 
				next_state_ofm = IDLE_OFM;
			end
			default: next_state_ofm = IDLE_OFM;
		endcase
	end

	wire end_write_ofm = (cnt_height == ofm_size ) && (cnt_collum == ofm_size_pack);

	always @(posedge ACLK or negedge ARESETN) begin
		if(~ARESETN) begin
			cnt_tiling_ofm  <= '0;
			cnt_channel_ofm <= '0;
			cnt_height      <= '0;
			base_addr       <= '0;
			cnt_collum      <= '0;
			cnt_load_filter <= '0;
		end else begin
			case(next_state_ofm)
				IDLE_OFM: begin 
					cnt_collum <= (cnt_collum == ofm_size_pack) ? 0 : cnt_collum;
					cnt_channel_ofm <= (cnt_channel_ofm == SYSTOLIC_SIZE - 1) ? 0 : cnt_channel_ofm;
				end
				NEXT_CHANNEL_OFM: begin
					cnt_channel_ofm <= (cnt_channel_ofm == SYSTOLIC_SIZE - 1) ? 0 : cnt_channel_ofm + 1;
				end
				UPDATE_BASE_ADDR: begin
			    cnt_height <=  cnt_height + 1;
					cnt_tiling_ofm <= (cnt_tiling_ofm == ( ofm_size_pack*ofm_size )) ? 0 : cnt_tiling_ofm + 1;
					base_addr <=  base_addr + ofm_size_pack;
//					cnt_collum <= (cnt_height == (ofm_size*8-2)) ? cnt_collum + 1 : cnt_collum;
				end
				END_COLLUM: begin
					cnt_height <= 0;
					cnt_collum <= (cnt_collum == ofm_size_pack - 1) ? 0: cnt_collum + 1;
					base_addr <= 0;
					cnt_load_filter <= (cnt_collum == ofm_size_pack - 1) ? (cnt_load_filter == num_load_filter - 1) ? 0 : cnt_load_filter + 1 : cnt_load_filter; 
				end
				END_LAYER: begin
					cnt_height <= 0;
					cnt_collum <= 0;
					base_addr  <= 0;
					cnt_load_filter <= 0;
				end
				default: begin
					cnt_channel_ofm <= cnt_channel_ofm; 
					cnt_load_filter <= cnt_load_filter;
					cnt_tiling_ofm <= cnt_tiling_ofm; 
					cnt_height <= cnt_height;
					base_addr <= base_addr;
					cnt_collum <= (cnt_collum == ofm_size_pack ) ?  0:  cnt_collum;
				end
			endcase
		end
	end


	always @(posedge ACLK or negedge ARESETN) begin
		if(~ARESETN) begin
			m_axi_araddr_4 <= 0;
		end else begin
			case(next_state_ofm)
				IDLE_OFM: begin
					m_axi_araddr_4 <= m_axi_araddr_4;
				end
				NEXT_CHANNEL_OFM: begin
			   //  m_axi_araddr_4 <=  ((cnt_channel_ofm + 1) * ofm_size_pack*ofm_size ) + base_addr + cnt_collum;
			    m_axi_araddr_4 <=  ((cnt_channel_ofm + 1) * ofm_size_pack*ofm_size ) + base_addr + cnt_collum + (cnt_load_filter * ofm_size * ofm_size_pack);
				end
				UPDATE_BASE_ADDR: begin
			    m_axi_araddr_4 <= (cnt_height + 1) * ofm_size_pack + (cnt_collum) + (cnt_load_filter * ofm_size * ofm_size_pack);
				end
				END_COLLUM: begin
					m_axi_araddr_4 <= (cnt_collum < ofm_size_pack -1) ?  ( cnt_collum  + 1 + (cnt_load_filter * ofm_size * ofm_size_pack))  : 0;
				end
			default:
			    m_axi_araddr_4 <= m_axi_araddr_4;
			endcase
		end
	end


	always @(*) begin
    next_state_bram = c_state_bram ;
	case(next_state_bram)
		BRAM_IDLE: begin
		if(M_AXI_RVALID) begin
			next_state_bram = BRAM_FIRST_TILING;
		end
	end

	BRAM_FIRST_TILING_NEXT_CHANNEL: begin
			next_state_bram = BRAM_LOAD_DATA;
		end
	BRAM_FIRST_TILING: begin
			next_state_bram = BRAM_LOAD_DATA;
		end

	BRAM_FIRST_CHANNEL: begin
			next_state_bram = BRAM_LOAD_DATA;
		end
	BRAM_NEXT_CHANNEL: begin
		next_state_bram = BRAM_LOAD_DATA;
		end
	BRAM_LOAD_DATA: begin
		if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel == NUM_CHANNEL) && (cnt_tiling == num_tile)) next_state_bram = BRAM_IDLE; // 86 = (418 x 418)/(8x256)
		else if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel < NUM_CHANNEL-1) && (cnt_tiling == 0)) begin
			next_state_bram = BRAM_FIRST_TILING_NEXT_CHANNEL;
		end else if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel < NUM_CHANNEL-1) && (cnt_tiling > 0)) begin
			next_state_bram = BRAM_NEXT_CHANNEL;
		end else if ((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel == NUM_CHANNEL-1) && (cnt_tiling <= num_tile)) begin
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


	always @(*) begin
		m_axi_araddr_1 = 0;  
    next_state    = c_state ;
	  read_en = 0;
  case(c_state)
	IDLE: begin
		if(start_read || done_layer) begin
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
		if(cnt_channel == NUM_CHANNEL) begin
			next_state = FIRST_CHANNEL; 
		end else begin
			next_state = LOAD_DATA;
		end
	end
	LOAD_DATA: begin 
		m_axi_araddr_1 = m_axi_araddr_1; 
		if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel == NUM_CHANNEL-1) && (cnt_tiling >= (num_tile-1))) begin
			next_state = IDLE;
		end
		else if((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel < NUM_CHANNEL-1)) begin
			next_state = NEXT_CHANNEL;
		end else if ((beat_cnt_r == M_AXI_ARLEN) && (cnt_channel == NUM_CHANNEL-1) && (cnt_tiling < (num_tile-1))) begin
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
				NEXT_CHANNEL: cnt_channel <= (cnt_channel == NUM_CHANNEL-1) ? 0 : cnt_channel + 1; 
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
			M_AXI_ARADDR <= '0;
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
				    c_state_ofm <= IDLE_OFM;
			    	c_state_fifo <= IDLE_FIFO;
			end else begin
            c_state_r <= next_state_r;
            c_state_w <= next_state_w;
            c_state   <= next_state  ;
						c_state_bram   <= next_state_bram;
				    c_state_ofm <=  next_state_ofm;
						c_state_fifo <= next_state_fifo;
			end
    end

    // Beat counter
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN)
            beat_cnt_r <= 0;
        else begin
            case (c_state_r)
              READ_DATA : if (M_AXI_RVALID && M_AXI_RREADY) beat_cnt_r <= (beat_cnt_r == BURST_LEN_R) ? 0:  beat_cnt_r + 1;
                default   : beat_cnt_r <= 0;
            endcase
        end
    end
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN)
            beat_cnt_w <= 0;
        else begin
            case (c_state_w)
              READ_DATA : if (M_AXI_WVALID && M_AXI_WREADY) beat_cnt_w <= (beat_cnt_w == BURST_LEN_W) ? 0:  beat_cnt_w + 1;
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
        M_AXI_ARLEN     = BURST_LEN_R                ; 
        M_AXI_ARSIZE    = $clog2(AXI_WIDTH/8) ; 
        M_AXI_ARBURST   = 2'b01                ; 
			  start_CNN = 0;
      //  M_AXI_ARADDR    = ADDR_R               ; 
        case (c_state_r)
            IDLE_R: begin
                BUSY_R = 0;
                  if (read_en) next_state_r = READ_ADDR;
									else next_state_r = IDLE_R;
            end
            READ_ADDR: begin
                M_AXI_ARVALID = 1;
                M_AXI_RREADY = 1;
                if (M_AXI_ARREADY)
                    next_state_r = READ_DATA;
            end
            READ_DATA: begin
                M_AXI_RREADY = 1;
                if (M_AXI_RVALID) begin
                    RDATA_OUT = M_AXI_RDATA;
									if (M_AXI_RLAST  && (beat_cnt_r == BURST_LEN_R) && (cnt_tiling == num_tile - 1) &&(cnt_channel == NUM_CHANNEL - 1 )) begin 
                        next_state_r = END_READ;
									end else if(M_AXI_RLAST) begin
                    next_state_r = IDLE_R;
									end
							end
             end
					END_READ: begin
						next_state_r = IDLE_R;
						start_CNN = 1;
					end
        endcase
    end

reg [2:0] sig_d;
reg posedge_pulse;
reg m_axi_awvalid_reg;

    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            sig_d         <= 2'b0;
            posedge_pulse <= 1'b0;
//            M_AXI_AWVALID <= 0;
        end else begin
            posedge_pulse <=((next_state_w == WRITE_ADDR)  & ( sig_d != WRITE_ADDR));
            sig_d         <= next_state_w;           
//          M_AXI_AWVALID <= m_axi_awvalid_reg;
        end
    end
reg read_fifo;


    always @(*) begin
        next_state_w    = c_state_w              ;
        BUSY_W          = 1'b1                   ;
        M_AXI_AWVALID   = 0                      ;
        M_AXI_WVALID    = 0                      ;
        M_AXI_WLAST     = 0                      ;
        M_AXI_BREADY    = 0                      ;
        M_AXI_WSTRB     = {(AXI_WIDTH/8){1'b1}} ;

        // Address/control signals
        M_AXI_AWID      = '0                  ;
        M_AXI_AWLEN     = BURST_LEN_W         ;
        M_AXI_AWSIZE    = $clog2(AXI_WIDTH/8) ;
        M_AXI_AWBURST   = 2'b01               ;
        M_AXI_AWADDR    = addr                ;
        M_AXI_WDATA     = ofm                 ;
			  m_axi_awvalid_reg = 0;
			  read_fifo = 0;
        case (c_state_w)
            IDLE_W: begin
            	BUSY_W = 0;
              if (fifo_ofm.cnt > 0) next_state_w = READ_FIFO_W;
            end
					READ_FIFO_W: begin
						read_fifo = 1;
						next_state_w = WRITE_ADDR;
					end
            WRITE_ADDR: begin
            	M_AXI_AWVALID = 1;
						//	m_axi_awvalid_reg = 1;
              if (M_AXI_AWREADY)
              	next_state_w = WRITE_DATA;
            end
            WRITE_DATA: begin
            	M_AXI_WVALID = 1;
            	M_AXI_WLAST  = (beat_cnt_w == BURST_LEN_W);
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

reg end_read_ifm_reg;
	assign end_read_ifm = end_read_ifm_reg;

reg RLAST_prev;
always @(posedge ACLK) begin
  RLAST_prev <= M_AXI_RLAST;
end
always @(posedge ACLK or negedge ARESETN) begin
  if (!ARESETN)
    end_read_ifm_reg <= 1'b0;
  else
    end_read_ifm_reg <= (cnt_tiling == (num_tile-1) ) && (M_AXI_RLAST == 1) && (RLAST_prev != 1) && (cnt_channel == NUM_CHANNEL-1); 
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
//property check_address_4;
//  @(posedge ACLK)
//    ($rose(write) && cnt_height >= 1) |-> 
//       (m_axi_araddr_4 == $past(m_axi_araddr_4, 1, $rose(write)) + ofm_size_pack );
//endproperty
//property check_address_4_1;
//  @(posedge ACLK)
//    (write && (cnt_channel_ofm < num_filter-1)) |=> 
//       (m_axi_araddr_4 == $past(m_axi_araddr_4, 1) + ofm_size_pack*ofm_size);
//endproperty
//
//addr_4_1: assert property (check_address_4_1)
//  begin
//    $display( "PASS ADDRESS OFM 1"  ); end
//    else begin
//    $display ("CHECK ADDRESS OFM 1 FAIL : past address: %d , current address: %d, ofm_size_pack*ofm_size: %d", $past(m_axi_araddr_4, 1), m_axi_araddr_4, ofm_size_pack*ofm_size);
//  end
//addr_4: assert property (check_address_4)
//  begin
//    $display( "PASS ADDRESS OFM"  ); end
//    else begin
//    $display ("CHECK ADDRESS OFM FAIL : past address: %d , current address: %d", $past(m_axi_araddr_4, 1, $rose(M_AXI_RVALID)), m_axi_araddr_4);
//  end
//
//sequence base_addr_change;
//  $changed(cnt_collum);
//endsequence
//property check_addr_4_inc;
//  @(posedge ACLK) disable iff (!ARESETN)
//    base_addr_change |-> (m_axi_araddr_4 == $past(m_axi_araddr_4, 1, $changed(cnt_collum)) + 1);
//endproperty
//
//addr_4_2: assert property (check_addr_4_inc)
//  begin
//    $display( "PASS ADDRESS OFM INC"  ); end
//    else begin
//    $display ("CHECK ADDRESS OFM INC FAIL : past address: %d , current address: %d", $past(m_axi_araddr_4, 1,$changed(cnt_collum) ), m_axi_araddr_4);
//  end
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

	wire [AXI_WIDTH + ADDR_WIDTH -1 :0] payload; 
	assign payload = {WDATA_IN[127:0],m_axi_araddr_4};
	wire [ ADDR_WIDTH_OFM - 1 :0 ] addr_ofm;
	assign addr_ofm = (swapper_memory) ? m_axi_araddr_4 :  m_axi_araddr_4 + BASE_ADDR_OFM ;

	reg done_write_layer_d ;
	always @(posedge ACLK or negedge ARESETN) begin
		if(~ARESETN) begin
			done_write_layer <= 0;
      done_write_layer_d <= 0; 
		end else begin
			done_write_layer <= (next_state_ofm == END_LAYER) ? 1 : 0; 
			done_write_layer_d <= done_write_layer;
		end
	end
	assign done = done_write_layer && !done_write_layer_d;
	

 FIFO_OFM #(
	.DATA_WIDTH (AXI_WIDTH  ), 
	.FIFO_SIZE  (65536 )
) fifo_ofm (
	.clk          (ACLK          ) ,
	.rst_n        (ARESETN       ) ,
	.rd_clr       (rd_clr        ) ,
	.wr_clr       (wr_clr        ) ,
	.rd_inc       (rd_inc        ) ,
	.wr_inc       (wr_inc        ) ,
	.rd_en        (read_fifo     ) ,
	.wr_en        (write         ) ,
	.data_in_fifo (WDATA_IN      ) ,
	.data_out_fifo(data_o_fifo   ) ,
	.empty        (empty         ) ,
	.full         (full          )
);
 FIFO_OFM #(
	.DATA_WIDTH (ADDR_WIDTH_OFM   ), 
	.FIFO_SIZE  (65536 )
) fifo_addr (
	.clk          (ACLK          ) ,
	.rst_n        (ARESETN       ) ,
	.rd_clr       (rd_clr        ) ,
	.wr_clr       (wr_clr        ) ,
	.rd_inc       (rd_inc        ) ,
	.wr_inc       (wr_inc        ) ,
	.rd_en        (read_fifo     ) ,
	.wr_en        (write         ) ,
	.data_in_fifo (addr_ofm      ) ,
	.data_out_fifo(addr_o_fifo   ) ,
	.empty        (empty         ) ,
	.full         (full          )
);

endmodule
