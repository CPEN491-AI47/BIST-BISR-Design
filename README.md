The separate components of the design: built-in self test, diagnosis, and repair are organized in different folders as they were built-upon throughout the developmental milestones. The final designs for the different dataflows are found in the BISR folder, this design uses:
   - StopTheWorld Self-Test and Self-Diagnosis
   - Proxy Self-Repair for Input-Stationary/Weight-Stationary dataflows
   - FSA Self-Repair for Output-Stationary dataflow
   - With modules from FaultInjection for testing

Overall design repo structure:
- BISR: Built-in Self-Repair Mechanisms built upon existing BIST from StopTheWorld
   - RecomputeUnitApproach_OS: RTL for FSA Self-Repair Approach intended for Output-Stationary Dataflow
        - Top_BISR_STW_systolic.v: Top-level module
        - header.vh: Header file with values for matrix size, word size, enabling BISR/fault injection
   - WeightProxyApproach: RTL, control FSMs, and testbenches for Proxy Self-Repair Approach intended for Weight-Stationary and Input-Stationary dataflows

     Key Modules:
        - bisr_systolic_top.sv: Top level module instantiating Systolic Array with Proxy BISR and matrix multiplication FSMs
        - systolic_stw_proxy.sv: Systolic array RTL with logic required for Proxy BISR (proxy controller and data re-routing) and StopTheWorld BIST
        - proxy_controller.sv: Proxy Controller module
        - absolutevalue32b_comp.sv: Comparator used for selecting proxy
        - sp_bram.sv: Reference block ram module used for storing input/output matrices, currently holds sample inputs for proxy_stw_matmul_tb (sourced from https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Initializing-Block-RAM-Verilog)
        - systolic_matmul_fsm.sv: FSM for executing matrix multiplication with inputs in sp_bram
        - matmul_output_control.sv: FSM for writing output matrix from systolic_matmul_fsm to sp_bram
        - proxy_stw_matmul_tb.sv: Main testbench for Proxy BISR
        - header_ws.vh: Header file with values for matrix size, word size, enabling BISR/fault injection


The other components can also be found individually in separate folders:
- FaultInjection
   - Version of MAC & systolic modified for fault injection: Modules for other approaches build on these
- m3_stw_demo
   - Working design & tb files used for STW Milestone 3 demo
- ReferenceRTL
   - Base modules from Scale-Sim. Source: https://github.com/scalesim-project/scale-sim-v2/tree/main/code-examples/systolic-array-rtl
- ControlPath
   - systolic_matmul_fsm(WS)/systolic_matmul_fsm_OS: Matrix multiplication FSMs for WS/OS
   - matmul_output_control: FSM for reading outputs into registers for checking
   - workflow_control: Top-level schematic instantiated matmul_output_control & systolic_matmul_fsm_OS/WS. Workflow selection(WS/OS) be chosen in header file
   - Corresponding tbs
- TMR
- StopTheWorld
   - Design files & tbs
- FSMApproach
   - Files for FSM Design Approach

