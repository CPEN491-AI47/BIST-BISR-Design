`include "./header.vh"
// `include "./traditional_systolic_tmr.v"
// `include "./traditional_systolic.v"

// `define WORD_SIZE 16
// `define ROWS 2
// `define COLS 2
// `define ENABLE_FI
// `define ENABLE_TMR

module tmr_systolic_tb();
    //inputs
    logic clk = 1'b0;
    logic rst, ctl_dummy_fsm_op2_select_in, ctl_dummy_fsm_out_select_in, ctl_stat_bit_in;

    logic [`ROWS * `WORD_SIZE - 1: 0] left_in_bus;
    logic [`COLS * `WORD_SIZE - 1: 0] top_in_bus;

    logic err;

    `ifdef ENABLE_FI
        logic [`ROWS-1:0] fi_row;   //row to inject fault
        logic [`COLS-1:0] fi_col;   //col to inject fault
        logic stuck_at_1 = 0;

        `ifdef ENABLE_TMR
            logic [(`ROWS * `COLS * 6) - 1:0] fault_inject_bus = 0;
            logic [1:0] faulty_tmr_pe;   //PE inside TMR (@fi_row, fi_col) to inject fault in: Range frm 0-2
        `else
            logic [(`ROWS * `COLS * 2) - 1:0] fault_inject_bus = 0;
        `endif
    `endif

    //outputs
    logic [`ROWS * `WORD_SIZE - 1: 0] right_out_bus;
    logic [`COLS * `WORD_SIZE - 1: 0] bottom_out_bus;

    logic [`ROWS * `WORD_SIZE - 1: 0] checker_right_out_bus;
    logic [`COLS * `WORD_SIZE - 1: 0] checker_bottom_out_bus;

    reg dut_checker_comp_err[`ROWS-1:0][`COLS-1:0];   //array for recording errors found throughout simulation

    `ifdef ENABLE_TMR
        traditional_systolic_tmr #(`ROWS, `COLS, `WORD_SIZE) systolic_dut(.*);
    `else
        traditional_systolic #(`ROWS, `COLS, `WORD_SIZE) systolic_dut(.*);
    `endif
    
    traditional_systolic #(`ROWS, `COLS, `WORD_SIZE) systolic_checker(
        .clk(clk),
        .rst(rst),
        .ctl_stat_bit_in(ctl_stat_bit_in), 
        .ctl_dummy_fsm_op2_select_in(ctl_dummy_fsm_op2_select_in),
        .ctl_dummy_fsm_out_select_in(ctl_dummy_fsm_out_select_in),
        `ifdef ENABLE_FI
            .fault_inject_bus({(`ROWS * `COLS * 2){1'b0}}),
        `endif
        .left_in_bus(left_in_bus),
        .top_in_bus(top_in_bus),
        .bottom_out_bus(checker_bottom_out_bus),
        .right_out_bus(checker_right_out_bus)
    );

    always #5 clk = ~clk;

    logic sample_comparator = 0;
    logic test = 0;
    
    genvar r_comp, c_comp;   //row & col of bottom output to compare
    generate
        for(r_comp = 0; r_comp < `ROWS; r_comp = r_comp+1) begin
            for(c_comp = 0; c_comp < `COLS; c_comp = c_comp+1) begin
                initial begin
                    automatic logic [`COLS-1:0] checker_count = 0;
                    while(checker_count < (`COLS * `ROWS)) begin   //Only checking bottom_out so check once per col
                        @(posedge sample_comparator)   //Wait until signal that output has propagated to bottom (set by main inital block)
                        //Record incorrect output in row r_comp and column c_comp
                        dut_checker_comp_err[r_comp][c_comp] = (tmr_systolic_tb.systolic_dut.mac_row_genblk[r_comp].mac_col_genblk[c_comp].rc.u_mac.bottom_out !== tmr_systolic_tb.systolic_checker.mac_row_genblk[r_comp].mac_col_genblk[c_comp].rc.u_mac.bottom_out);
                        
                        // if(dut_checker_comp_err[r_comp][c_comp] == 1'b1) begin
                        //     $display("Error: Fault detected in row %0d, col %0d", r_comp, c_comp);
                        // end
                        checker_count = checker_count+1;
                    end
                end
            end
        end
    endgenerate

    //Check dut_checker_comp_err for any errors recorded throughout simulation
    task errorCheck;
        integer x, y;
        for(y = 0; y < `ROWS; y = y+1) begin
            for(x = 0; x < `COLS; x = x+1) begin
                if(dut_checker_comp_err[y][x] == 1'b1) begin
                    $display("Error: Incorrect output detected in row %0d, col %0d", y, x);
                end
            end
        end
    endtask

    integer r, c, curr_output;
    initial begin
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;

        //No control flow for traditional_systolic so I've fixed all inputs. 
        //We're just checking that fault injection is working so for now this is sufficient
        ctl_dummy_fsm_out_select_in = 1'b1;
        ctl_dummy_fsm_op2_select_in = 1'b1;
        ctl_stat_bit_in = 1'b0;
        left_in_bus = {`WORD_SIZE'd5, `WORD_SIZE'd4};
        top_in_bus = {`WORD_SIZE'd3, `WORD_SIZE'd2};
        
        $display("Settings: out_sel = %0d, op2_sel = %0d, stat_bit = %0d", ctl_dummy_fsm_out_select_in, ctl_dummy_fsm_op2_select_in, ctl_stat_bit_in);
        
        `ifdef ENABLE_FI
            fi_row = 0;
            fi_col = 1;
            stuck_at_1 = 0;
            `ifdef ENABLE_TMR
                faulty_tmr_pe = 2'd2;
                fault_inject_bus[(fi_col*`ROWS+fi_row)*6 +: 6] = {{stuck_at_1, (faulty_tmr_pe == 2'd2)}, {stuck_at_1, (faulty_tmr_pe == 2'd01)}, {stuck_at_1, (faulty_tmr_pe == 2'd0)}};
            `else
                fault_inject_bus[(fi_col*`ROWS+fi_row)*2 +: 2] = 2'b01;
            `endif
        `endif
        
        `ifdef ENABLE_FI
            //For 1st input, takes 2 cycles for result of MAC on row 0, col 0 to output
            @(negedge clk);
            @(negedge clk);
            for(curr_output = 0; curr_output < `COLS*`ROWS; curr_output = curr_output+1)
            begin
                @(negedge clk);   //New result should be output every cycle
                sample_comparator = 1;   //Signal for comparison with systolic_checker (trigger on posedge sample_comparator)
                #2;
                sample_comparator = 0;
                if(curr_output == 0) begin
                    for(r = 0; r < `ROWS; r = r+1)
                    begin
                        $display("r: %0d, left_in: %0d", r, left_in_bus[((r+1) * `WORD_SIZE) - 1 -: `WORD_SIZE]);
                        $display("right_out: %0d", right_out_bus[((r+1) * `WORD_SIZE) - 1 -: `WORD_SIZE]);
                    end
                end
                for(c = 0; c < `COLS; c = c+1)
                begin
                    $display("c: %0d, top_in: %0d", c, top_in_bus[((c+1) * `WORD_SIZE) - 1 -: `WORD_SIZE]);
                    $display("bottom_out: %0d", bottom_out_bus[((c+1) * `WORD_SIZE) - 1 -: `WORD_SIZE]);
                end
            end
            errorCheck();
        `else
            for(curr_output = 0; curr_output < `COLS; curr_output = curr_output+1)
            begin
                wait(bottom_out_bus[((curr_output+1) * `WORD_SIZE) - 1 -: `WORD_SIZE] != `WORD_SIZE'd0);   //wait until result in column curr_output has propagated to bottom_out_bus
                sample_comparator = 1;
                #2;
                sample_comparator = 0;
                @(negedge clk);
                $display(dut_checker_comp_err[0][0]);
                if(curr_output == 0) begin
                    for(r = 0; r < `ROWS; r = r+1)
                    begin
                        $display("r: %0d, left_in: %0d", r, left_in_bus[((r+1) * `WORD_SIZE) - 1 -: `WORD_SIZE]);
                        $display("right_out: %0d", right_out_bus[((r+1) * `WORD_SIZE) - 1 -: `WORD_SIZE]);
                    end
                end
                for(c = 0; c < `COLS; c = c+1)
                begin
                    $display("c: %0d, top_in: %0d", c, top_in_bus[((c+1) * `WORD_SIZE) - 1 -: `WORD_SIZE]);
                    $display("bottom_out: %0d", bottom_out_bus[((c+1) * `WORD_SIZE) - 1 -: `WORD_SIZE]);
                end
                
            end
        `endif
        #40 $stop;
    end
endmodule