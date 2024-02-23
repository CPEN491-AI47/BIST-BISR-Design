Overall design repo structure:
- TMR
- StopTheWorld
   - Design files & tbs
- ControlPath
   - Matrix multiplication FSMs for WS/OS
   - matmul_output_control: FSM for reading outputs into registers for checking
   - Corresponding tbs
- FaultInjection
   - Version of MAC & systolic modified for fault injection: Modules for other approaches build on these
- m3_stw_demo
   - Working design & tb files used for STW Milestone 3 demo
- ReferenceRTL
   - Base modules from Scale-Sim. Source: https://github.com/scalesim-project/scale-sim-v2/tree/main/code-examples/systolic-array-rtl

