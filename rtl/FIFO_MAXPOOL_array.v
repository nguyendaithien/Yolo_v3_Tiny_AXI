
`timescale 1 ns / 1 ps
module FIFO_MAXPOOL_array #(
    parameter DATA_WIDTH  = 16 ,
    parameter NUM_MODULES = 16
) (
    input  [DATA_WIDTH * NUM_MODULES * 2 - 1 : 0] data_in ,
    output [DATA_WIDTH * NUM_MODULES     - 1 : 0] data_out
);

    genvar i;
    generate
        for (i = 0; i < NUM_MODULES; i = i + 1) begin : max_pooling
            MAXPOOL #(.DATA_WIDTH (DATA_WIDTH)) u_maxpooling_2 (
                .data_in_1 ( data_in [(2*i)     * DATA_WIDTH +: DATA_WIDTH] ) ,
                .data_in_2 ( data_in [(2*i + 1) * DATA_WIDTH +: DATA_WIDTH] ) ,
                .data_out  ( data_out[ i        * DATA_WIDTH +: DATA_WIDTH] )
            );
        end
    endgenerate

endmodule
