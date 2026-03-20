
`timescale 1 ns / 1 ps
module ifm_FIFO #(
    parameter DATA_WIDTH        = 16   ,
    parameter MAX_WGT_FIFO_SIZE = 4608 
) (
    input                       clk       ,
    
    input                       rd_clr_1  ,
    input                       wr_clr_1  ,
    input                       rd_en_1   ,
    input                       wr_en_1   ,

    input                       rd_clr_2  ,
    input                       wr_clr_2  , 
    input                       rd_en_2   ,
    input                       wr_en_2   ,

    input                       ifm_demux ,
    input                       ifm_mux   ,
    
    input  [DATA_WIDTH - 1 : 0] data_in   ,
    output [DATA_WIDTH - 1 : 0] data_out
);

    wire [DATA_WIDTH - 1 : 0] data_in_1 , data_in_2 ;
    wire [DATA_WIDTH - 1 : 0] data_out_1, data_out_2;

    FIFO #(.DATA_WIDTH (DATA_WIDTH), .FIFO_SIZE (MAX_WGT_FIFO_SIZE)) ifm_FIFO_1 (
        .clk           ( clk         ) ,
        .rd_clr        ( rd_clr_1    ) ,
        .wr_clr        ( wr_clr_1    ) ,
        .rd_inc        ( 1'b1        ) ,
        .wr_inc        ( 1'b1        ) ,
        .rd_en         ( rd_en_1     ) ,
        .wr_en         ( wr_en_1     ) ,
        .data_in_fifo  ( data_in_1   ) ,
        .data_out_fifo ( data_out_1  )
    );

    FIFO #(.DATA_WIDTH (DATA_WIDTH), .FIFO_SIZE (MAX_WGT_FIFO_SIZE)) ifm_FIFO_2 (
        .clk           ( clk         ) ,
        .rd_clr        ( rd_clr_2    ) ,
        .wr_clr        ( wr_clr_2    ) ,
        .rd_inc        ( 1'b1        ) ,
        .wr_inc        ( 1'b1        ) ,
        .rd_en         ( rd_en_2     ) ,
        .wr_en         ( wr_en_2     ) ,
        .data_in_fifo  ( data_in_2   ) ,
        .data_out_fifo ( data_out_2  )
    );

    assign data_in_1 = (ifm_demux == 0) ? data_in : 0             ;
    assign data_in_2 = (ifm_demux == 1) ? data_in : 0             ;
    assign data_out  = (ifm_mux   == 0) ? data_out_1 : data_out_2 ;

endmodule
