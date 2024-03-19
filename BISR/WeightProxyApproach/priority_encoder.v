module priority_encoder
#(
    parameter INPUT_WIDTH = 4
) (
    rst,
    data_in,
    encoded_out
);
    localparam NUM_ENCODED_BITS = $clog2(INPUT_WIDTH);

    input rst;
    input [INPUT_WIDTH-1:0] data_in;
    output reg [NUM_ENCODED_BITS-1:0] encoded_out;
    reg break;

    integer i;
    always @(*) begin
        if(rst) begin
            break = 1'b0;
            encoded_out = 'x;
        end
        else begin
            for(i = 0; i < INPUT_WIDTH; i=i+1) begin   //Priority LSB
                if(!data_in[i] && !break) begin   //Find idx of 1st ZERO
                    encoded_out = i;
                    break = 1'b1;
                end
            end
        end
    end
endmodule