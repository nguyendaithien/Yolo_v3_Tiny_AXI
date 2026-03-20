
`timescale 1 ns / 1 ps
module MAXPOOL #(
    parameter DATA_WIDTH = 16
) (
    input  [DATA_WIDTH - 1 : 0] data_in_1 , 
    input  [DATA_WIDTH - 1 : 0] data_in_2 , 
    output [DATA_WIDTH - 1 : 0] data_out  
);

    wire signed [DATA_WIDTH - 1 : 0] signed_data_in_1 = data_in_1;
    wire signed [DATA_WIDTH - 1 : 0] signed_data_in_2 = data_in_2;

    assign data_out = (signed_data_in_1 > signed_data_in_2) ? data_in_1 : data_in_2;

endmodule
