
`timescale 1 ns / 1 ps
module tb();
parameter ID_WIDTH     = 4;
parameter ADDR_WIDTH   = 16;
parameter DATA_WIDTH   = 16;        

parameter SYSTOLIC_SIZE     = 16      ;
parameter INOUT_WIDTH       = 256     ;
parameter IFM_RAM_SIZE      = 524172  ;
parameter WGT_RAM_SIZE      = 8845488 ;
parameter OFM_RAM_SIZE_1    = 2205619 ;
parameter OFM_RAM_SIZE_2    = 259584  ;
parameter MAX_WGT_FIFO_SIZE = 4608    ;
parameter RELU_PARAM        = 0       ;
parameter Q                 = 9       ;

	parameter AXI_WIDTH =   128;

parameter NUM_LAYER         = 1       ;
localparam OFM_SIZE   = 208 ;
localparam NUM_FILTER = 16 ;
  reg                       rd_en ;
  reg                     	wr_en ;
  reg  [ADDR_WIDTH-1:0]     addr_R  ;
  reg  [ADDR_WIDTH-1:0]     addr_W  ;
  reg  [AXI_WIDTH-1:0]     wdata ;
  wire [AXI_WIDTH-1:0]     rdata ;
	wire                       busy_r  ; 
	wire                       busy_w  ; 
  reg ACLK;
  reg ARESETN;
	reg [10:0] num_channel           ;
	wire read_en_out                 ;
	reg start_read                   ;
	reg [8:0] ifm_size               ;
	reg wr_en_test;
	wire done_CNN;

top_axi_master_slave top  (
   .rd_en       ( rd_en       ) ,
   .wr_en       ( wr_en       ) ,
   .addr_R      ( addr_R      ) ,
   .addr_W      ( addr_W      ) ,
   .wdata       ( wdata       ) ,
   .rdata       ( rdata       ) ,
   .busy_r      ( busy_r      ) ,
   .busy_w      ( busy_w      ) ,
   .ACLK        ( ACLK        ) ,
   .ARESETN     ( ARESETN     ) ,
   .num_channel ( num_channel ) ,
   .read_en_out ( read_en_out ) ,
   .start_read  ( start_read  ) ,
   .wr_en_test  ( wr_en_test  ) ,
   .ifm_size    ( ifm_size    ) ,
	 .done_CNN    (done_CNN     ) 
);
always #5 ACLK = !ACLK ;

//always @(posedge top.BREADY) begin
//      $display(" data in memory ofm in %d : %h ", top.AWADDR, top.u_slave.mem[top.AWADDR]);
//end

integer fd;
integer i, j, c;

initial begin
    // Wait until rd_end is asserted
    @(posedge top.u_master.end_read_ifm);
    fd = $fopen("../data/ifm_memory.txt", "w");
    if (fd == 0) begin
        $display("Error: could not open output file.");
        $finish;
    end
    // Dump memory per channel
    for (c = 0; c < 3; c = c + 1) begin
        for (i = 0; i < 418; i = i + 1) begin
            for (j = 0; j < 418; j = j + 1) begin
                $fwrite(fd, "%0d ", top.ifm_bram.mem[c*418*418 + i*418 + j]);
            end
            $fwrite(fd, "\n");
        end
        $fwrite(fd, "\n"); // blank line between channels
    end

    $fclose(fd);
    $display("Dumped IFM memory to ifm_memory.txt");
end

//write to output text file
integer file;
initial begin
    wait (done_CNN)
    file = $fopen ("../data/output_matrix.txt", "w");
        for (i = 0; i < OFM_SIZE * NUM_FILTER; i = i + 1) begin
            for (j = 0; j < OFM_SIZE; j = j + 1) begin
                $fwrite (file, "%0d ", $signed(top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.ofm_dpram_1.mem[i * OFM_SIZE + j + 0])); //9558
            end
            $fwrite (file, "\n");
            if ( (i + 1) % OFM_SIZE == 0 ) $fwrite (file, "\n");
        end
        $fclose (file);
end

initial begin
		ACLK = 0;
	wr_en_test = 0;
	num_channel = 11'd3;
	ifm_size = 9'd418;
		ARESETN = 0 ;
   # 30 
		ARESETN = 1 ;
	# 20 
	start_read = 0;
    rd_en  = 0;
    wr_en  = 0;
    addr_R   = 0;
    addr_W   = 16;
    wdata  =  16'd20; 
	# 50 
    rd_en  = 1;
	  start_read = 1;
	# 10 
    rd_en  = 0;
  	start_read = 0;
	  wdata = 16'd 45;
end
initial begin
	#135 wr_en_test = 1;
	#10 wr_en_test = 0; 
end

initial begin
    $readmemb ("../data/ifm_128bit.bin", top.u_slave.mem,0);
end

initial begin
    $readmemb ("../data/wgt.txt", top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.wgt_dpram.mem);
end
reg [DATA_WIDTH - 1 : 0] ofm_golden [OFM_SIZE * OFM_SIZE * NUM_FILTER - 1 : 0];

initial begin
	$readmemb ("../data/output_layer1_bin.txt", ofm_golden);
end

initial begin 
    #200000000 $finish  ; 
end


//compare
task compare;
	integer i;
	begin
		for (i = 0; i < OFM_SIZE * OFM_SIZE * NUM_FILTER; i = i + 1) begin
			$display (" matrix ofm RTL : %d", top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.ofm_dpram_1.mem[i + 0]);
			$display (" matrix golden : %d", ofm_golden[i]);
			if (ofm_golden[i] !=top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.ofm_dpram_1.mem[i + 0]) begin
				$display ("NO PASS in addess %d", i);
				disable compare;
			end
		end
		$display("\n");
		$display("██████╗  █████╗ ███████╗███████╗    ████████╗███████╗███████╗████████╗");
		$display("██╔══██╗██╔══██╗██╔════╝██╔════╝    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝");
		$display("██████╔╝███████║███████╗███████╗       ██║   █████╗  ███████    ██║   ");
		$display("██╔═══╝ ██╔══██║╚════██║╚════██║       ██║   ██╔══╝       ██    ██║   ");
		$display("██║     ██║  ██║███████║███████║       ██║   ███████╗███████╗   ██║   ");
		$display("╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝       ╚═╝   ╚══════╝╚══════╝   ╚═╝   ");
		#1ms;
		$finish;
	end
endtask

always @(posedge done_CNN) begin
	if (done_CNN) begin
		compare();
	end
end
always @(posedge ACLK or negedge ARESETN) begin
	if(top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.write_out_ofm_en_1) begin
		$display ("OFM: %h", top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.ofm_data_out_1);
	end
end

//initial begin
//	$monitor ("At time : %d - ofm_size = %d - count_layer = %d - counter filter = %d (max = %d) - counter tiling = %d (max = %d)", $time, top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.ofm_size_conv,top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.count_layer,top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.control.count_filter, top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.control.num_load_filter, top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.control.count_tiling, top.wrapper_ip.SYSTOLIC_ARRAY_v1_0_M00_AXI_inst.F_U.control.num_tiling);
//end

endmodule

