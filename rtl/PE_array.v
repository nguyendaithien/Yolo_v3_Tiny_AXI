`timescale 1 ns / 1 ps
module PE_array #(
    parameter DATA_WIDTH    = 16 , 
    parameter SYSTOLIC_SIZE = 16 ,
    parameter Q             = 9
) (
    input                                       clk          ,
    input                                       rst_n        ,
    input                                       reset_pe     ,
    input                                       write_out_en ,
    input  [SYSTOLIC_SIZE * DATA_WIDTH - 1 : 0] wgt_in       ,
    input  [SYSTOLIC_SIZE * DATA_WIDTH - 1 : 0] ifm_in       ,
    output [SYSTOLIC_SIZE * DATA_WIDTH - 1 : 0] ofm_out
);

    wire [SYSTOLIC_SIZE * SYSTOLIC_SIZE * DATA_WIDTH - 1 : 0] right_out  ;  
    wire [SYSTOLIC_SIZE * SYSTOLIC_SIZE * DATA_WIDTH - 1 : 0] bottom_out ;
    wire [SYSTOLIC_SIZE * SYSTOLIC_SIZE * DATA_WIDTH - 1 : 0] mac_out    ;

    genvar i, j;
    generate
        for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin : row
            for (j = 0; j < SYSTOLIC_SIZE; j = j + 1) begin : col
                PE #(.DATA_WIDTH (DATA_WIDTH), .Q (Q)) pe_inst (
                    .clk          ( clk                                                                                                                                ) ,
                    .rst_n        ( rst_n                                                                                                                              ) ,
                    .write_out_en ( write_out_en                                                                                                                       ) , 
                    .reset_pe     ( reset_pe                                                                                                                           ) ,
                    .top_in       ( (i == 0                ) ? wgt_in [j*DATA_WIDTH +: DATA_WIDTH] : bottom_out [((i-1)*SYSTOLIC_SIZE + j) * DATA_WIDTH +: DATA_WIDTH] ) ,
                    .left_in      ( (j == 0                ) ? ifm_in [i*DATA_WIDTH +: DATA_WIDTH] : right_out  [(i*SYSTOLIC_SIZE + (j-1)) * DATA_WIDTH +: DATA_WIDTH] ) ,
                    .mac_in       ( (j == SYSTOLIC_SIZE - 1) ? {DATA_WIDTH{1'b0}}                  : mac_out    [(i*SYSTOLIC_SIZE + (j+1)) * DATA_WIDTH +: DATA_WIDTH] ) ,
                    .bottom_out   ( bottom_out [(i*SYSTOLIC_SIZE + j) * DATA_WIDTH +: DATA_WIDTH]                                                                      ) ,
                    .right_out    ( right_out  [(i*SYSTOLIC_SIZE + j) * DATA_WIDTH +: DATA_WIDTH]                                                                      ) ,
                    .mac_out      ( mac_out    [(i*SYSTOLIC_SIZE + j) * DATA_WIDTH +: DATA_WIDTH]                                                                      )
                );
            end
        end
    endgenerate

    assign ofm_out = { 
        mac_out[15*SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[14*SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[13*SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[12*SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[11*SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[10*SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[9 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[8 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[7 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[6 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[5 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[4 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[3 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[2 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[1 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH], 
        mac_out[0 *SYSTOLIC_SIZE*DATA_WIDTH +: DATA_WIDTH]
    };    

endmodule
