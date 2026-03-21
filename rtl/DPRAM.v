
`timescale 1 ns / 1 ps
module DPRAM #(
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
    input      [INOUT_WIDTH - 1 : 0] din_b          ,
    
    input                                 upsample_mode  , 
    input      [8 : 0]                    ofm_size
);

    reg [DATA_WIDTH - 1 : 0] mem     [0 : RAM_SIZE      - 1] ;
    reg [DATA_WIDTH - 1 : 0] data_in [0 : SYSTOLIC_SIZE - 1] ;

    integer i;

    always @(*) begin
        for (i = 0; i < SYSTOLIC_SIZE ; i = i + 1) begin
            data_in[i] = din_b[i*DATA_WIDTH +: DATA_WIDTH];
        end
    end

    
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
            for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                if (i < write_ofm_size) begin
                    if (upsample_mode) begin
                        mem[addr_b + 2*i]                <= data_in[i];
                        mem[addr_b + 2*i + 1]            <= data_in[i];
                        mem[addr_b + ofm_size + 2*i]     <= data_in[i];
                        mem[addr_b + ofm_size + 2*i + 1] <= data_in[i];
                    end 
                    else begin
                        mem[addr_b + i]                  <= data_in[i];
                    end
                end
            end
        end
    end

endmodule
