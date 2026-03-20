
`timescale 1 ns / 1 ps
module Functional_Unit #(
	parameter SYSTOLIC_SIZE     = 16      ,
	parameter DATA_WIDTH        = 16      ,
	parameter INOUT_WIDTH       = 256     ,
	parameter IFM_RAM_SIZE      = 524172  ,
	// parameter WGT_RAM_SIZE      = 8845488 ,
  parameter WGT_RAM_SIZE = 432,
  parameter OFM_RAM_SIZE_1    = 2205619 ,  
  parameter OFM_RAM_SIZE_2    = 259584  , 
	parameter MAX_WGT_FIFO_SIZE = 4608    ,
	parameter RELU_PARAM        = 0       , //fp = 5 (leaky = 0.01)
	parameter Q                 = 9         //fractional part, format Q7.9
) (
	input                                   clk                ,
	input                                   rst_n              ,
	input                                   start              ,
	output                                  done               ,

    //Layer config
	input  [3 : 0]                          count_layer        ,
  input  [8 : 0]                          ifm_size           ,
	input  [8 : 0]                          ofm_size_conv      ,
	input  [8 : 0]                          ofm_size           ,
	input  [8 : 0]                          ofm_size_ofm_ram_2 ,
  input  [10: 0]                          ifm_channel        ,
  input  [1 : 0]                          kernel_size        ,  
  input  [10: 0]                          num_filter         ,
  input                                   maxpool_mode       ,
  input  [1 : 0]                          maxpool_stride     ,
	input                                   upsample_mode      ,

	input  [$clog2(OFM_RAM_SIZE_1) - 1 : 0] start_write_addr_1 ,
	input  [$clog2(OFM_RAM_SIZE_1) - 1 : 0] start_read_addr_1  ,
	input  [$clog2(OFM_RAM_SIZE_2) - 1 : 0] start_write_addr_2 ,
	input  [$clog2(OFM_RAM_SIZE_2) - 1 : 0] start_read_addr_2  ,
	input  [17: 0]                          ifm_channel_size   ,
	input  [15: 0]                          ofm_channel_size_1 ,
	input  [$clog2(OFM_RAM_SIZE_1) - 1 : 0] write_addr_incr_1  ,
	input  [4 : 0]                          last_write_size_1  ,
	input  [15: 0]                          ofm_channel_size_2 ,
	input  [$clog2(OFM_RAM_SIZE_2) - 1 : 0] write_addr_incr_2  ,
	input  [4 : 0]                          last_write_size_2  ,

  input  [12: 0]                          num_cycle_load     ,
  input  [12: 0]                          num_cycle_compute  ,
  input  [6 : 0]                          num_load_filter    ,
  input  [13: 0]                          num_tiling	       ,
  output                                  ifm_read_en        ,   
  output [$clog2(IFM_RAM_SIZE)   - 1 : 0] ifm_addr_a         ,
	input [INOUT_WIDTH - 1 : 0]             ifm_data_in        ,                                                 

//  output wire  [ 8:0]                            write_ofm_size_1   ,
//  output wire                                    ofm_read_en_1      ,
//  wire         [ $clog2(OFM_RAM_SIZE_1) - 1 : 0] ofm_addr_a_1       ,
//  output wire  [ INOUT_WIDTH-1:0]                ofm_data_in_1      ,
  output wire                                    write_out_ofm_en_1, 
//  output wire  [ $clog2(OFM_RAM_SIZE_1) - 1 : 0] ofm_addr_b_1       ,
  output wire  [ INOUT_WIDTH-1:0]                ofm_data_out_1     

);

//	wire [INOUT_WIDTH - 1 : 0] ifm_data_in                                                        ;
	wire [INOUT_WIDTH - 1 : 0] ofm_data_in_2                                       ;
//	wire [INOUT_WIDTH - 1 : 0] ofm_data_in =  (count_layer == 12) ? ofm_data_in_2 : ofm_data_in_1 ;
	wire [INOUT_WIDTH - 1 : 0] ofm_data_in =  (count_layer == 12) ? ofm_data_in_2 : ofm_data_in_2 ;
  wire [INOUT_WIDTH - 1 : 0] wgt_data_in                                                        ;  
	wire [INOUT_WIDTH - 1 : 0] input_data_in = (count_layer == 1) ? ifm_data_in   : ofm_data_in   ;

	wire [INOUT_WIDTH - 1 : 0] left_in ;
	wire [INOUT_WIDTH - 1 : 0] top_in  ;

	wire         wgt_read_en                                                ;
	wire         ofm_read_en_2                                              ;
//	wire [INOUT_WIDTH - 1 : 0] ofm_data_in =  (count_layer == 12) ? ofm_data_in_2 : ofm_data_in_1 ;
	wire [4 : 0] read_wgt_size                                                             ;
	wire [4 : 0] read_ofm_size_1, read_ofm_size_2                                          ;
	wire [4 : 0] read_ofm_size   = (count_layer == 12) ? read_ofm_size_2 : read_ofm_size_1 ;
	wire [4 : 0] read_input_size = (count_layer == 1)  ? SYSTOLIC_SIZE   : read_ofm_size   ;
	wire [4 : 0] write_ofm_size_2                                        ;
	
//	wire [$clog2(IFM_RAM_SIZE)   - 1 : 0] ifm_addr_a   ;	
	wire [$clog2(WGT_RAM_SIZE)   - 1 : 0] wgt_addr_a   ;
	wire [$clog2(OFM_RAM_SIZE_2) - 1 : 0] ofm_addr_a_2 ;
	wire [$clog2(OFM_RAM_SIZE_2) - 1 : 0] ofm_addr_b_2 ;

	wire load_ifm, load_ofm ;
	wire load_ofm_1 = (count_layer != 12) ? load_ofm : 0 ;
	wire load_ofm_2 = (count_layer == 12) ? load_ofm : 0 ;
	wire load_wgt           ;
	wire ifm_demux, ifm_mux ; 

    wire                         wgt_rd_clr   ;
    wire                         wgt_wr_clr   ;
    wire [SYSTOLIC_SIZE - 1 : 0] wgt_rd_en    ;
    wire                         wgt_wr_en    ;

    wire                         ifm_rd_clr_1 ;
    wire                         ifm_wr_clr_1 ;
    wire [SYSTOLIC_SIZE - 1 : 0] ifm_rd_en_1  ;
    wire                         ifm_wr_en_1  ;
    
    wire                         ifm_rd_clr_2 ;
    wire                         ifm_wr_clr_2 ;
    wire [SYSTOLIC_SIZE - 1 : 0] ifm_rd_en_2  ;
    wire                         ifm_wr_en_2  ;    

	wire maxpool_rd_clr ;
	wire maxpool_wr_clr ;
	wire maxpool_rd_en  ;
	wire maxpool_wr_en  ;

	wire         reset_pe     ;
	wire [6 : 0] count_filter ;
	wire [13: 0] count_tiling ;
	wire [8 : 0] count_tiling_mod_ofm_size ;

	wire write_out_pe_en                                                                                       ;
	wire write_out_maxpool_en                                                                                  ;
	assign write_out_ofm_en_1 = (maxpool_mode)                          ? write_out_maxpool_en : write_out_pe_en ;
	wire write_out_ofm_en_2 = (count_layer == 5 || count_layer == 11) ? write_out_pe_en      : 0               ;

	wire [INOUT_WIDTH   - 1 : 0] pe_data_out        ;
	wire [INOUT_WIDTH   - 1 : 0] maxpool_1_data_out ;
	wire [INOUT_WIDTH   - 1 : 0] fifo_data_out      ;
	wire [INOUT_WIDTH*2 - 1 : 0] maxpool_2_data_in = {
							maxpool_1_data_out[15 * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[15 * DATA_WIDTH +: DATA_WIDTH],   
							maxpool_1_data_out[14 * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[14 * DATA_WIDTH +: DATA_WIDTH],  
							maxpool_1_data_out[13 * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[13 * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[12 * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[12 * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[11 * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[11 * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[10 * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[10 * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[9  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[9  * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[8  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[8  * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[7  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[7  * DATA_WIDTH +: DATA_WIDTH],  
							maxpool_1_data_out[6  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[6  * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[5  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[5  * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[4  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[4  * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[3  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[3  * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[2  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[2  * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[1  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[1  * DATA_WIDTH +: DATA_WIDTH],
							maxpool_1_data_out[0  * DATA_WIDTH +: DATA_WIDTH], fifo_data_out[0  * DATA_WIDTH +: DATA_WIDTH] };
	wire [INOUT_WIDTH - 1 : 0] maxpool_2_data_out ;
	wire [INOUT_WIDTH - 1 : 0] maxpool_2_data_out_stride_2 = 
		{ 128'b0, maxpool_2_data_out[14 * DATA_WIDTH +: DATA_WIDTH], maxpool_2_data_out[12 * DATA_WIDTH +: DATA_WIDTH],
				  maxpool_2_data_out[10 * DATA_WIDTH +: DATA_WIDTH], maxpool_2_data_out[8  * DATA_WIDTH +: DATA_WIDTH],
				  maxpool_2_data_out[6  * DATA_WIDTH +: DATA_WIDTH], maxpool_2_data_out[4  * DATA_WIDTH +: DATA_WIDTH],
			      maxpool_2_data_out[2  * DATA_WIDTH +: DATA_WIDTH], maxpool_2_data_out[0  * DATA_WIDTH +: DATA_WIDTH] };

	wire [INOUT_WIDTH - 1 : 0] data_out = (maxpool_mode) ? ((maxpool_stride == 1) ? maxpool_2_data_out : maxpool_2_data_out_stride_2) : pe_data_out ; 

	//Leaky relu
	 (* use_dsp = "yes" *) wire [INOUT_WIDTH*2 - 1 : 0] mult_fp_ofm_data_out_1;
	assign mult_fp_ofm_data_out_1[15 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[15 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[14 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[14 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[13 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[13 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[12 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[12 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[11 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[11 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[10 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[10 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[9  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[9  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[8  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[8  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[7  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[7  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[6  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[6  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[5  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[5  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[4  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[4 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[3  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[3  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[2  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[2  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[1  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[1  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_1[0  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * data_out[0  * DATA_WIDTH +: DATA_WIDTH];

	wire [INOUT_WIDTH - 1 : 0] ofm_data_out_1_leaky;
	assign ofm_data_out_1_leaky[15 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[15 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[14 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[14 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[13 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[13 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[12 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[12 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[11 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[11 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[10 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[10 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[9  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[9  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[8  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[8  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[7  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[7  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[6  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[6  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[5  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[5  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[4  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[4  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[3  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[3  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[2  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[2  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[1  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[1  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_1_leaky[0  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_1[0  * DATA_WIDTH*2 + Q +: DATA_WIDTH];

//	wire [INOUT_WIDTH - 1 : 0] ofm_data_out_2;
	assign ofm_data_out_1[15 * DATA_WIDTH +: DATA_WIDTH] = (data_out[16 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[15 * DATA_WIDTH +: DATA_WIDTH] : data_out[15 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[14 * DATA_WIDTH +: DATA_WIDTH] = (data_out[15 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[14 * DATA_WIDTH +: DATA_WIDTH] : data_out[14 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[13 * DATA_WIDTH +: DATA_WIDTH] = (data_out[14 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[13 * DATA_WIDTH +: DATA_WIDTH] : data_out[13 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[12 * DATA_WIDTH +: DATA_WIDTH] = (data_out[13 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[12 * DATA_WIDTH +: DATA_WIDTH] : data_out[12 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[11 * DATA_WIDTH +: DATA_WIDTH] = (data_out[12 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[11 * DATA_WIDTH +: DATA_WIDTH] : data_out[11 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[10 * DATA_WIDTH +: DATA_WIDTH] = (data_out[11 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[10 * DATA_WIDTH +: DATA_WIDTH] : data_out[10 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[9  * DATA_WIDTH +: DATA_WIDTH] = (data_out[10 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[9  * DATA_WIDTH +: DATA_WIDTH] : data_out[9  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[8  * DATA_WIDTH +: DATA_WIDTH] = (data_out[9  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[8  * DATA_WIDTH +: DATA_WIDTH] : data_out[8  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[0  * DATA_WIDTH +: DATA_WIDTH] = (data_out[8  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[7  * DATA_WIDTH +: DATA_WIDTH] : data_out[7  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[1  * DATA_WIDTH +: DATA_WIDTH] = (data_out[7  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[6  * DATA_WIDTH +: DATA_WIDTH] : data_out[6  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[2  * DATA_WIDTH +: DATA_WIDTH] = (data_out[6  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[5  * DATA_WIDTH +: DATA_WIDTH] : data_out[5  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[3  * DATA_WIDTH +: DATA_WIDTH] = (data_out[5  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[4  * DATA_WIDTH +: DATA_WIDTH] : data_out[4  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[4  * DATA_WIDTH +: DATA_WIDTH] = (data_out[4  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[3  * DATA_WIDTH +: DATA_WIDTH] : data_out[3  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[5  * DATA_WIDTH +: DATA_WIDTH] = (data_out[3  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[2  * DATA_WIDTH +: DATA_WIDTH] : data_out[2  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[6  * DATA_WIDTH +: DATA_WIDTH] = (data_out[2  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[1  * DATA_WIDTH +: DATA_WIDTH] : data_out[1  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_1[7  * DATA_WIDTH +: DATA_WIDTH] = (data_out[1  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_1_leaky[0  * DATA_WIDTH +: DATA_WIDTH] : data_out[0  * DATA_WIDTH +: DATA_WIDTH] ;

	//Leaky relu
	 (* use_dsp = "yes" *) wire [INOUT_WIDTH*2 - 1 : 0] mult_fp_ofm_data_out_2;
	assign mult_fp_ofm_data_out_2[15 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[15 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[14 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[14 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[13 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[13 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[12 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[12 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[11 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[11 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[10 * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[10 * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[9  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[9  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[8  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[8  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[7  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[7  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[6  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[6  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[5  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[5  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[4  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[4  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[3  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[3  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[2  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[2  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[1  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[1  * DATA_WIDTH +: DATA_WIDTH];
	assign mult_fp_ofm_data_out_2[0  * DATA_WIDTH*2 +: DATA_WIDTH*2] = RELU_PARAM * pe_data_out[0  * DATA_WIDTH +: DATA_WIDTH];

	wire [INOUT_WIDTH - 1 : 0] ofm_data_out_2_leaky;
	assign ofm_data_out_2_leaky[15 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[15 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[14 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[14 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[13 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[13 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[12 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[12 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[11 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[11 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[10 * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[10 * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[9  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[9  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[8  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[8  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[7  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[7  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[6  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[6  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[5  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[5  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[4  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[4  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[3  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[3  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[2  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[2  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[1  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[1  * DATA_WIDTH*2 + Q +: DATA_WIDTH];
	assign ofm_data_out_2_leaky[0  * DATA_WIDTH +: DATA_WIDTH] = mult_fp_ofm_data_out_2[0  * DATA_WIDTH*2 + Q +: DATA_WIDTH];

	wire [INOUT_WIDTH - 1 : 0] ofm_data_out_2;
	assign ofm_data_out_2[15 * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[16 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[15 * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[15 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[14 * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[15 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[14 * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[14 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[13 * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[14 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[13 * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[13 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[12 * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[13 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[12 * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[12 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[11 * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[12 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[11 * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[11 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[10 * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[11 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[10 * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[10 * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[9  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[10 * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[9  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[9  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[8  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[9  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[8  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[8  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[7  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[8  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[7  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[7  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[6  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[7  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[6  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[6  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[5  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[6  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[5  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[5  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[4  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[5  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[4  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[4  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[3  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[4  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[3  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[3  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[2  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[3  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[2  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[2  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[1  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[2  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[1  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[1  * DATA_WIDTH +: DATA_WIDTH] ;
	assign ofm_data_out_2[0  * DATA_WIDTH +: DATA_WIDTH] = (pe_data_out[1  * DATA_WIDTH - 1] == 1 && count_layer != 10 && count_layer != 13) ? ofm_data_out_2_leaky[0  * DATA_WIDTH +: DATA_WIDTH] : pe_data_out[0  * DATA_WIDTH +: DATA_WIDTH] ;
	

//DPRAM #(.RAM_SIZE (IFM_RAM_SIZE), .DATA_WIDTH (DATA_WIDTH), .INOUT_WIDTH (INOUT_WIDTH), .SYSTOLIC_SIZE (SYSTOLIC_SIZE)) ifm_dpram (
//	.clk            ( clk         ) ,
//	.write_ofm_size (             ) ,
//
//	.re_a           ( ifm_read_en ) ,
//	.addr_a         ( ifm_addr_a  ) ,
//	.dout_a         ( ifm_data_in ) ,
//
//	.we_b           (             ) ,
//	.addr_b         (             ) ,
//	.din_b          (             ) ,
//
//	.upsample_mode  (             ) , 
//	.ofm_size       (             )  
//);

DPRAM #(.RAM_SIZE (WGT_RAM_SIZE), .DATA_WIDTH (DATA_WIDTH), .INOUT_WIDTH (INOUT_WIDTH), .SYSTOLIC_SIZE (SYSTOLIC_SIZE)) wgt_dpram (
	.clk            ( clk         ) ,
	.write_ofm_size (             ) ,

	.re_a           ( wgt_read_en ) ,
	.addr_a         ( wgt_addr_a  ) ,
	.dout_a         ( wgt_data_in ) ,

	.we_b           (             ) ,
	.addr_b         (             ) ,
	.din_b          (             ) ,

	.upsample_mode  (             ) ,
	.ofm_size       (             )
);

//DPRAM #(.RAM_SIZE (OFM_RAM_SIZE_1), .DATA_WIDTH (DATA_WIDTH), .INOUT_WIDTH (INOUT_WIDTH), .SYSTOLIC_SIZE (SYSTOLIC_SIZE)) ofm_dpram_1 (
//	.clk            ( clk                ) ,
//	.write_ofm_size ( write_ofm_size_1   ) ,
//	.re_a           ( ofm_read_en_1      ) ,
//	.addr_a         ( ofm_addr_a_1       ) ,
//	.dout_a         ( ofm_data_in_1      ) ,
//	.we_b           ( write_out_ofm_en_1 ) ,
//	.addr_b         ( ofm_addr_b_1       ) ,
//	.din_b          ( ofm_data_out_1     ) ,
//
//	.upsample_mode  ( upsample_mode      ) , 
//	.ofm_size       ( ofm_size           )   
//);

//DPRAM #(.RAM_SIZE (OFM_RAM_SIZE_2), .DATA_WIDTH (DATA_WIDTH), .INOUT_WIDTH (INOUT_WIDTH), .SYSTOLIC_SIZE (SYSTOLIC_SIZE)) ofm_dpram_2 (
//	.clk            ( clk                ) ,
//	.write_ofm_size ( write_ofm_size_2   ) ,

//	.re_a           ( ofm_read_en_2      ) ,
//	.addr_a         ( ofm_addr_a_2       ) ,
//	.dout_a         ( ofm_data_in_2      ) ,

//	.we_b           ( write_out_ofm_en_2 ) ,
//	.addr_b         ( ofm_addr_b_2       ) ,
//	.din_b          ( ofm_data_out_2     ) ,

//	.upsample_mode  ( upsample_mode      ) , 
//	.ofm_size       ( ofm_size_ofm_ram_2 )  
//);

ifm_addr_controller #(.SYSTOLIC_SIZE (SYSTOLIC_SIZE), .IFM_RAM_SIZE (IFM_RAM_SIZE)) ifm_addr (
	.clk          ( clk              ) ,
	.rst_n        ( rst_n            ) ,
	.load         ( load_ifm         ) ,

	.ifm_addr     ( ifm_addr_a       ) ,
	.read_en      ( ifm_read_en      ) ,

	.ifm_size     ( ifm_size         ) ,
	.channel_size ( ifm_channel_size ) ,
	.ifm_channel  ( ifm_channel      ) , 
	.ofm_size     ( ofm_size_conv    )
);

wgt_addr_controller #(.SYSTOLIC_SIZE (SYSTOLIC_SIZE), .WGT_RAM_SIZE (WGT_RAM_SIZE)) wgt_addr (
	.clk             ( clk             ) ,
	.rst_n           ( rst_n           ) ,
	.load            ( load_wgt        ) ,

	.wgt_addr        ( wgt_addr_a      ) ,
	.read_en         ( wgt_read_en     ) ,
	.read_wgt_size   ( read_wgt_size   ) ,

	.num_filter      ( num_filter      ) ,
	.num_cycle_load  ( num_cycle_load  ) ,
	.num_load_filter ( num_load_filter ) ,

	.count_filter    ( count_filter    ) 
);

ofm_write_addr_controller_1 #(.SYSTOLIC_SIZE (SYSTOLIC_SIZE), .OFM_RAM_SIZE (OFM_RAM_SIZE_1)) ofm_write_addr_1 (
	.clk              ( clk                ) ,
	.rst_n            ( rst_n              ) ,
	.start            ( start              ) ,
	.start_write_addr ( start_write_addr_1 ) , 
	.write            ( write_out_ofm_en_1 ) ,
	.read_wgt_size    ( read_wgt_size      ) ,

	.ofm_addr         ( ofm_addr_b_1       ) ,
	.write_ofm_size   ( write_ofm_size_1   ) ,

	.count_layer      ( count_layer        ) ,
	.ofm_size         ( ofm_size           ) , 
	.ofm_size_conv    ( ofm_size_conv      ) , 
	.channel_size     ( ofm_channel_size_1 ) ,
	.maxpool_mode     ( maxpool_mode       ) ,
	.maxpool_stride   ( maxpool_stride     ) ,  
	.upsample_mode    ( upsample_mode      ) ,

	.num_tiling       ( num_tiling         ) ,
	.write_addr_incr  ( write_addr_incr_1  ) , 
	.last_write_size  ( last_write_size_1  )     
);

ofm_read_addr_controller #(.SYSTOLIC_SIZE (SYSTOLIC_SIZE), .OFM_RAM_SIZE (OFM_RAM_SIZE_1)) ofm_read_addr_1 (
	.clk                       ( clk                       ) ,
	.rst_n                     ( rst_n                     ) ,
	.start                     ( start                     ) ,
	.start_read_addr           ( start_read_addr_1         ) , 
	.load                      ( load_ofm_1                ) ,
  .count_tiling              ( count_tiling              ) ,
	.count_tiling_mod_ofm_size ( count_tiling_mod_ofm_size ) ,

	.ofm_addr                  ( ofm_addr_a_1              ) ,
	.read_en                   ( ofm_read_en_1             ) ,
	.read_ofm_size             ( read_ofm_size_1           ) ,

	.ifm_size                  ( ifm_size                  ) ,
	.channel_size              ( ifm_channel_size          ) ,
	.ifm_channel               ( ifm_channel               ) , 
	.kernel_size               ( kernel_size               ) , 
	.ofm_size                  ( ofm_size_conv             ) ,
	.num_tiling                ( num_tiling                )
);

ofm_write_addr_controller_2 #(.SYSTOLIC_SIZE (SYSTOLIC_SIZE), .OFM_RAM_SIZE (OFM_RAM_SIZE_2)) ofm_write_addr_2 (
	.clk              ( clk                ) ,
	.rst_n            ( rst_n              ) ,
	.start            ( start              ) ,
	.start_write_addr ( start_write_addr_2 ) , 
	.write            ( write_out_ofm_en_2 ) ,
	.read_wgt_size    ( read_wgt_size      ) ,
	
	.ofm_addr         ( ofm_addr_b_2       ) ,
	.write_ofm_size   ( write_ofm_size_2   ) ,
	
	.count_layer      ( count_layer        ) ,
	.ofm_size         ( ofm_size_ofm_ram_2 ) , 
	.ofm_size_conv    ( ofm_size_conv      ) , 
	.channel_size     ( ofm_channel_size_2 ) ,
	.upsample_mode    ( upsample_mode      ) ,

	.num_tiling       ( num_tiling         ) ,
	.write_addr_incr  ( write_addr_incr_2  ) , 
	.last_write_size  ( last_write_size_2  ) 
);

ofm_read_addr_controller #(.SYSTOLIC_SIZE (SYSTOLIC_SIZE), .OFM_RAM_SIZE (OFM_RAM_SIZE_2)) ofm_read_addr_2 (
	.clk                       ( clk                       ) ,
	.rst_n                     ( rst_n                     ) ,
	.start                     ( start                     ) ,
	.start_read_addr           ( start_read_addr_2         ) , 
	.load                      ( load_ofm_2                ) ,
  .count_tiling              ( count_tiling              ) ,
	.count_tiling_mod_ofm_size ( count_tiling_mod_ofm_size ) ,

	.ofm_addr                  ( ofm_addr_a_2              ) ,
	.read_en                   ( ofm_read_en_2             ) ,
	.read_ofm_size             ( read_ofm_size_2           ) ,

	.ifm_size                  ( ifm_size                  ) ,
	.channel_size              ( ifm_channel_size          ) ,
	.ifm_channel               ( ifm_channel               ) , 
	.kernel_size               ( kernel_size               ) , 
	.ofm_size                  ( ofm_size_conv             ) ,

	.num_tiling                ( num_tiling                )
);

ifm_FIFO_array #(
	.SYSTOLIC_SIZE     ( SYSTOLIC_SIZE     ) , 
	.DATA_WIDTH        ( DATA_WIDTH        ) , 
	.INOUT_WIDTH       ( INOUT_WIDTH       ) , 
	.MAX_WGT_FIFO_SIZE ( MAX_WGT_FIFO_SIZE ) , 
	.NUM_FIFO          ( SYSTOLIC_SIZE     )
) ifm_fifo_array (
	.clk                       ( clk                            ) ,
	.rst_n                     ( rst_n                          ) ,

	.rd_clr_1                  ( ifm_rd_clr_1                   ) ,
	.wr_clr_1                  ( ifm_wr_clr_1                   ) ,
	.rd_en_1                   ( ifm_rd_en_1                    ) ,
	.wr_en_1                   ( ifm_wr_en_1                    ) ,
	
	.rd_clr_2                  ( ifm_rd_clr_2                   ) ,
	.wr_clr_2                  ( ifm_wr_clr_2                   ) ,
	.rd_en_2                   ( ifm_rd_en_2                    ) ,
	.wr_en_2                   ( ifm_wr_en_2                    ) ,
	
	.ifm_demux                 ( ifm_demux                      ) ,
	.ifm_mux                   ( ifm_mux                        ) ,	
	.count_tiling              ( count_tiling                   ) ,
	.count_tiling_mod_ofm_size ( count_tiling_mod_ofm_size      ) ,

	.read_ifm_size             ( read_input_size                ) ,	
	.ofm_read_en               ( ofm_read_en_1 || ofm_read_en_2 ) ,

	.data_in                   ( input_data_in                  ) ,
	.data_out                  ( left_in                        ) ,
	
	.count_layer               ( count_layer                    ) ,
	.kernel_size               ( kernel_size                    ) ,
	.maxpool_stride            ( maxpool_stride                 ) ,  
	.ofm_size                  ( ofm_size_conv                  ) ,

	.num_tiling                ( num_tiling                     )
);

wgt_FIFO_array #(
	.DATA_WIDTH        ( DATA_WIDTH        ) , 
	.INOUT_WIDTH       ( INOUT_WIDTH       ) , 
	.MAX_WGT_FIFO_SIZE ( MAX_WGT_FIFO_SIZE ) , 
	.NUM_FIFO          ( SYSTOLIC_SIZE     )
) wgt_fifo_array (
	.clk           ( clk           ) ,
	.rd_clr        ( wgt_rd_clr    ) ,
	.wr_clr        ( wgt_wr_clr    ) ,
	.rd_en         ( wgt_rd_en     ) ,
	.wr_en         ( wgt_wr_en     ) ,
	.read_wgt_size ( read_wgt_size ) ,
	.data_in       ( wgt_data_in   ) ,
	.data_out      ( top_in        )    
);

PE_array #(.DATA_WIDTH (DATA_WIDTH), .SYSTOLIC_SIZE (SYSTOLIC_SIZE), .Q (Q)) pe_array (
	.clk          ( clk             ) ,
    .rst_n        ( rst_n           ) ,
	.reset_pe     ( reset_pe        ) ,
    .write_out_en ( write_out_pe_en ) ,
    .wgt_in       ( top_in          ) ,
    .ifm_in       ( left_in         ) ,
    .ofm_out      ( pe_data_out     )
);

PE_MAXPOOL_array #(.DATA_WIDTH (DATA_WIDTH), .NUM_MODULES (SYSTOLIC_SIZE)) maxpool_array_1 (
	.data_in  ( pe_data_out        ) ,
    .data_out ( maxpool_1_data_out ) 
);

FIFO_MAXPOOL_array #(.DATA_WIDTH (DATA_WIDTH), .NUM_MODULES (SYSTOLIC_SIZE)) maxpool_array_2 (
	.data_in  ( maxpool_2_data_in  ) ,
    .data_out ( maxpool_2_data_out )
);

MAXPOOL_FIFO_array #(.DATA_WIDTH (DATA_WIDTH), .SYSTOLIC_SIZE (SYSTOLIC_SIZE), .NUM_FIFO (SYSTOLIC_SIZE)) maxpool_fifo_array (
	.clk      ( clk                ) ,
    .rd_clr   ( maxpool_rd_clr     ) ,
	.wr_clr   ( maxpool_wr_clr     ) ,
    .rd_en    ( maxpool_rd_en      ) ,
    .wr_en    ( maxpool_wr_en      ) ,
    .data_in  ( maxpool_1_data_out ) ,
    .data_out ( fifo_data_out      )
);

controller #(.SYSTOLIC_SIZE (SYSTOLIC_SIZE)) control (
	.clk                       ( clk                       ) ,
	.rst_n                     ( rst_n                     ) ,
	.start                     ( start                     ) ,
	.read_wgt_size             ( read_wgt_size             ) ,

	.load_ifm                  ( load_ifm                  ) ,
	.load_ofm                  ( load_ofm                  ) ,
	.load_wgt                  ( load_wgt                  ) ,
	.ifm_demux                 ( ifm_demux                 ) ,
	.ifm_mux                   ( ifm_mux                   ) ,
 
	.wgt_rd_clr                ( wgt_rd_clr                ) ,
	.wgt_wr_clr                ( wgt_wr_clr                ) ,
	.wgt_rd_en                 ( wgt_rd_en                 ) ,
	.wgt_wr_en                 ( wgt_wr_en                 ) ,

	.ifm_rd_clr_1              ( ifm_rd_clr_1              ) ,
	.ifm_wr_clr_1              ( ifm_wr_clr_1              ) ,
	.ifm_rd_en_1               ( ifm_rd_en_1               ) ,
	.ifm_wr_en_1               ( ifm_wr_en_1               ) ,

	.ifm_rd_clr_2              ( ifm_rd_clr_2              ) ,
	.ifm_wr_clr_2              ( ifm_wr_clr_2              ) ,
	.ifm_rd_en_2               ( ifm_rd_en_2               ) ,
	.ifm_wr_en_2               ( ifm_wr_en_2               ) ,
       
	.maxpool_rd_clr            ( maxpool_rd_clr            ) ,
	.maxpool_wr_clr            ( maxpool_wr_clr            ) ,
    .maxpool_rd_en             ( maxpool_rd_en             ) ,
    .maxpool_wr_en             ( maxpool_wr_en             ) ,	
	
	.reset_pe                  ( reset_pe                  ) ,
	.write_out_pe_en           ( write_out_pe_en           ) ,
	.write_out_maxpool_en      ( write_out_maxpool_en      ) ,
	.count_filter              ( count_filter              ) ,
	.count_tiling              ( count_tiling              ) ,
	.count_tiling_mod_ofm_size ( count_tiling_mod_ofm_size ) ,
	.done                      ( done                      ) ,

	.count_layer               ( count_layer               ) ,
	.ifm_channel               ( ifm_channel               ) ,
	.kernel_size               ( kernel_size               ) ,
	.ofm_size                  ( ofm_size_conv             ) ,
	.num_filter                ( num_filter                ) ,
	.maxpool_mode              ( maxpool_mode              ) ,
	.maxpool_stride            ( maxpool_stride            ) ,

	.num_cycle_load            ( num_cycle_load            ) ,
	.num_cycle_compute         ( num_cycle_compute         ) ,
	.num_load_filter           ( num_load_filter           ) ,
	.num_tiling                ( num_tiling                )
);

endmodule
