`ifndef __EX_MEM_REG_SV
`define __EX_MEM_REG_SV

// Pipeline register between EX and MEM.
module ex_mem_reg import common::*;(
    input  logic  clk,
    input  logic  reset,
    input  logic  flush_i,
    input  logic  stall_i,
    input  logic  in_valid_i,
    input  word_t in_pc_i,
    input  u32    in_instr_i,
    input  u5     in_rd_i,
    input  logic  in_wen_i,
    input  logic  in_trap_i,
    input  logic  in_is_load_i,
    input  logic  in_is_store_i,
    input  logic  in_mem_unsigned_i,
    input  msize_t in_mem_size_i,
    input  word_t in_store_data_i,
    input  word_t in_result_i,
    input  logic  in_is_csr_i,
    input  logic  in_csr_wen_i,
    input  u12    in_csr_addr_i,
    input  word_t in_csr_wdata_i,
    input  logic  in_is_ecall_i,
    input  logic  in_is_mret_i,
    input  logic  in_is_sret_i,
    input  logic  in_exc_valid_i,
    input  word_t in_exc_cause_i,
    input  word_t in_exc_tval_i,
    output logic  out_valid_o,
    output word_t out_pc_o,
    output u32    out_instr_o,
    output u5     out_rd_o,
    output logic  out_wen_o,
    output logic  out_trap_o,
    output logic  out_is_load_o,
    output logic  out_is_store_o,
    output logic  out_mem_unsigned_o,
    output msize_t out_mem_size_o,
    output word_t out_store_data_o,
    output word_t out_result_o,
    output logic  out_is_csr_o,
    output logic  out_csr_wen_o,
    output u12    out_csr_addr_o,
    output word_t out_csr_wdata_o,
    output logic  out_is_ecall_o,
    output logic  out_is_mret_o,
    output logic  out_is_sret_o,
    output logic  out_exc_valid_o,
    output word_t out_exc_cause_o,
    output word_t out_exc_tval_o
);
    always_ff @(posedge clk) begin
        if (reset || flush_i) begin
            out_valid_o  <= 1'b0;
            out_pc_o     <= '0;
            out_instr_o  <= '0;
            out_rd_o     <= '0;
            out_wen_o    <= 1'b0;
            out_trap_o   <= 1'b0;
            out_is_load_o <= 1'b0;
            out_is_store_o <= 1'b0;
            out_mem_unsigned_o <= 1'b0;
            out_mem_size_o <= MSIZE8;
            out_store_data_o <= '0;
            out_result_o <= '0;
            out_is_csr_o    <= 1'b0;
            out_csr_wen_o   <= 1'b0;
            out_csr_addr_o  <= '0;
            out_csr_wdata_o <= '0;
            out_is_ecall_o  <= 1'b0;
            out_is_mret_o   <= 1'b0;
            out_is_sret_o   <= 1'b0;
            out_exc_valid_o <= 1'b0;
            out_exc_cause_o <= '0;
            out_exc_tval_o  <= '0;
        end else if (stall_i) begin
            out_valid_o  <= out_valid_o;
            out_pc_o     <= out_pc_o;
            out_instr_o  <= out_instr_o;
            out_rd_o     <= out_rd_o;
            out_wen_o    <= out_wen_o;
            out_trap_o   <= out_trap_o;
            out_is_load_o <= out_is_load_o;
            out_is_store_o <= out_is_store_o;
            out_mem_unsigned_o <= out_mem_unsigned_o;
            out_mem_size_o <= out_mem_size_o;
            out_store_data_o <= out_store_data_o;
            out_result_o <= out_result_o;
            out_is_csr_o    <= out_is_csr_o;
            out_csr_wen_o   <= out_csr_wen_o;
            out_csr_addr_o  <= out_csr_addr_o;
            out_csr_wdata_o <= out_csr_wdata_o;
            out_is_ecall_o  <= out_is_ecall_o;
            out_is_mret_o   <= out_is_mret_o;
            out_is_sret_o   <= out_is_sret_o;
            out_exc_valid_o <= out_exc_valid_o;
            out_exc_cause_o <= out_exc_cause_o;
            out_exc_tval_o  <= out_exc_tval_o;
        end else begin
            out_valid_o  <= in_valid_i;
            out_pc_o     <= in_pc_i;
            out_instr_o  <= in_instr_i;
            out_rd_o     <= in_rd_i;
            out_wen_o    <= in_wen_i;
            out_trap_o   <= in_trap_i;
            out_is_load_o <= in_is_load_i;
            out_is_store_o <= in_is_store_i;
            out_mem_unsigned_o <= in_mem_unsigned_i;
            out_mem_size_o <= in_mem_size_i;
            out_store_data_o <= in_store_data_i;
            out_result_o <= in_result_i;
            out_is_csr_o    <= in_is_csr_i;
            out_csr_wen_o   <= in_csr_wen_i;
            out_csr_addr_o  <= in_csr_addr_i;
            out_csr_wdata_o <= in_csr_wdata_i;
            out_is_ecall_o  <= in_is_ecall_i;
            out_is_mret_o   <= in_is_mret_i;
            out_is_sret_o   <= in_is_sret_i;
            out_exc_valid_o <= in_exc_valid_i;
            out_exc_cause_o <= in_exc_cause_i;
            out_exc_tval_o  <= in_exc_tval_i;
        end
    end
endmodule

`endif
