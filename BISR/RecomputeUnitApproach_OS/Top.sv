`include "./header.vh"

module Top
#(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter WORD_SIZE = 16,
    parameter NUM_RU = 4   //Number of redundant units
) (
    //Inputs to top module
    input clk,
    input rst,

    input inputs_rdy,

    input start_fsm,
    input bisr_en,
    output fsm_rdy,

    `ifdef ENABLE_STW
    output STW_complete,
    output [(ROWS * COLS) - 1 : 0]STW_result_mat,
    `endif
    
    //Addresses/Signals for read/write from Input RAM
    input logic [`MEM_PORT_WIDTH-1:0] mem_rd_data;,
    output logic [31:0] mem_addr;
    output logic mem_wr_en;
    //Addresses/Signals for read/write from Output RAM
    output logic [31:0] output_mem_addr;  // NOTE revert
    output logic output_mem_wr_en;
    output logic [`MEM_PORT_WIDTH-1:0] output_mem_wr_data;

    fi_en;
);

`ifdef ENABLE_FI
    localparam NUM_FAULTS = 1;
    // logic [(`ROWS*NUM_FAULTS)-1:0] fi_row_arr = {`ROWS'd1, `ROWS'd2, `ROWS'd3, `ROWS'd0};
    // logic [(`COLS*NUM_FAULTS)-1:0] fi_col_arr = {`COLS'd0, `COLS'd1, `COLS'd2, `COLS'd3};
    logic [(`ROWS*NUM_FAULTS)-1:0] fi_row_arr = {`ROWS'd0}; //, `ROWS'd2, `ROWS'd3, `ROWS'd0};
    logic [(`COLS*NUM_FAULTS)-1:0] fi_col_arr = {`COLS'd0}; //, `COLS'd1, `COLS'd2, `COLS'd3};

    input logic fi_en;
    // assign fault_inject_bus[1:0] = 2'b11;

    //   initial begin
        always @(posedge clk) begin
            if(rst) begin
                fi_row_arr <= {`ROWS'd0};
                fi_col_arr <= {`COLS'd0};
                fault_inject_bus <= 'b0;
            end
            else if (fi_en) begin
                for(integer f = 0; f < NUM_FAULTS; f++) begin
                    fi_row <= fi_row_arr[(f*`ROWS) +: `ROWS];
                    fi_col <= fi_col_arr[(f*`COLS) +: `COLS];
                    //   fi_row = fi_row_arr[f];
                    //   fi_col = fi_col_arr[f];
                    fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] <= 2'b11;
                    // $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
                end
            end
            else begin
                fault_inject_bus <= 'b0;
            end
        end
    //   end
  `endif
endmodule