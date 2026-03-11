`ifndef __ID_EX_REG_SV
`define __ID_EX_REG_SV

// Pipeline register between ID and EX.
module id_ex_reg import common::*;(
    input  logic  clk,
    input  logic  reset,
    input  logic  flush_i,
    input  logic  in_valid_i,
    input  word_t in_pc_i,
    input  u32    in_instr_i,
    input  u5     in_rd_i,
    input  logic  in_wen_i,
    input  logic  in_trap_i,
    input  logic  in_use_imm_i,
    input  logic  in_is_word_i,
    input  u3     in_alu_op_i,
    input  word_t in_imm_i,
    input  word_t in_op1_i,
    input  word_t in_op2_i,
    output logic  out_valid_o,
    output word_t out_pc_o,
    output u32    out_instr_o,
    output u5     out_rd_o,
    output logic  out_wen_o,
    output logic  out_trap_o,
    output logic  out_use_imm_o,
    output logic  out_is_word_o,
    output u3     out_alu_op_o,
    output word_t out_imm_o,
    output word_t out_op1_o,
    output word_t out_op2_o
);
    always_ff @(posedge clk) begin
        if (reset || flush_i) begin
            out_valid_o   <= 1'b0;
            out_pc_o      <= '0;
            out_instr_o   <= '0;
            out_rd_o      <= '0;
            out_wen_o     <= 1'b0;
            out_trap_o    <= 1'b0;
            out_use_imm_o <= 1'b0;
            out_is_word_o <= 1'b0;
            out_alu_op_o  <= '0;
            out_imm_o     <= '0;
            out_op1_o     <= '0;
            out_op2_o     <= '0;
        end else begin
            out_valid_o   <= in_valid_i;
            out_pc_o      <= in_pc_i;
            out_instr_o   <= in_instr_i;
            out_rd_o      <= in_rd_i;
            out_wen_o     <= in_wen_i;
            out_trap_o    <= in_trap_i;
            out_use_imm_o <= in_use_imm_i;
            out_is_word_o <= in_is_word_i;
            out_alu_op_o  <= in_alu_op_i;
            out_imm_o     <= in_imm_i;
            out_op1_o     <= in_op1_i;
            out_op2_o     <= in_op2_i;
        end
    end
endmodule

`endif
