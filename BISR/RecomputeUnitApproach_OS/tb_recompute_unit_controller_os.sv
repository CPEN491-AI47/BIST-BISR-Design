
`include "./header.vh"

module tb_recompute_unit_controller_os();
    //inputs
    logic clk = 1'b0;
    logic rst = 1'b0;

    logic [`COLS-1:0] ru_en;
    logic [`COLS * `WORD_SIZE - 1 : 0] ru_top_inputs;
    logic [`COLS * `WORD_SIZE - 1 : 0] ru_left_inputs;

    logic [`COLS-1:0] ru_set_stationary;
    logic [`COLS-1:0] ru_fsm_out_sel_in;
    logic [`COLS-1:0] ru_stat_bit_in;
    logic [($clog2(`COLS)*`COLS)-1:0] ru_col_mapping;
    logic [($clog2(`COLS)*`COLS)-1:0] ru_row_mapping;

    logic [(`ROWS*`COLS) - 1 :0] STW_result_mat = 16'b1111_1111_1111_1111;
    logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] top_matrix;
logic[5:0] test = $clog2(4);
    `ifdef OS_WORKFLOW
        logic [`ROWS * `COLS * `WORD_SIZE - 1 : 0] left_matrix; 
    `else
        logic [`WORD_SIZE:0] left_matrix[`ROWS][`COLS];
    `endif

    logic [`WORD_SIZE - 1:0] output_matrix[`ROWS][`COLS];

    `ifdef ENABLE_STW
        //STW inputs
        logic STW_test_load_en;
        logic [`WORD_SIZE-1:0] STW_mult_op1;
        logic [`WORD_SIZE-1:0] STW_mult_op2;
        logic [`WORD_SIZE-1:0] STW_add_op;
        logic [`WORD_SIZE-1:0] STW_expected;
        logic STW_start;
        //outputs
        logic STW_complete;
        //STW_result_mat; //[`COLS-1:0];
    `endif

    logic err;

    `ifdef ENABLE_FI
        logic [(`ROWS * `COLS * 2) - 1:0] fault_inject_bus = 0;
        logic [`ROWS-1:0] fi_row;   //row to inject fault
        logic [`COLS-1:0] fi_col;   //col to inject fault
    `endif

    integer n_cycle;
    logic start_inputting = 1'b0;

    always #5 clk = ~clk;

    task Matrix_Initilization;
        if (`ROWS == 2)begin
            top_matrix = {`WORD_SIZE'd4, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};
            `ifdef OS_WORKFLOW
                left_matrix = {`WORD_SIZE'd2, `WORD_SIZE'd1,`WORD_SIZE'd6, `WORD_SIZE'd7};
            `else
                 left_matrix = '{'{`WORD_SIZE'd2, `WORD_SIZE'd1},
                                '{`WORD_SIZE'd6, `WORD_SIZE'd7}};
            `endif 
        end 
        else if (`ROWS == 3)begin 
            `ifdef OS_WORKFLOW
                left_matrix = {`WORD_SIZE'd9, `WORD_SIZE'd8, `WORD_SIZE'd7, `WORD_SIZE'd6, `WORD_SIZE'd5, `WORD_SIZE'd4, `WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1};
            `else
                 left_matrix = '{'{`WORD_SIZE'd9, `WORD_SIZE'd8, `WORD_SIZE'd7},
                                 '{`WORD_SIZE'd6, `WORD_SIZE'd5, `WORD_SIZE'd4},
                                 '{`WORD_SIZE'd3, `WORD_SIZE'd2, `WORD_SIZE'd1}};
            `endif 
            top_matrix = {`WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6, `WORD_SIZE'd3,`WORD_SIZE'd12, `WORD_SIZE'd5, `WORD_SIZE'd1, `WORD_SIZE'd4,`WORD_SIZE'd9};
        end 
        else begin 
            //4x4 example 
            top_matrix = {`WORD_SIZE'd7, `WORD_SIZE'd2, `WORD_SIZE'd3, `WORD_SIZE'd5,
                        `WORD_SIZE'd1, `WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6,
                        `WORD_SIZE'd2,`WORD_SIZE'd3, `WORD_SIZE'd12, `WORD_SIZE'd5, 
                        `WORD_SIZE'd5,`WORD_SIZE'd1, `WORD_SIZE'd4, `WORD_SIZE'd9};
            `ifdef OS_WORKFLOW
                left_matrix = {`WORD_SIZE'd7, `WORD_SIZE'd2, `WORD_SIZE'd3, `WORD_SIZE'd5,
                               `WORD_SIZE'd4, `WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6,
                               `WORD_SIZE'd2,`WORD_SIZE'd3, `WORD_SIZE'd12, `WORD_SIZE'd5,
                               `WORD_SIZE'd5,`WORD_SIZE'd1, `WORD_SIZE'd4, `WORD_SIZE'd9}; 
            `else
                 left_matrix = '{'{`WORD_SIZE'd7, `WORD_SIZE'd2, `WORD_SIZE'd3, `WORD_SIZE'd5},
                                 '{`WORD_SIZE'd4, `WORD_SIZE'd7, `WORD_SIZE'd8, `WORD_SIZE'd6},
                                 '{`WORD_SIZE'd2,`WORD_SIZE'd3, `WORD_SIZE'd12, `WORD_SIZE'd5},
                                '{`WORD_SIZE'd5,`WORD_SIZE'd1, `WORD_SIZE'd4, `WORD_SIZE'd9}}; 
            `endif 
        end 
    endtask
    //Inject Faults Randomly/Manually in MAC unit 
    task fault_injection;
        `ifdef ENABLE_FI
            `ifdef ENABLE_RANDOM
                //Inject fault randomly
                $urandom(`SEED);
                fault_inject_bus = $urandom_range({(`ROWS * `COLS * 2){1'b1}},{(`ROWS * `COLS * 2){1'b0}});
                for(integer n = 0; n < (`ROWS * `COLS * 2); n = n+2)begin
                    if(fault_inject_bus[n] == 1'b1)
                        $display("Injected stuck-at %d fault at col %0d, row %0d",fault_inject_bus[n+1], n / ( 2 * `COLS), ((n / 2) % `ROWS));
                end 
            `else
                //Inject faulty MAC manually at array[0,1]
                fi_row = 0;
                fi_col = 1;
                fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b01;
                $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
            `endif
        `endif
    endtask 
    
    recompute_unit_controller_os #(`ROWS, `COLS, `WORD_SIZE, `ROWS) rcm_os(   //Number of redundant units
    
        .clk(clk),
        .rst(rst),
        //Input matrices
        .top_matrix(top_matrix),
        .left_matrix(left_matrix),
        .STW_result_mat(STW_result_mat),
        //input [WORD_SIZE-1:0] systolic_output_reg [COLS-1:0];

        //outputs
        .ru_en(ru_en),
        .ru_top_inputs(ru_top_inputs),
        .ru_left_inputs(ru_left_inputs),

        .ru_set_stationary(ru_set_stationary),
        .ru_fsm_out_sel_in(ru_fsm_out_sel_in),
        .ru_stat_bit_in(ru_stat_bit_in),

        .ru_col_mapping(ru_col_mapping),
        .ru_row_mapping(ru_row_mapping)
);  


    integer r, c, curr_output;
    initial begin
        Matrix_Initilization();
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;

        @(negedge clk);
        STW_result_mat = 16'b1111_1111_1011_1101;

        `ifdef ENABLE_FI
            fi_row = 0;
            fi_col = 1;
            fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b01;
            $display("Injected fault at col %0d, row %0d", fi_col, fi_row);
            fi_row = 2;
            fi_col = 3;
            fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b11;
            $display("Injected fault at col %0d, row %0d", fi_col, fi_row);

            @(negedge clk);
        `endif
        
        $display("Tested fault injection matrix");
        //$display("Top (weight) Matrix:");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", STW_result_mat[(r*`COLS+c)]);
            end
            $write("\n");
        end

        $display("Top (weight) Matrix:");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", top_matrix[(r*`COLS+c)*`WORD_SIZE +: `WORD_SIZE]);
            end
            $write("\n");
        end

        $display("Left (input) Matrix:");
        for(integer r = 0; r < `ROWS; r++) begin
           for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", left_matrix[(r*`COLS+c)*`WORD_SIZE +: `WORD_SIZE]);
            end
            $write("\n");
        end

        wait(ru_en != 0);
        $display("ru_en:");
        for(integer c = 0; c < `COLS; c++) begin
                $write("%d ", left_matrix[c]);
        end
        $write("\n");
        
        #20;
        //introducing new faulty PE
        STW_result_mat = 16'b1111_1011_1111_1101;
        #500;

        $stop;
    end
endmodule