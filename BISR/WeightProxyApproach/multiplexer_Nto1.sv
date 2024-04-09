module multiplexer_Nto1
#(
    parameter NUM_INPUTS = 4,
    parameter WORD_SIZE = 16
) (
    input_options_bus,
    out_sel,
    mux_out
);
    localparam NUM_BITS_OUT_SEL = $clog2(NUM_INPUTS);
    
    input logic signed [(NUM_INPUTS*WORD_SIZE)-1:0] input_options_bus;
    input [NUM_BITS_OUT_SEL-1 : 0] out_sel;   //onehot select
    output logic signed [WORD_SIZE-1 : 0] mux_out;

    // genvar i;
    // generate
    //     for(i = 0; i < NUM_INPUTS; i=i+1) begin
    //         always @(*) begin
    //             if(out_sel[i])
    //                 mux_out = input_options_bus[(i*WORD_SIZE) +: WORD_SIZE];
    //         end
    //     end
    // endgenerate
    assign mux_out = input_options_bus[(out_sel*WORD_SIZE) +: WORD_SIZE];

endmodule