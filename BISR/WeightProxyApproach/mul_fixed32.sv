module mul_fixed32(input logic signed [31:0] a, input logic signed [31:0] b, output logic signed [31:0] out);
    /* takes 16.16 fixed point for both inputs, so we should right shift by 16 to truncate the result */
    logic [63:0] out_raw;
    assign out_raw = a * b;
    assign out = (out_raw[47:16]);
endmodule: mul_fixed32