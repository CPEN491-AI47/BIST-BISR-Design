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
    
    input [(NUM_INPUTS*WORD_SIZE)-1:0] input_options_bus;
    input [NUM_BITS_OUT_SEL-1 : 0] out_sel;
    output [WORD_SIZE-1 : 0] mux_out;

    assign mux_out = input_options_bus[(out_sel*WORD_SIZE) +: WORD_SIZE];

endmodule