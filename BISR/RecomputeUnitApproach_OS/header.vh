// Array & Word size initilization
    `define WORD_SIZE 16
    `define ROWS 4
    `define COLS 4
    `define NUM_RU 4
// Enable Fault-injection & Fault Randomization(and seed)
    `define ENABLE_FI
    //`define ENABLE_RANDOM
    `define SEED 1000

// Self Test enaling
  //`define ENABLE_TMR
    `define ENABLE_STW

// Control Workflow select(default as WS_WORKFLOW, by disabling OS below)
    `define OS_WORKFLOW


