
`timescale 1 ns / 1 ps
module PE #(
	parameter DATA_WIDTH = 16 ,
	parameter Q          = 9
) (
	input                           clk          ,
	input                           rst_n        ,
	input                           reset_pe     ,
	input                           write_out_en ,
	input      [DATA_WIDTH - 1 : 0] top_in       ,
	input      [DATA_WIDTH - 1 : 0] left_in      ,
	input      [DATA_WIDTH - 1 : 0] mac_in       ,
	output reg [DATA_WIDTH - 1 : 0] bottom_out   ,
	output reg [DATA_WIDTH - 1 : 0] right_out    ,
	output reg [DATA_WIDTH - 1 : 0] mac_out
);

	reg  [DATA_WIDTH*2 - 1 : 0] result ;
	wire [DATA_WIDTH*2 - 1 : 0] mult   ;
	wire [DATA_WIDTH   - 1 : 0] quantized_result = {result[DATA_WIDTH*2 - 1], result[DATA_WIDTH - 2 + Q : Q]};

	mult_fixpoint #(.DATA_WIDTH(DATA_WIDTH)) mult_fp (
		.a ( top_in  ) ,
		.b ( left_in ) ,
		.q ( mult    )
	);

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			result     <= {(DATA_WIDTH*2){1'b0}} ;
			bottom_out <= {DATA_WIDTH{1'b0}} ;
			right_out  <= {DATA_WIDTH{1'b0}} ;
			mac_out    <= {DATA_WIDTH{1'b0}} ;
		end
		else begin
			result     <= (reset_pe) ? {(DATA_WIDTH*2){1'b0}} : (mult + result) ;  
			bottom_out <= top_in                                                ;
			right_out  <= left_in                                               ;
			mac_out    <= (write_out_en) ? mac_in : quantized_result            ;
		end
	end

endmodule
