module ifm_addr_controller #(
    parameter SYSTOLIC_SIZE = 16     ,
    parameter IFM_RAM_SIZE  = 524172
) (
    input                                     clk          ,
    input                                     rst_n        ,
    input                                     load         ,

    output reg [$clog2(IFM_RAM_SIZE) - 1 : 0] ifm_addr     ,
    output reg                                read_en      ,  

    //Layer config
    input      [8 : 0]                        ifm_size     ,
    input      [17: 0]                        channel_size ,
    input      [10: 0]                        ifm_channel  ,
    input      [8 : 0]                        ofm_size
);

    parameter IDLE         = 3'b000 ;
    parameter HOLD         = 3'b001 ;
    parameter NEXT_PIXEL   = 3'b010 ;
    parameter NEXT_LINE    = 3'b011 ;
    parameter NEXT_CHANNEL = 3'b100 ;
    parameter NEXT_TILING  = 3'b101 ;

    reg [2 : 0] current_state, next_state;
    
    reg [$clog2(IFM_RAM_SIZE) - 1 : 0] base_addr;
    reg [$clog2(IFM_RAM_SIZE) - 1 : 0] start_window_addr;
    reg [$clog2(IFM_RAM_SIZE) - 1 : 0] line_addr;
    reg [$clog2(IFM_RAM_SIZE) - 1 : 0] channel_addr;
    
    reg [1 : 0] count_pixel;
    reg [1 : 0] count_line;
    reg [10: 0] count_channel;
    reg [8 : 0] count_height; 

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
            HOLD: next_state = NEXT_PIXEL;          
            NEXT_PIXEL: begin
                if      (count_pixel == 2 && count_line == 2 && count_channel == ifm_channel - 1) next_state = NEXT_TILING;   
                else if (count_pixel == 2 && count_line == 2)                                     next_state = NEXT_CHANNEL;  
                else if (count_pixel == 2)                                                        next_state = NEXT_LINE;
                else                                                                              next_state = NEXT_PIXEL;
            end 
            NEXT_LINE:    next_state = NEXT_PIXEL;
            NEXT_CHANNEL: next_state = NEXT_PIXEL;
            NEXT_TILING:  next_state = IDLE;
            default:      next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
                    ifm_addr          <= 0 ;
                    read_en           <= 0 ;
                    base_addr         <= 0 ;
                    start_window_addr <= 0 ;
                    line_addr         <= 0 ;
                    channel_addr      <= 0 ; 
                    count_pixel       <= 0 ;
                    count_line        <= 0 ;
                    count_channel     <= 0 ;
                    count_height      <= 0 ;
        end
        else begin
            case (next_state)
                IDLE: begin
                    ifm_addr      <= start_window_addr ;
                    read_en       <= 0                 ;
                    line_addr     <= 0                 ;
                    channel_addr  <= 0                 ; 
                    count_pixel   <= 0                 ;
                    count_line    <= 0                 ;
                    count_channel <= 0                 ;
                end 
                HOLD: begin  
                    ifm_addr <= ifm_addr ;
                    read_en  <= 1        ;    
                end
                NEXT_PIXEL: begin
                    ifm_addr    <= ifm_addr + 1    ;
                    read_en     <= 1               ;
                    count_pixel <= count_pixel + 1 ;
                end
                NEXT_LINE: begin
                    ifm_addr    <= start_window_addr + channel_addr + (line_addr + ifm_size) ;
                    line_addr   <= line_addr + ifm_size                                      ;
                    read_en     <= 1                                                         ;
                    count_line  <= count_line + 1                                            ;
                    count_pixel <= 0                                                         ;
                end
                NEXT_CHANNEL: begin
                    ifm_addr      <= start_window_addr + (channel_addr + channel_size) ;
                    channel_addr  <= channel_addr + channel_size                       ;
                    line_addr     <= 0                                                 ;
                    read_en       <= 1                                                 ;
                    count_channel <= count_channel + 1                                 ;
                    count_line    <= 0                                                 ; 
                    count_pixel   <= 0                                                 ;
                end
                NEXT_TILING: begin
                    read_en           <= 0                                                                         ;
                    count_height      <= (count_height == ofm_size - 1) ? 0 : count_height + 1                     ;
                    base_addr         <= (count_height == ofm_size - 2) ? base_addr + SYSTOLIC_SIZE : base_addr    ;
                    start_window_addr <= (count_height == ofm_size - 1) ? base_addr : start_window_addr + ifm_size ;  
                end
            endcase
        end
    end

endmodule