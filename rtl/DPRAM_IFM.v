
`timescale 1 ns / 1 ps
module DPRAM_IFM #(
  parameter RAM_SIZE          = 524172 ,
  parameter DATA_WIDTH        = 16     ,
  parameter BUFFER_ADDR_WIDTH = 19     ,
  parameter BUFFER_DATA_WIDTH = 256    ,
  parameter INOUT_WIDTH       = 256    ,
  parameter IFM_WIDTH         = 418    ,
  parameter SYSTOLIC_SIZE     = 16
) (
    input                                 clk            ,
    input      [4 : 0]                    write_ofm_size ,

    input                                 re_a           ,
    input      [$clog2(RAM_SIZE) - 1 : 0] addr_a         ,
    output reg [INOUT_WIDTH      - 1 : 0] dout_a         , 
    
    input                                 we_b           ,
    input      [$clog2(RAM_SIZE) - 1 : 0] addr_b         ,
    input      [BUFFER_DATA_WIDTH - 1 : 0] din_b          ,
    
    input                                 upsample_mode  , 
    input      [8 : 0]                    ofm_size
);

  (* ram_style = "ultra" *)  reg [DATA_WIDTH - 1 : 0] mem     [0 : RAM_SIZE      - 1] ;
    wire [DATA_WIDTH - 1 : 0] data_in [0 : (SYSTOLIC_SIZE/2) - 1] ;

    integer i;

//    always @(*) begin
//        for (i = 0; i <8  ; i = i + 1) begin
//            data_in[i] = din_b[i*DATA_WIDTH +: DATA_WIDTH];
//        end
//    end

assign data_in[0] = din_b[7*DATA_WIDTH +: DATA_WIDTH];    // din_b[127:112]
assign data_in[1] = din_b[6*DATA_WIDTH +: DATA_WIDTH];    // din_b[111:96]
assign data_in[2] = din_b[5*DATA_WIDTH +: DATA_WIDTH];    // din_b[95:80]
assign data_in[3] = din_b[4*DATA_WIDTH +: DATA_WIDTH];    // din_b[79:64]
assign data_in[4] = din_b[3*DATA_WIDTH +: DATA_WIDTH];    // din_b[63:48]
assign data_in[5] = din_b[2*DATA_WIDTH +: DATA_WIDTH];    // din_b[47:32]
assign data_in[6] = din_b[1*DATA_WIDTH +: DATA_WIDTH];    // din_b[31:16]
assign data_in[7] = din_b[0*DATA_WIDTH +: DATA_WIDTH];    // din_b[15:0]

    
    //Port A: read 
    always @(posedge clk) begin
        if (re_a) begin
            for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                dout_a[i*DATA_WIDTH +: DATA_WIDTH] <= mem[addr_a + i];
            end
        end 
        else begin
            dout_a <= {INOUT_WIDTH{1'b0}};
        end
    end

    //Port B: Write 
    always @(posedge clk) begin
        if (we_b) begin
            for (i = 0; i < SYSTOLIC_SIZE/2; i = i + 1) begin
                if (i < write_ofm_size) begin
                        mem[addr_b + i]                  <= data_in[i];
                    end
                end
            end
    end

endmodule
