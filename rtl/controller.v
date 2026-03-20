
`timescale 1 ns / 1 ps
module controller #(
    parameter SYSTOLIC_SIZE = 16
) (
    input                              clk                       , 
    input                              rst_n                     ,
    input                              start                     ,
    input      [4 : 0]                 read_wgt_size             ,      

    output                             load_ifm, load_ofm        ,
    output reg                         load_wgt                  ,
    output reg                         ifm_demux, ifm_mux        ,

    output reg                         wgt_rd_clr                ,
    output reg                         wgt_wr_clr                ,
    output reg [SYSTOLIC_SIZE - 1 : 0] wgt_rd_en                 ,
    output reg                         wgt_wr_en                 ,

    output reg                         ifm_rd_clr_1              ,
    output reg                         ifm_wr_clr_1              ,
    output reg [SYSTOLIC_SIZE - 1 : 0] ifm_rd_en_1               ,
    output reg                         ifm_wr_en_1               ,
 
    output reg                         ifm_rd_clr_2              ,
    output reg                         ifm_wr_clr_2              , 
    output reg [SYSTOLIC_SIZE - 1 : 0] ifm_rd_en_2               ,
    output reg                         ifm_wr_en_2               ,     

    output reg                         maxpool_rd_clr            ,
    output reg                         maxpool_wr_clr            ,
    output reg                         maxpool_rd_en             , 
    output reg                         maxpool_wr_en             ,                

    output reg                         reset_pe                  ,
    output reg                         write_out_pe_en           ,
    output reg                         write_out_maxpool_en      ,
    output reg [6 : 0]                 count_filter              ,
    output reg [13: 0]                 count_tiling              ,
    output reg [8 : 0]                 count_tiling_mod_ofm_size ,
    output reg                         done                      ,
  
    //Layer config
    input      [3 : 0]                 count_layer               ,
    input      [10: 0]                 ifm_channel               ,
    input      [1 : 0]                 kernel_size               , 
    input      [8 : 0]                 ofm_size                  ,
    input      [10: 0]                 num_filter                ,
    input                              maxpool_mode              , 
    input      [1 : 0]                 maxpool_stride            ,

    input      [12: 0]                 num_cycle_load            ,
    input      [12: 0]                 num_cycle_compute         ,
    input      [6 : 0]                 num_load_filter           ,
    input      [13: 0]                 num_tiling
);

    parameter IDLE               = 3'b000 ;
    parameter LOAD_WEIGHT        = 3'b001 ;
    parameter LOAD_COMPUTE       = 3'b010 ;
    parameter LOAD_COMPUTE_WRITE = 3'b011 ; 
    parameter COMPUTE_WRITE      = 3'b100 ;
    parameter WRITE              = 3'b101 ;
    parameter LAST_POOL          = 3'b110 ;

    reg [2 : 0] current_state, next_state ;

    reg [12: 0] count_load      ;
    reg [12: 0] count_compute_1 ;
    reg [12: 0] count_compute_2 ;
    reg [4 : 0] count_write     ;
    reg [4 : 0] count_pooling   ;

    reg sel_write_out_pool_stride_1 ;
    reg sel_write_out_pool_stride_2 ;

    reg load_input ;

    assign load_ifm = (count_layer == 1) ? load_input : 0 ;
    assign load_ofm = (count_layer >  1) ? load_input : 0 ;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE       ;
        else        current_state <= next_state ;
    end

    always @(*) begin
        case (current_state)
            IDLE: begin               
                if (start) next_state = LOAD_WEIGHT ;
                else       next_state = IDLE        ;
            end
            LOAD_WEIGHT: begin        
                if (count_load == num_cycle_load + 2) next_state = LOAD_COMPUTE ;
                else                                  next_state = LOAD_WEIGHT  ;
            end
            LOAD_COMPUTE: begin       
                if (count_compute_1 == num_cycle_compute + 1) next_state = LOAD_COMPUTE_WRITE ;
                else                                          next_state = LOAD_COMPUTE       ;
            end
            LOAD_COMPUTE_WRITE: begin
                if (count_tiling == num_tiling && count_compute_2 == 0) next_state = COMPUTE_WRITE      ;
                else                                                    next_state = LOAD_COMPUTE_WRITE ;
            end
            COMPUTE_WRITE: begin       
                if (count_compute_1 == num_cycle_compute + 1) next_state = WRITE         ;
                else                                          next_state = COMPUTE_WRITE ;
            end
            WRITE: begin 
                if (maxpool_mode == 1 && maxpool_stride == 1 && count_write == SYSTOLIC_SIZE + 1) next_state = LAST_POOL ;
                else begin
                    if      (count_write == SYSTOLIC_SIZE + 1 && count_filter < num_load_filter) next_state = LOAD_WEIGHT ; 
                    else if (count_write == SYSTOLIC_SIZE + 1)                                   next_state = IDLE        ;
                    else                                                                         next_state = WRITE       ;
                end
            end
            LAST_POOL: begin
                    if      (count_pooling == SYSTOLIC_SIZE + 1 && count_filter < num_load_filter) next_state = LOAD_WEIGHT ;
                    else if (count_pooling == SYSTOLIC_SIZE + 1)                                   next_state = IDLE        ;
                    else                                                                           next_state = LAST_POOL   ;
            end
            default: next_state = IDLE ;
        endcase
    end

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin  
                    count_load                  <= 0                     ;
                    count_compute_1             <= 0                     ;
                    count_compute_2             <= 0                     ;
                    count_write                 <= 0                     ;
                    count_filter                <= 0                     ;
                    count_tiling                <= 0                     ;
                    count_tiling_mod_ofm_size   <= 0                     ;
                    count_pooling               <= 0                     ;

                    sel_write_out_pool_stride_1 <= 0                     ;
                    sel_write_out_pool_stride_2 <= 0                     ;

                    load_input                  <= 0                     ;
                    load_wgt                    <= 0                     ;
                    ifm_demux                   <= 0                     ;
                    ifm_mux                     <= 1                     ;
 
                    wgt_rd_clr                  <= 1                     ;
                    wgt_wr_clr                  <= 1                     ;
                    wgt_rd_en                   <= {SYSTOLIC_SIZE{1'b0}} ;
                    wgt_wr_en                   <= 0                     ;

                    ifm_rd_clr_1                <= 1                     ;
                    ifm_wr_clr_1                <= 1                     ;
                    ifm_rd_en_1                 <= {SYSTOLIC_SIZE{1'b0}} ;
                    ifm_wr_en_1                 <= 0                     ;
                    
                    ifm_rd_clr_2                <= 1                     ;
                    ifm_wr_clr_2                <= 1                     ;
                    ifm_rd_en_2                 <= {SYSTOLIC_SIZE{1'b0}} ;
                    ifm_wr_en_2                 <= 0                     ; 

                    maxpool_rd_clr              <= 1                     ;
                    maxpool_wr_clr              <= 1                     ;
                    maxpool_rd_en               <= 0                     ;
                    maxpool_wr_en               <= 0                     ;

                    reset_pe                    <= 0                     ;
                    write_out_pe_en             <= 0                     ;
                    write_out_maxpool_en        <= 0                     ;
                    done                        <= 0                     ; 
        end
        else begin
            case (next_state)
                IDLE: begin
                    count_load                  <= 0                     ;
                    count_compute_1             <= 0                     ;
                    count_compute_2             <= 0                     ;
                    count_write                 <= 0                     ;
                    count_filter                <= 0                     ;
                    count_tiling                <= 0                     ;
                    count_tiling_mod_ofm_size   <= 0                     ;
                    count_pooling               <= 0                     ;

                    sel_write_out_pool_stride_1 <= 0                     ;
                    sel_write_out_pool_stride_2 <= 0                     ;

                    load_input                  <= 0                     ;
                    load_wgt                    <= 0                     ;
                    ifm_demux                   <= 0                     ;
                    ifm_mux                     <= 1                     ;
 
                    wgt_rd_clr                  <= 1                     ;
                    wgt_wr_clr                  <= 1                     ;
                    wgt_rd_en                   <= {SYSTOLIC_SIZE{1'b0}} ;
                    wgt_wr_en                   <= 0                     ;

                    ifm_rd_clr_1                <= 1                     ;
                    ifm_wr_clr_1                <= 1                     ;
                    ifm_rd_en_1                 <= {SYSTOLIC_SIZE{1'b0}} ;
                    ifm_wr_en_1                 <= 0                     ;
                    
                    ifm_rd_clr_2                <= 1                     ;
                    ifm_wr_clr_2                <= 1                     ;
                    ifm_rd_en_2                 <= {SYSTOLIC_SIZE{1'b0}} ;
                    ifm_wr_en_2                 <= 0                     ; 

                    maxpool_rd_clr              <= 1                     ;
                    maxpool_wr_clr              <= 1                     ;
                    maxpool_rd_en               <= 0                     ;
                    maxpool_wr_en               <= 0                     ;

                    reset_pe                    <= 0                     ;
                    write_out_pe_en             <= 0                     ;
                    write_out_maxpool_en        <= 0                     ;
                    done                        <= 0                     ; 
                end 
                LOAD_WEIGHT: begin
                    count_write                 <= 0                                                                    ;                   
                    count_pooling               <= 0                                                                    ;
                    count_load                  <= count_load + 1                                                       ;
                    count_filter                <= (count_load == num_cycle_load - 1) ? count_filter + 1 : count_filter ;
                    count_tiling                <= (count_load == 0) ? count_tiling + 1 : count_tiling                  ;
                    count_tiling_mod_ofm_size   <= (count_load == 0) ? ((count_tiling_mod_ofm_size == ofm_size - 1) ? 0 : count_tiling_mod_ofm_size + 1) : count_tiling_mod_ofm_size ;

                    sel_write_out_pool_stride_1 <= 0                                                                    ;
                    sel_write_out_pool_stride_2 <= 0                                                                    ;

                    load_input                  <= (count_load == 0) ? 1 : 0                                            ;
                    load_wgt                    <= (count_load < num_cycle_load - 1) ? 1 : 0                            ;
                    ifm_demux                   <= 0                                                                    ;
                    ifm_mux                     <= 1                                                                    ;

                    wgt_rd_clr                  <= 1                                                                    ;
                    wgt_wr_clr                  <= (count_load >= 2) ? 0 : 1                                            ;
                    wgt_rd_en                   <= {SYSTOLIC_SIZE{1'b0}}                                                ;
                    wgt_wr_en                   <= (count_load >= 2) ? 1 : 0                                            ;   

                    ifm_rd_clr_1                <= 1                                                                    ;
                    ifm_wr_clr_1                <= (count_load >= 2) ? 0 : 1                                            ;
                    ifm_rd_en_1                 <= {SYSTOLIC_SIZE{1'b0}}                                                ;
                    ifm_wr_en_1                 <= (count_load >= 2) ? 1 : 0                                            ;        

                    ifm_rd_clr_2                <= 1                                                                    ;
                    ifm_wr_clr_2                <= 1                                                                    ;
                    ifm_rd_en_2                 <= {SYSTOLIC_SIZE{1'b0}}                                                ;
                    ifm_wr_en_2                 <= 0                                                                    ;         

                    maxpool_rd_clr              <= 1                                                                    ;
                    maxpool_wr_clr              <= 1                                                                    ;
                    maxpool_rd_en               <= 0                                                                    ;
                    maxpool_wr_en               <= 0                                                                    ;        
 
                    reset_pe                    <= 0                                                                    ;
                    write_out_pe_en             <= 0                                                                    ;
                    write_out_maxpool_en        <= 0                                                                    ;
                    done                        <= 0                                                                    ;             
                end
                LOAD_COMPUTE: begin
                    count_load                  <= 0                                                                         ;
                    count_compute_1             <= count_compute_1 + 1                                                       ;
                    count_tiling                <= (count_compute_1 == 0) ? count_tiling + 1 : count_tiling                  ;
                    count_tiling_mod_ofm_size   <= (count_compute_1 == 0) ? ((count_tiling_mod_ofm_size == ofm_size - 1) ? 0 : count_tiling_mod_ofm_size + 1) : count_tiling_mod_ofm_size ;

                    sel_write_out_pool_stride_1 <= 0                                                                         ;
                    sel_write_out_pool_stride_2 <= 0                                                                         ;

                    load_input                  <= (count_compute_1 == 0) ? 1 : 0                                            ;
                    load_wgt                    <= 0                                                                         ;
                    ifm_demux                   <= (count_compute_1 <= num_cycle_compute - 1) ? 1 : 0                        ;
                    ifm_mux                     <= (count_compute_1 <= num_cycle_compute - 1) ? 0 : 1                        ;

                    wgt_rd_clr                  <= (count_compute_1 < num_cycle_load + SYSTOLIC_SIZE - 1) ? 0 : 1            ;
                    wgt_wr_clr                  <= 1                                                                         ;
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        wgt_rd_en[i]            <= (count_compute_1 >= i && count_compute_1 < num_cycle_load + i) ? 1 : 0    ;
                    end
                    wgt_wr_en                   <= 0                                                                         ;   

                    ifm_rd_clr_1                <= (count_compute_1 < num_cycle_load + SYSTOLIC_SIZE - 1) ? 0 : 1            ;
                    ifm_wr_clr_1                <= 1                                                                         ;
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        ifm_rd_en_1[i]          <= (count_compute_1 >= i && count_compute_1 < num_cycle_load + i) ? 1 : 0    ;
                    end
                    ifm_wr_en_1                 <= 0                                                                         ;   

                    ifm_rd_clr_2                <= 1                                                                         ;
                    ifm_wr_clr_2                <= (count_compute_1 >= 2 && count_compute_1 <= num_cycle_load + 1) ? 0 : 1   ;
                    ifm_rd_en_2                 <= {SYSTOLIC_SIZE{1'b0}}                                                     ;
                    ifm_wr_en_2                 <= (count_compute_1 >= 2 && count_compute_1 <= num_cycle_load + 1) ? 1 : 0   ;    

                    maxpool_rd_clr              <= 1                                                                         ;
                    maxpool_wr_clr              <= 1                                                                         ;
                    maxpool_rd_en               <= 0                                                                         ;
                    maxpool_wr_en               <= 0                                                                         ;  

                    reset_pe                    <= (count_compute_1 == num_cycle_compute) ? 1 : 0                            ;
                    write_out_pe_en             <= 0                                                                         ;
                    write_out_maxpool_en        <= 0                                                                         ;
                    done                        <= 0                                                                         ;    
                end
                LOAD_COMPUTE_WRITE: begin
                    count_compute_1             <= 0                                                                                                       ;
                    count_compute_2             <= (count_compute_2 == num_cycle_compute) ? 0 : count_compute_2 + 1                                        ;
                    count_tiling                <= (count_compute_2 == 0) ? count_tiling + 1 : count_tiling                                                ;
                    count_tiling_mod_ofm_size   <= (count_compute_2 == 0) ? ((count_tiling_mod_ofm_size == ofm_size - 1) ? 0 : count_tiling_mod_ofm_size + 1) : count_tiling_mod_ofm_size ;

                    sel_write_out_pool_stride_1 <= (count_compute_2 == num_cycle_compute - 1) ? 1 : sel_write_out_pool_stride_1                            ;
                    sel_write_out_pool_stride_2 <= (count_compute_2 == num_cycle_compute - 1) ? ~sel_write_out_pool_stride_2 : sel_write_out_pool_stride_2 ;

                    load_input                  <= (count_compute_2 == 0) ? 1 : 0                                                                          ;
                    load_wgt                    <= 0                                                                                                       ;
                    ifm_demux                   <= (count_compute_2 == num_cycle_compute) ? ~ifm_demux : ifm_demux                                         ;
                    ifm_mux                     <= (count_compute_2 == num_cycle_compute) ? ~ifm_mux   : ifm_mux                                           ;

                    wgt_rd_clr                  <= (count_compute_2 < num_cycle_load + SYSTOLIC_SIZE - 1) ? 0 : 1                                          ;
                    wgt_wr_clr                  <= 1                                                                                                       ;
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        wgt_rd_en[i]            <= (count_compute_2 >= i && count_compute_2 < num_cycle_load + i) ? 1 : 0                                  ;
                    end  
                    wgt_wr_en                   <= 0                                                                                                       ;   

                    ifm_rd_clr_1                <= (ifm_demux == 1) ? ((count_compute_2 < num_cycle_load + SYSTOLIC_SIZE - 1) ? 0 : 1) : 1                 ;
                    ifm_wr_clr_1                <= (ifm_demux == 0) ? ((count_compute_2 >= 2 && count_compute_2 <= num_cycle_load + 1) ? 0 : 1) : 1        ;
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        ifm_rd_en_1[i]          <= (ifm_demux == 1) ? ((count_compute_2 >= i && count_compute_2 < num_cycle_load + i) ? 1 : 0) : 0         ;  
                    end
                    ifm_wr_en_1                 <= (ifm_demux == 0) ? ((count_compute_2 >= 2 && count_compute_2 <= num_cycle_load + 1) ? 1 : 0) : 0        ;   

                    ifm_rd_clr_2                <= (ifm_demux == 0) ? ((count_compute_2 < num_cycle_load + SYSTOLIC_SIZE - 1) ? 0 : 1) : 1                 ;
                    ifm_wr_clr_2                <= (ifm_demux == 1) ? ((count_compute_2 >= 2 && count_compute_2 <= num_cycle_load + 1) ? 0 : 1) : 1        ;
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        ifm_rd_en_2[i]          <= (ifm_demux == 0) ? ((count_compute_2 >= i && count_compute_2 < num_cycle_load + i) ? 1 : 0) : 0         ;
                    end                                                
                    ifm_wr_en_2                 <= (ifm_demux == 1) ? ((count_compute_2 >= 2 && count_compute_2 <= num_cycle_load + 1) ? 1 : 0) : 0        ;    

                    maxpool_rd_clr              <= (maxpool_stride == 1) ? ((count_compute_2 <= read_wgt_size - 2 || count_compute_2 == num_cycle_compute) && (sel_write_out_pool_stride_1 == 1) ? 0 : 1) : ((count_compute_2 <= read_wgt_size - 2 || count_compute_2 == num_cycle_compute) && (sel_write_out_pool_stride_2 == 1) ? 0 : 1) ;
                    maxpool_wr_clr              <= (count_compute_2 <= read_wgt_size - 1) ? 0 : 1                                                                                                                                                                                                                                          ;
                    maxpool_rd_en               <= (maxpool_stride == 1) ? ((count_compute_2 <= read_wgt_size - 2 || count_compute_2 == num_cycle_compute) && (sel_write_out_pool_stride_1 == 1) ? 1 : 0) : ((count_compute_2 <= read_wgt_size - 2 || count_compute_2 == num_cycle_compute) && (sel_write_out_pool_stride_2 == 1) ? 1 : 0) ;
                    maxpool_wr_en               <= (count_compute_2 <= read_wgt_size - 1) ? 1 : 0                                                                                                                                                                                                                                          ;  

                    reset_pe                    <= (count_compute_2 == num_cycle_compute) ? 1 : 0                                                                                                                                                          ;
                    write_out_pe_en             <= (count_compute_2 <= read_wgt_size - 1) ? 1 : 0                                                                                                                                                          ;
                    write_out_maxpool_en        <= (maxpool_stride == 1) ? ((count_compute_2 <= read_wgt_size - 1) && (sel_write_out_pool_stride_1 == 1) ? 1 : 0) : ((count_compute_2 <= read_wgt_size - 1) && (sel_write_out_pool_stride_2 == 1) ? 1 : 0) ;
                    done                        <= 0                                                                                                                                                                                                       ;  
                end
                COMPUTE_WRITE: begin                  
                    count_compute_2             <= 0                                                                                                       ;
                    count_tiling                <= 0                                                                                                       ;
                    count_tiling_mod_ofm_size   <= 0                                                                                                       ;
                    count_compute_1             <= count_compute_1 + 1                                                                                     ;

                    sel_write_out_pool_stride_2 <= (count_compute_1 == num_cycle_compute - 1) ? ~sel_write_out_pool_stride_2 : sel_write_out_pool_stride_2 ;

                    load_input                  <= 0                                                                                                       ;
                    load_wgt                    <= 0                                                                                                       ;
                    ifm_demux                   <= (count_compute_1 == num_cycle_compute) ? ~ifm_demux : ifm_demux                                         ;
                    ifm_mux                     <= (count_compute_1 == num_cycle_compute) ? ~ifm_mux   : ifm_mux                                           ;

                    wgt_rd_clr                  <= (count_compute_1 < num_cycle_load + SYSTOLIC_SIZE - 1) ? 0 : 1                                          ;
                    wgt_wr_clr                  <= 1                                                                                                       ;
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        wgt_rd_en[i]            <= (count_compute_1 >= i && count_compute_1 < num_cycle_load + i) ? 1 : 0                                  ;
                    end  
                    wgt_wr_en                   <= 0                                                                                                       ;   

                    ifm_rd_clr_1                <= (ifm_demux == 1) ? ((count_compute_1 < num_cycle_load + SYSTOLIC_SIZE - 1) ? 0 : 1) : 1                 ;
                    ifm_wr_clr_1                <= (ifm_demux == 0) ? ((count_compute_1 >= 2 && count_compute_1 <= num_cycle_load + 1) ? 0 : 1) : 1        ;
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        ifm_rd_en_1[i]          <= (ifm_demux == 1) ? ((count_compute_1 >= i && count_compute_1 < num_cycle_load + i) ? 1 : 0) : 0         ;  
                    end
                    ifm_wr_en_1                 <= (ifm_demux == 0) ? ((count_compute_1 >= 2 && count_compute_1 <= num_cycle_load + 1) ? 1 : 0) : 0        ;   

                    ifm_rd_clr_2                <= (ifm_demux == 0) ? ((count_compute_1 < num_cycle_load + SYSTOLIC_SIZE - 1) ? 0 : 1) : 1                 ;
                    ifm_wr_clr_2                <= (ifm_demux == 1) ? ((count_compute_1 >= 2 && count_compute_1 <= num_cycle_load + 1) ? 0 : 1) : 1        ;
                    for (i = 0; i < SYSTOLIC_SIZE; i = i + 1) begin
                        ifm_rd_en_2[i]          <= (ifm_demux == 0) ? ((count_compute_1 >= i && count_compute_1 < num_cycle_load + i) ? 1 : 0) : 0         ;
                    end                                                
                    ifm_wr_en_2                 <= (ifm_demux == 1) ? ((count_compute_1 >= 2 && count_compute_1 <= num_cycle_load + 1) ? 1 : 0) : 0        ;    

                    maxpool_rd_clr              <= (maxpool_stride == 1) ? ((count_compute_1 <= read_wgt_size - 2 || count_compute_1 == num_cycle_compute) ? 0 : 1) : ((count_compute_1 <= read_wgt_size - 2 || count_compute_1 == num_cycle_compute) && (sel_write_out_pool_stride_2 == 1) ? 0 : 1) ;
                    maxpool_wr_clr              <= (count_compute_1 <= read_wgt_size - 1) ? 0 : 1                                                                                                                                                                                                    ;
                    maxpool_rd_en               <= (maxpool_stride == 1) ? ((count_compute_1 <= read_wgt_size - 2 || count_compute_1 == num_cycle_compute) ? 1 : 0) : ((count_compute_1 <= read_wgt_size - 2 || count_compute_1 == num_cycle_compute) && (sel_write_out_pool_stride_2 == 1) ? 1 : 0) ;
                    maxpool_wr_en               <= (count_compute_1 <= read_wgt_size - 1) ? 1 : 0                                                                                                                                                                                                    ;  

                    reset_pe                    <= (count_compute_1 == num_cycle_compute) ? 1 : 0                                                                                                                    ;
                    write_out_pe_en             <= (count_compute_1 <= read_wgt_size - 1) ? 1 : 0                                                                                                                    ;
                    write_out_maxpool_en        <= (maxpool_stride == 1) ? ((count_compute_1 <= read_wgt_size - 1) ? 1 : 0) : ((count_compute_1 <= read_wgt_size - 1) && (sel_write_out_pool_stride_2 == 1) ? 1 : 0) ;
                    done                        <= 0                                                                                                                                                                 ;  
                end
                WRITE: begin
                    count_compute_1             <= 0                     ;
                    count_write                 <= count_write + 1       ;

                    load_input                  <= 0                     ;
                    load_wgt                    <= 0                     ;
                    ifm_demux                   <= 0                     ;
                    ifm_mux                     <= 1                     ;
 
                    wgt_rd_clr                  <= 1                     ;
                    wgt_wr_clr                  <= 1                     ;
                    wgt_rd_en                   <= {SYSTOLIC_SIZE{1'b0}} ;
                    wgt_wr_en                   <= 0                     ;

                    ifm_rd_clr_1                <= 1                     ;
                    ifm_wr_clr_1                <= 1                     ;
                    ifm_rd_en_1                 <= {SYSTOLIC_SIZE{1'b0}} ;
                    ifm_wr_en_1                 <= 0                     ;
                    
                    ifm_rd_clr_2                <= 1                     ;
                    ifm_wr_clr_2                <= 1                     ;
                    ifm_rd_en_2                 <= {SYSTOLIC_SIZE{1'b0}} ;
                    ifm_wr_en_2                 <= 0                     ;  

                    maxpool_rd_clr              <= (maxpool_stride == 1) ? ((count_write <= read_wgt_size - 2 || count_write == SYSTOLIC_SIZE) ? 0 : 1) : ((count_write <= read_wgt_size - 2) && (sel_write_out_pool_stride_2 == 1) ? 0 : 1) ;
                    maxpool_wr_clr              <= (count_write <= read_wgt_size - 1) ? 0 : 1                                                                                                                                                ;
                    maxpool_rd_en               <= (maxpool_stride == 1) ? ((count_write <= read_wgt_size - 2 || count_write == SYSTOLIC_SIZE) ? 1 : 0) : ((count_write <= read_wgt_size - 2) && (sel_write_out_pool_stride_2 == 1) ? 1 : 0) ;
                    maxpool_wr_en               <= (count_write <= read_wgt_size - 1) ? 1 : 0                                                                                                                                                ;  

                    reset_pe                    <= 1                                                                                                                                                         ;
                    write_out_pe_en             <= (count_write <= read_wgt_size - 1) ? 1 : 0                                                                                                                ;
                    write_out_maxpool_en        <= (maxpool_stride == 1) ? ((count_write <= read_wgt_size - 1) ? 1 : 0) : ((count_write <= read_wgt_size - 1) && (sel_write_out_pool_stride_2 == 1) ? 1 : 0) ;
                    if (maxpool_stride != 1 && count_write == SYSTOLIC_SIZE && count_filter == num_load_filter) done <= 1 ;
                end
                LAST_POOL: begin
                    count_write                 <= 0                                                 ;
                    count_pooling               <= count_pooling + 1                                 ;

                    load_input                  <= 0                                                 ;
                    load_wgt                    <= 0                                                 ;
                    ifm_demux                   <= 0                                                 ;
                    ifm_mux                     <= 1                                                 ;
                    
                    wgt_rd_clr                  <= 1                                                 ;
                    wgt_wr_clr                  <= 1                                                 ;
                    wgt_rd_en                   <= {SYSTOLIC_SIZE{1'b0}}                             ;
                    wgt_wr_en                   <= 0                                                 ;

                    ifm_rd_clr_1                <= 1                                                 ;
                    ifm_wr_clr_1                <= 1                                                 ;
                    ifm_rd_en_1                 <= {SYSTOLIC_SIZE{1'b0}}                             ;
                    ifm_wr_en_1                 <= 0                                                 ;
                    
                    ifm_rd_clr_2                <= 1                                                 ;
                    ifm_wr_clr_2                <= 1                                                 ;
                    ifm_rd_en_2                 <= {SYSTOLIC_SIZE{1'b0}}                             ;
                    ifm_wr_en_2                 <= 0                                                 ;  

                    maxpool_rd_clr              <= (count_pooling <= read_wgt_size - 2) ? 0 : 1      ;
                    maxpool_wr_clr              <= 1                                                 ;
                    maxpool_rd_en               <= (count_pooling <= read_wgt_size - 2) ? 1 : 0      ;
                    maxpool_wr_en               <= 0                                                 ;  

                    reset_pe                    <= 1                                                 ;
                    write_out_pe_en             <= 0                                                 ;
                    write_out_maxpool_en        <= (count_pooling <= read_wgt_size - 1) ? 1 : 0      ;
                    if (count_pooling == SYSTOLIC_SIZE && count_filter == num_load_filter) done <= 1 ;
                end
            endcase
        end
    end

endmodule
