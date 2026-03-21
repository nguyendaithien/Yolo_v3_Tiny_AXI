
`timescale 1 ns / 1 ps
module FIFO #(
	parameter DATA_WIDTH = 16   , 
	parameter FIFO_SIZE  = 4608 
) (
	input                           clk           ,
	input                           rd_clr        ,
	input                           wr_clr        ,
	input                           rd_inc        ,
	input                           wr_inc        ,
	input                           rd_en         ,
	input                           wr_en         ,
	input      [DATA_WIDTH - 1 : 0] data_in_fifo  ,
	output reg [DATA_WIDTH - 1 : 0] data_out_fifo                
);

	reg [DATA_WIDTH        - 1 : 0] fifo_data [0 : FIFO_SIZE - 1] ;
	reg [$clog2(FIFO_SIZE) - 1 : 0] rd_ptr                        ;
	reg [$clog2(FIFO_SIZE) - 1 : 0] wr_ptr                        ;

	always @(posedge clk) begin
		if (rd_clr) begin
			data_out_fifo <= 0 ;
			rd_ptr        <= 0 ;
		end 
		else if (rd_en) begin
			data_out_fifo <= fifo_data[rd_ptr] ;
			rd_ptr        <= rd_ptr + rd_inc   ;
		end
		else data_out_fifo <= 0 ;
	end

	always @(posedge clk) begin
		if      (wr_clr) wr_ptr <= 0 ; 
		else if (wr_en) begin
			fifo_data[wr_ptr] <= data_in_fifo    ;
			wr_ptr            <= wr_ptr + wr_inc ;
		end
	end

endmodule
