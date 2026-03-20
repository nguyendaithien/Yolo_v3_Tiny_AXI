module mult_fixpoint #(
    parameter DATA_WIDTH = 16
) (
    input  [DATA_WIDTH   - 1 : 0] a ,
    input  [DATA_WIDTH   - 1 : 0] b ,
    output [DATA_WIDTH*2 - 1 : 0] q 
);

    wire [DATA_WIDTH - 1 : 0] multiplicand;
    wire [DATA_WIDTH - 1 : 0] multiplier;
    (* use_dsp = "yes" *) wire [DATA_WIDTH*2 - 1 : 0] product;

    assign multiplicand = (a[DATA_WIDTH - 1] == 1) ? (~a) + 1 : a;
    assign multiplier   = (b[DATA_WIDTH - 1] == 1) ? (~b) + 1 : b;

    assign product = multiplicand[DATA_WIDTH - 2 : 0] * multiplier[DATA_WIDTH - 2 : 0];
    
    assign q[DATA_WIDTH*2 - 1]     = (a != 0 && b != 0 && product != 0) ? a[DATA_WIDTH - 1] ^ b[DATA_WIDTH - 1] : 0;
    assign q[DATA_WIDTH*2 - 2 : 0] = (q[DATA_WIDTH*2 - 1] == 1) ? (~product) + 1 : product;

endmodule