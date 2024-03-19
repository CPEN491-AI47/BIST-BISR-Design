Overall design repo structure:
- TMR
- StopTheWorld
   - Design files & tbs
- FSMApproach
   - Files for FSM Design Approach
- ControlPath
   - systolic_matmul_fsm(WS)/systolic_matmul_fsm_OS: Matrix multiplication FSMs for WS/OS
   - matmul_output_control: FSM for reading outputs into registers for checking
   - workflow_control: Top-level schematic instantiated matmul_output_control & systolic_matmul_fsm_OS/WS. Workflow selection(WS/OS) be chosen in header file
   - Corresponding tbs
- FaultInjection
   - Version of MAC & systolic modified for fault injection: Modules for other approaches build on these
- m3_stw_demo
   - Working design & tb files used for STW Milestone 3 demo
- ReferenceRTL
   - Base modules from Scale-Sim. Source: https://github.com/scalesim-project/scale-sim-v2/tree/main/code-examples/systolic-array-rtl

