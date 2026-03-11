`ifndef __MEM_WB_REG_SV
`define __MEM_WB_REG_SV

// Pipeline register between MEM and WB.
module mem_wb_reg import common::*;(
    input  logic  clk,
    input  logic  reset,
    input  logic  flush_i,
    input  logic  in_valid_i,
    input  word_t in_pc_i,
    input  u32    in_instr_i,
    input  u5     in_rd_i,
    input  logic  in_wen_i,
    input  logic  in_trap_i,
    input  word_t in_result_i,
    output logic  out_valid_o,
    output word_t out_pc_o,
    output u32    out_instr_o,
    output u5     out_rd_o,
    output logic  out_wen_o,
    output logic  out_trap_o,
    output word_t out_result_o
);
    always_ff @(posedge clk) begin
        if (reset || flush_i) begin
            out_valid_o  <= 1'b0;
            out_pc_o     <= '0;
            out_instr_o  <= '0;
            out_rd_o     <= '0;
            out_wen_o    <= 1'b0;
            out_trap_o   <= 1'b0;
            out_result_o <= '0;
        end else begin
            out_valid_o  <= in_valid_i;
            out_pc_o     <= in_pc_i;
            out_instr_o  <= in_instr_i;
            out_rd_o     <= in_rd_i;
            out_wen_o    <= in_wen_i;
            out_trap_o   <= in_trap_i;
            out_result_o <= in_result_i;
        end
    end
endmodule

`endif
