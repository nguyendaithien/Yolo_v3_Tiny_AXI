module wgt_FIFO_array #(
    parameter DATA_WIDTH        = 16   ,
    parameter INOUT_WIDTH       = 256  ,
    parameter MAX_WGT_FIFO_SIZE = 4608 ,
    parameter NUM_FIFO          = 16
) (
    input                                  clk           ,
    input                                  rd_clr        ,
    input                                  wr_clr        ,
    input  [NUM_FIFO              - 1 : 0] rd_en         ,
    input                                  wr_en         ,
    input  [4 : 0]                         read_wgt_size ,
    input  [DATA_WIDTH * NUM_FIFO - 1 : 0] data_in       ,
    output [DATA_WIDTH * NUM_FIFO - 1 : 0] data_out
);

    reg [DATA_WIDTH * NUM_FIFO - 1 : 0] wgt_data_in ;    

    integer i;
    always @(*) begin
        wgt_data_in = {INOUT_WIDTH{1'b0}};
        case (read_wgt_size)
            1 : for (i = 0; i <  1 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            2 : for (i = 0; i <  2 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            3 : for (i = 0; i <  3 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            4 : for (i = 0; i <  4 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            5 : for (i = 0; i <  5 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            6 : for (i = 0; i <  6 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            7 : for (i = 0; i <  7 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            8 : for (i = 0; i <  8 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            9 : for (i = 0; i <  9 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            10: for (i = 0; i < 10 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            11: for (i = 0; i < 11 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            12: for (i = 0; i < 12 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            13: for (i = 0; i < 13 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            14: for (i = 0; i < 14 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            15: for (i = 0; i < 15 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            16: for (i = 0; i < 16 * DATA_WIDTH; i = i + 1) wgt_data_in[i] = data_in[i];
            default: ;
        endcase
    end

    genvar j;
    generate
        for (j = 0; j < NUM_FIFO; j = j + 1) begin
            FIFO #(.DATA_WIDTH (DATA_WIDTH), .FIFO_SIZE (MAX_WGT_FIFO_SIZE)) wgt_FIFO_inst (
                .clk           ( clk                                        ) ,
                .rd_clr        ( rd_clr                                     ) ,
                .wr_clr        ( wr_clr                                     ) ,
                .rd_inc        ( 1'b1                                       ) ,
                .wr_inc        ( 1'b1                                       ) ,
                .rd_en         ( rd_en [j]                                  ) ,
                .wr_en         ( wr_en                                      ) ,
                .data_in_fifo  ( wgt_data_in [j * DATA_WIDTH +: DATA_WIDTH] ) ,
                .data_out_fifo ( data_out    [j * DATA_WIDTH +: DATA_WIDTH] )
            );
        end
    endgenerate

endmodule