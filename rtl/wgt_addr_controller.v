module wgt_addr_controller #(
    parameter SYSTOLIC_SIZE = 16      ,
    parameter WGT_RAM_SIZE  = 8845488
) (
    input                                     clk             ,
    input                                     rst_n           ,
    input                                     load            ,

    output reg [$clog2(WGT_RAM_SIZE) - 1 : 0] wgt_addr        ,
    output reg                                read_en         ,
    output reg [4 : 0]                        read_wgt_size   ,

    //Layer config
    input      [10: 0]                        num_filter      ,
    input      [12: 0]                        num_cycle_load  ,
    input      [6 : 0]                        num_load_filter ,

    input      [6 : 0]                        count_filter    
);

    parameter IDLE       = 2'b00 ;
    parameter HOLD       = 2'b01 ;
    parameter ADDRESSING = 2'b10 ;
    parameter UPDATE     = 2'b11 ;

    reg [1 : 0] current_state, next_state;

    reg [12: 0] count;

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
            HOLD: next_state = ADDRESSING;
            ADDRESSING: begin 
                if (count == num_cycle_load - 1) next_state = UPDATE;
                else                             next_state = ADDRESSING;
            end
            UPDATE:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
                    wgt_addr      <= 0             ;  
                    read_en       <= 0             ;
                    read_wgt_size <= SYSTOLIC_SIZE ;
                    count         <= 0             ;
        end
        else begin
            case (next_state)
                IDLE: begin
                    wgt_addr <= wgt_addr ;
                    read_en  <= 0        ;
                    count    <= 0        ;
                end
                HOLD: begin
                    wgt_addr      <= wgt_addr ;
                    read_en       <= 1 ;
                    count         <= 0 ;
                    read_wgt_size <= (num_filter == 11'd255 && count_filter == num_load_filter - 1) ? 5'd15 : SYSTOLIC_SIZE ;
                end
                ADDRESSING: begin
                    wgt_addr <= wgt_addr + read_wgt_size ;
                    read_en  <= 1                        ;
                    count    <= count + 1                ;
                end  
                UPDATE: begin
                    wgt_addr <= wgt_addr + read_wgt_size ;
                    read_en  <= 0                        ;
                    count    <= 0                        ;      
                end
            endcase
        end
    end

endmodule
