module priority_encoder
#(
    parameter INPUT_WIDTH = 4,
    parameter ENCODED_VAL = 0   //Encoder will return 1st idx n of data_in where n = ENCODED_VAL. Decides whether we are looking for 1st bit = 0 or first bit = 1
) (
    rst,
    data_in,
    encoded_out
);
    localparam NUM_ENCODED_BITS = $clog2(INPUT_WIDTH);

    input rst;
    input [INPUT_WIDTH-1:0] data_in;
    output reg [NUM_ENCODED_BITS-1:0] encoded_out;
    reg break = 0;

    // integer i;
    // always @(*) begin
    //     if(rst) begin
    //         break = 1'b0;
    //         encoded_out = 'x;
    //     end
    //     else begin
    //         for(i = 0; i < INPUT_WIDTH; i=i+1) begin   //Priority LSB
    //             if((data_in[i] == ENCODED_VAL) && !break) begin   //Find idx of 1st ZERO
    //                 encoded_out = i;
    //                 break = 1'b1;
    //             end
    //             else
    //                 break = 1'b0;
    //         end
    //     end
    // end

    genvar i;
    generate
        for(i = 0; i < INPUT_WIDTH; i=i+1) begin   //Priority LSB
            always @(*) begin
                if((data_in[i] == ENCODED_VAL)) begin   //Find idx of 1st ZERO
                    encoded_out = i;
                    // break = 1'b1;
                end
                // break = 1'b0;
            end
        end

    endgenerate
endmodule