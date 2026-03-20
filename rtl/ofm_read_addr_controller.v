module ofm_read_addr_controller #(
    parameter SYSTOLIC_SIZE = 16      ,
    parameter OFM_RAM_SIZE  = 2205619
) (
    input                                     clk                       ,
    input                                     rst_n                     ,
    input                                     start                     ,
    input      [$clog2(OFM_RAM_SIZE) - 1 : 0] start_read_addr           ,
    input                                     load                      ,
    input      [13: 0]                        count_tiling              ,
    input      [8 : 0]                        count_tiling_mod_ofm_size ,

    output reg [$clog2(OFM_RAM_SIZE) - 1 : 0] ofm_addr                  ,
    output reg                                read_en                   ,
    output reg [4 : 0]                        read_ofm_size             ,    

    //Layer config
    input      [8 : 0]                        ifm_size                  ,
    input      [17: 0]                        channel_size              ,
    input      [10: 0]                        ifm_channel               ,
    input      [1 : 0]                        kernel_size               ,
    input      [8 : 0]                        ofm_size                  ,

    input      [13: 0]                        num_tiling	          
);

    parameter IDLE         = 3'b000 ;
    parameter HOLD         = 3'b001 ;
    parameter PADDING      = 3'b010 ;
    parameter NEXT_PIXEL   = 3'b011 ;
    parameter NEXT_LINE    = 3'b100 ;
    parameter NEXT_CHANNEL = 3'b101 ;
    parameter NEXT_TILING  = 3'b110 ;

    reg [2 : 0] current_state, next_state;
    
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] base_addr             ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] base_addr_rst         ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] start_window_addr     ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] start_window_addr_rst ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] line_addr             ;
    reg [$clog2(OFM_RAM_SIZE) - 1 : 0] channel_addr          ;

    reg [1 : 0] count_pixel   ;
    reg [2 : 0] count_padding ;
    reg [1 : 0] count_line    ;
    reg [10: 0] count_channel ;
    reg [8 : 0] count_height  ; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else        current_state <= next_state;
    end

    always @(*) begin
        case (current_state)
            IDLE: begin  
                if (load) next_state = HOLD;
                else      next_state = IDLE;
            end
            HOLD: begin
                if      (kernel_size == 1)                                           next_state = NEXT_CHANNEL;
                else if (count_tiling <= ofm_size || count_tiling_mod_ofm_size == 1) next_state = PADDING;
                else                                                                 next_state = NEXT_PIXEL;
            end   
            PADDING: begin
                if (count_tiling == 1) begin
                    if      (count_line == 0 && count_padding == 4) next_state = NEXT_PIXEL;
                    else if (count_line != 0)                       next_state = NEXT_PIXEL;
                    else                                            next_state = PADDING;
                end
                else if (count_tiling < ofm_size) next_state = NEXT_PIXEL;
                else if (count_tiling == ofm_size) begin
                    if      (count_line < 2)                                                            next_state = NEXT_PIXEL;
                    else if (count_line == 2 && count_padding == 2 && count_channel <  ifm_channel - 1) next_state = NEXT_CHANNEL;
                    else if (count_line == 2 && count_padding == 2 && count_channel == ifm_channel - 1) next_state = NEXT_TILING;
                    else                                                                                next_state = PADDING;
                end
                else if (count_tiling_mod_ofm_size == 1) begin
                    if (count_line == 0 && count_padding == 3) next_state = NEXT_PIXEL;
                    else                                       next_state = PADDING;
                end
                else if (count_tiling_mod_ofm_size == 0) begin
                    if      (count_line == 1 && count_padding == 3 && count_channel == ifm_channel - 1) next_state = NEXT_TILING;
                    else if (count_line == 1 && count_padding == 3)                                     next_state = NEXT_CHANNEL;
                    else                                                                                next_state = PADDING;
                end 
                else next_state = PADDING;
            end         
            NEXT_PIXEL: begin
                if (count_tiling == 1) begin
                    if      (count_line == 1 && count_channel == ifm_channel - 1) next_state = NEXT_TILING;
                    else if (count_line == 1)                                     next_state = NEXT_CHANNEL;
                    else                                                          next_state = NEXT_LINE;
                end
                else if (count_tiling < ofm_size) begin
                    if      (count_pixel == 1 && count_line == 2 && count_channel == ifm_channel - 1) next_state = NEXT_TILING;
                    else if (count_pixel == 1 && count_line == 2 )                                    next_state = NEXT_CHANNEL;
                    else if (count_pixel == 1)                                                        next_state = NEXT_LINE;   
                    else                                                                              next_state = NEXT_PIXEL;                   
                end
                else if (count_tiling == ofm_size) begin
                    if (count_pixel == 1) next_state = NEXT_LINE;   
                    else                  next_state = NEXT_PIXEL;
                end
                else if (count_tiling_mod_ofm_size == 1) begin
                    if      (count_pixel == 2 && count_line == 1 && count_channel == ifm_channel - 1) next_state = NEXT_TILING;   
                    else if (count_pixel == 2 && count_line == 1)                                     next_state = NEXT_CHANNEL;  
                    else if (count_pixel == 2)                                                        next_state = NEXT_LINE;
                    else                                                                              next_state = NEXT_PIXEL;
                end
                else if (count_tiling_mod_ofm_size == 0) begin
                    if      (count_pixel == 2 && count_line == 1) next_state = PADDING;
                    else if (count_pixel == 2)                    next_state = NEXT_LINE;
                    else                                          next_state = NEXT_PIXEL;
                end 
                else begin
                    if      (count_pixel == 2 && count_line == 2 && count_channel == ifm_channel - 1) next_state = NEXT_TILING;   
                    else if (count_pixel == 2 && count_line == 2)                                     next_state = NEXT_CHANNEL;  
                    else if (count_pixel == 2)                                                        next_state = NEXT_LINE;
                    else                                                                              next_state = NEXT_PIXEL;
                end
            end 
            NEXT_LINE: begin
                if (count_tiling <= ofm_size) next_state = PADDING;
                else                          next_state = NEXT_PIXEL;
            end
            NEXT_CHANNEL: begin
                if (kernel_size == 1) begin
                    if (count_channel == ifm_channel - 1) next_state = NEXT_TILING;
                    else                                  next_state = NEXT_CHANNEL;
                end
                else begin
                    if (count_tiling <= ofm_size || count_tiling_mod_ofm_size == 1) next_state = PADDING;
                    else                                                            next_state = NEXT_PIXEL;
                end
            end 
            NEXT_TILING: next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
                    ofm_addr              <= 0                                                     ;
                    read_en               <= 0                                                     ;
                    read_ofm_size         <= (ofm_size < SYSTOLIC_SIZE) ? ofm_size : SYSTOLIC_SIZE ;
                    base_addr             <= 0                                                     ;
                    base_addr_rst         <= 0                                                     ;
                    start_window_addr     <= 0                                                     ;
                    start_window_addr_rst <= 0                                                     ;
                    line_addr             <= 0                                                     ;
                    channel_addr          <= 0                                                     ;                     
                    count_pixel           <= 0                                                     ;
                    count_padding         <= 0                                                     ;
                    count_line            <= 0                                                     ;
                    count_channel         <= 0                                                     ;
                    count_height          <= 0                                                     ;
        end
        else begin
            case (next_state)
                IDLE: begin
                    ofm_addr              <= (start) ? start_read_addr : start_window_addr                                     ;
                    read_en               <= 0                                                                                 ;
                    read_ofm_size         <= (start) ? ((ofm_size < SYSTOLIC_SIZE) ? ofm_size : SYSTOLIC_SIZE) : read_ofm_size ;
                    base_addr             <= (start) ? start_read_addr : base_addr                                             ;
                    base_addr_rst         <= (start) ? 0 : base_addr_rst                                                       ;
                    start_window_addr     <= (start) ? start_read_addr : start_window_addr                                     ;
                    start_window_addr_rst <= (start) ? 0 : start_window_addr_rst                                               ;  
                    line_addr             <= 0                                                                                 ;
                    channel_addr          <= 0                                                                                 ;                    
                    count_pixel           <= 0                                                                                 ;
                    count_padding         <= 0                                                                                 ;
                    count_line            <= 0                                                                                 ;
                    count_channel         <= 0                                                                                 ;
                end 
                HOLD: begin  
                    ofm_addr      <= ofm_addr ;
                    read_en       <= 1        ;    
                    read_ofm_size <= (count_tiling <= num_tiling - ofm_size) ? SYSTOLIC_SIZE : ((count_tiling == num_tiling - ofm_size + 1) ? ((num_tiling <= 14'd16) ? ((ifm_size + 2) - base_addr_rst - kernel_size + 1) : ((ifm_size + 2) - (base_addr_rst + 1) - kernel_size + 1)) : read_ofm_size) ; 
                end
                PADDING: begin
                    ofm_addr      <= ofm_addr          ;
                    read_en       <= 1                 ;   
                    count_padding <= count_padding + 1 ;
                end
                NEXT_PIXEL: begin
                    ofm_addr      <= ofm_addr + 1    ;
                    read_en       <= 1               ;
                    count_pixel   <= count_pixel + 1 ;
                    count_padding <= 0               ;
                end
                NEXT_LINE: begin
                    ofm_addr    <= start_window_addr + channel_addr + (line_addr + ifm_size) ;
                    line_addr   <= line_addr + ifm_size                                      ;
                    read_en     <= 1                                                         ;
                    count_line  <= count_line + 1                                            ;
                    count_pixel <= 0                                                         ;
                end
                NEXT_CHANNEL: begin
                    ofm_addr      <= start_window_addr + (channel_addr + channel_size) ;
                    channel_addr  <= channel_addr + channel_size                       ;
                    line_addr     <= 0                                                 ;
                    read_en       <= 1                                                 ;
                    count_channel <= count_channel + 1                                 ;
                    count_line    <= 0                                                 ; 
                    count_pixel   <= 0                                                 ;
                end
                NEXT_TILING: begin
                    read_en               <= 0 ;
                    count_height          <= (count_height == ofm_size   - 1) ? 0 : count_height + 1 ;
                    base_addr             <= (count_tiling == num_tiling - 1) ? start_read_addr : ((count_height == ofm_size - 2) ? ((kernel_size == 3 && count_tiling == ofm_size - 1) ? (base_addr     + SYSTOLIC_SIZE - 1) : (base_addr     + SYSTOLIC_SIZE)) : base_addr    ) ;
                    base_addr_rst         <= (count_tiling == num_tiling - 1) ? 0               : ((count_height == ofm_size - 2) ? ((kernel_size == 3 && count_tiling == ofm_size - 1) ? (base_addr_rst + SYSTOLIC_SIZE - 1) : (base_addr_rst + SYSTOLIC_SIZE)) : base_addr_rst) ;
                    start_window_addr     <= (count_height == ofm_size   - 1) ? base_addr     : ((kernel_size == 3 && count_tiling_mod_ofm_size == 1) ? start_window_addr : start_window_addr + ifm_size) ;  
                    start_window_addr_rst <= (count_height == ofm_size   - 1) ? base_addr_rst : start_window_addr_rst + ifm_size ;
                end
            endcase
        end
    end

endmodule
