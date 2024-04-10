module absolutevalue32b_comp (
    a,
    b,
    a_lessthan_b
);
    input logic [31:0] a;
    input logic [31:0] b;
    output a_lessthan_b;
    
    logic [31:0] abs_a;
    logic [31:0] abs_b;
    always @(*) begin
        if(a[31] == 1'b1)
            abs_a = -a;
        else
            abs_a = a;
        
        if(b[31] == 1'b1)
            abs_b = -b;
        else
            abs_b = b;
    end

    assign a_lessthan_b = abs_a < abs_b;

endmodule