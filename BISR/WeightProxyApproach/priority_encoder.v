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
    // reg break_loop = 0;

    // always @(*) begin
        // encoded_out = 'b0;
//    genvar i;
//    generate
//         for(i = 0; i < INPUT_WIDTH; i=i+1) begin    //Priority LSB
//             always @(*) begin
//                 if((data_in[i] == ENCODED_VAL)) begin   //Find idx of 1st ZERO
//                     encoded_out = i;
//                     // break_loop = 1'b1;
//                 end
//                 // else
//                 //     encoded_out = 'b0;
                
//             end
//         end
//     // end

//    endgenerate
    reg [NUM_ENCODED_BITS:0] i;
    always @(*) begin
        encoded_out = 'bx;
        for(i = 0; i < INPUT_WIDTH; i=i+1) begin
            if((data_in[i] == ENCODED_VAL)) begin   //Find idx of 1st ZERO
                encoded_out = i;
                // break_loop = 1'b1;
            end
        end
   end
endmodule