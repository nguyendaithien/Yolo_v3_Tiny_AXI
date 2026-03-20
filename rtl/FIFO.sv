module FIFO_OFM #(
	parameter DATA_WIDTH = 16   , 
	parameter FIFO_SIZE  = 4608 
) (
	input                           clk           ,
	input                           rst_n         ,
	input                           rd_clr        ,
	input                           wr_clr        ,
	input                           rd_inc        ,
	input                           wr_inc        ,
	input                           rd_en         ,
	input                           wr_en         ,
	input      [DATA_WIDTH - 1 : 0] data_in_fifo  ,
	output reg [DATA_WIDTH - 1 : 0] data_out_fifo ,               
	output wire                     empty         ,
	output wire                     full
);

	reg [DATA_WIDTH        - 1 : 0] fifo_data [0 : FIFO_SIZE - 1] ;
	reg [$clog2(FIFO_SIZE) - 1 : 0] rd_ptr                        ;
	reg [$clog2(FIFO_SIZE) - 1 : 0] wr_ptr                        ;
	reg [$clog2(FIFO_SIZE) - 1 : 0] cnt,cnt_next                  ;

	wire [$clog2(FIFO_SIZE) - 1 : 0] rd_ptr_next   ;
	assign rd_ptr_next = (rd_ptr == FIFO_SIZE - 1) ? '0 :  rd_ptr + (rd_en && !empty);
	always @(posedge clk or negedge rst_n) begin
		if (rd_clr || !rst_n) begin
			data_out_fifo <= 0 ;
			rd_ptr        <= 0 ;
		end 
		else if (rd_en && !empty) begin
			data_out_fifo <= fifo_data[rd_ptr] ;
			rd_ptr        <= rd_ptr_next   ;
		end
		else data_out_fifo <= 0 ;
	end

	wire [$clog2(FIFO_SIZE) - 1 : 0] wr_ptr_next                        ;
	assign wr_ptr_next = (wr_ptr == FIFO_SIZE - 1 ) ? '0 :( wr_ptr + (wr_en && !full));

	always @(posedge clk or negedge rst_n) begin
		if      (wr_clr || !rst_n) wr_ptr <= 0 ; 
		else if (wr_en && !full) begin
			fifo_data[wr_ptr] <= data_in_fifo    ;
			wr_ptr            <= wr_ptr_next ;
		end
	end

  // count logic
  assign cnt_next = cnt + (wr_en && !full) - (rd_en && !empty);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= '0;
    end else begin
      cnt <= cnt_next;
    end
  end

  // flags
  assign full  = (cnt == FIFO_SIZE);
  assign empty = (cnt == 0);
  assign count = cnt;

endmodule
