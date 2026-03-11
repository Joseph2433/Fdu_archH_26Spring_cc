`ifndef __WB_STAGE_SV
`define __WB_STAGE_SV

// WB stage: convert the last pipeline result into architectural writeback/commit signals.
module wb_stage import common::*;(
    input  logic  valid_i,
    input  logic  wen_i,
    input  u5     rd_i,
    input  word_t result_i,
    input  logic  trap_i,
    output logic  rf_wen_o,
    output u5     rf_waddr_o,
    output word_t rf_wdata_o,
    output logic  commit_valid_o,
    output logic  commit_wen_o
);
	// x0 writes are suppressed before reaching the register file and Difftest write port.
    assign rf_wen_o      = valid_i && wen_i && (rd_i != '0);
    assign rf_waddr_o    = rd_i;
    assign rf_wdata_o    = result_i;
    assign commit_valid_o = valid_i;
    assign commit_wen_o   = valid_i && wen_i && (rd_i != '0);

    `UNUSED_OK({trap_i});
endmodule

`endif
