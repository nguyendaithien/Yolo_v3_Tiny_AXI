module ofm_write_addr_controller_2 #(
    parameter SYSTOLIC_SIZE = 16     ,
    parameter OFM_RAM_SIZE  = 259584
) (
    input                                     clk              , 
    input                                     rst_n            ,
    input                                     start            ,
    input      [$clog2(OFM_RAM_SIZE) - 1 : 0] start_write_addr ,
    input                                     write            ,
    input      [4 : 0]                        read_wgt_size    ,

    output reg [$clog2(OFM_RAM_SIZE) - 1 : 0] ofm_addr         ,
    output reg [4 : 0]                        write_ofm_size   ,

    //Layer config
    input      [3 : 0]                        count_layer      ,
    input      [8 : 0]                        ofm_size         , 
    input      [8 : 0]                        ofm_size_conv    , 
    input      [15: 0]                        channel_size     ,
    input                                     upsample_mode    ,

    input      [13: 0]                        num_tiling       ,
    input      [$clog2(OFM_RAM_SIZE) - 1 : 0] write_addr_incr  ,
    input      [4 : 0]                        last_write_size
);

    wire [8 : 0] ofm_size_local = (count_layer == 4'd11) ? ofm_size_conv : ofm_size;
    wire [8 : 0] ofm_size_incr  = (count_layer == 4'd11) ? (ofm_size << 1) : ofm_size;

    parameter IDLE             = 2'b00 ;
    parameter NEXT_CHANNEL     = 2'b01 ;
    parameter UPDATE_BASE_ADDR = 2'b10 ;

    reg [1 : 0] current_state, next_state;
    
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] base_addr             ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] base_addr_rst         ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] start_window_addr     ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] start_window_addr_rst ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] channel_addr          ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] next_addr             ;

    reg [4 : 0] count_channel;
    reg [8 : 0] count_height ;
    reg [13: 0] count_tiling_write ;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else        current_state <= next_state;
    end

    always @(*) begin
        case (current_state)
            IDLE: begin
                if (write) next_state = NEXT_CHANNEL;
                else       next_state = IDLE;
            end
            NEXT_CHANNEL: begin 
                if (count_channel == read_wgt_size - 1) next_state = UPDATE_BASE_ADDR;
                else                                    next_state = NEXT_CHANNEL;
            end
            UPDATE_BASE_ADDR: next_state = IDLE; 
            default:          next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
                    ofm_addr              <= 0 ;                    
                    write_ofm_size        <= (upsample_mode == 1) ? 5'd13 : ((ofm_size < SYSTOLIC_SIZE) ? ofm_size : SYSTOLIC_SIZE) ;
                    base_addr             <= 0 ;
                    base_addr_rst         <= 0 ;
                    start_window_addr     <= 0 ; 
                    start_window_addr_rst <= 0 ;
                    channel_addr          <= 0 ; 
                    next_addr             <= write_addr_incr ;                                 
                    count_channel         <= 0 ;
                    count_height          <= 0 ; 
                    count_tiling_write    <= 0 ;
        end 
        else begin
            case (next_state)
                IDLE: begin
                    ofm_addr              <= (start) ? start_write_addr : start_window_addr ;
                    write_ofm_size        <= (start) ? ((upsample_mode == 1) ? 5'd13 : ((ofm_size < SYSTOLIC_SIZE) ? ofm_size : SYSTOLIC_SIZE)) : write_ofm_size ;
                    base_addr             <= (start) ? start_write_addr : base_addr ;                                  
                    base_addr_rst         <= (start) ? 0 : base_addr_rst ;
                    start_window_addr     <= (start) ? start_write_addr : start_window_addr ;
                    start_window_addr_rst <= (start) ? 0 : start_window_addr_rst ;
                    channel_addr          <= 0 ; 
                    next_addr             <= (start) ? write_addr_incr : next_addr ;
                    count_channel         <= 0 ;
                end                            
                NEXT_CHANNEL: begin
                    ofm_addr      <= start_window_addr + (channel_addr + channel_size) ;  
                    channel_addr  <= channel_addr + channel_size ;
                    count_channel <= count_channel + 1 ;
                end
                UPDATE_BASE_ADDR: begin
                    count_height          <= (count_height       == ofm_size_local - 1) ? 0 : count_height + 1 ;
                    count_tiling_write    <= (count_tiling_write == num_tiling     - 1) ? 0 : count_tiling_write + 1 ;
                    next_addr             <= (count_tiling_write == num_tiling     - 1) ? next_addr + write_addr_incr : next_addr ;
                    base_addr             <= (count_tiling_write == num_tiling     - 2) ? start_write_addr + next_addr : ((count_height == ofm_size_local - 2) ? base_addr     + write_ofm_size : base_addr) ;    
                    base_addr_rst         <= (count_tiling_write == num_tiling     - 2) ?                    next_addr : ((count_height == ofm_size_local - 2) ? base_addr_rst + write_ofm_size : base_addr_rst) ;  
                    start_window_addr     <= (count_height       == ofm_size_local - 1) ? base_addr     : start_window_addr     + ofm_size_incr ;                            
                    start_window_addr_rst <= (count_height       == ofm_size_local - 1) ? base_addr_rst : start_window_addr_rst + ofm_size_incr ;   
                    write_ofm_size        <= (upsample_mode == 1) ? 5'd13 : ((count_tiling_write >= num_tiling - ofm_size_local - 1 && count_tiling_write != num_tiling - 1) ? last_write_size : ((ofm_size < SYSTOLIC_SIZE) ? ofm_size : SYSTOLIC_SIZE)) ; 
                end
            endcase
        end
    end

endmodule
