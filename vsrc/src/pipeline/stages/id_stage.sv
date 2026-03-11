`ifndef __ID_STAGE_SV
`define __ID_STAGE_SV

// ID stage: decode control signals and select operands with simple bypassing.
module id_stage import common::*;(
    input  u32    instr_i,
    input  word_t rs1_val_i,
    input  word_t rs2_val_i,
    input  logic  ex_bypass_en_i,
    input  u5     ex_bypass_rd_i,
    input  word_t ex_bypass_data_i,
    input  logic  mem_bypass_en_i,
    input  u5     mem_bypass_rd_i,
    input  word_t mem_bypass_data_i,
    output u5     rs1_o,
    output u5     rs2_o,
    output u5     rd_o,
    output logic  wen_o,
    output logic  trap_o,
    output logic  use_imm_o,
    output logic  is_word_o,
    output u3     alu_op_o,
    output word_t imm_o,
    output word_t op1_o,
    output word_t op2_o
);
    logic rs1_used;
    logic rs2_used;
    logic funct7_sub;

    // Decoder translates the raw instruction into pipeline control.
    decoder u_decoder(
        .instr_i      (instr_i),
        .rs1_o        (rs1_o),
        .rs2_o        (rs2_o),
        .rd_o         (rd_o),
        .wen_o        (wen_o),
        .trap_o       (trap_o),
        .use_imm_o    (use_imm_o),
        .is_word_o    (is_word_o),
        .alu_op_o     (alu_op_o),
        .imm_o        (imm_o),
        .rs1_used_o   (rs1_used),
        .rs2_used_o   (rs2_used),
        .funct7_sub_o (funct7_sub)
    );

    always_comb begin
		// Default operands come directly from the register file.
        op1_o = rs1_val_i;
        op2_o = rs2_val_i;

		// EX/MEM has higher priority than MEM/WB because it is newer data.
        if (rs1_used && ex_bypass_en_i && (ex_bypass_rd_i == rs1_o) && (rs1_o != '0)) begin
            op1_o = ex_bypass_data_i;
        end else if (rs1_used && mem_bypass_en_i && (mem_bypass_rd_i == rs1_o) && (rs1_o != '0)) begin
            op1_o = mem_bypass_data_i;
        end

        if (rs2_used && ex_bypass_en_i && (ex_bypass_rd_i == rs2_o) && (rs2_o != '0)) begin
            op2_o = ex_bypass_data_i;
        end else if (rs2_used && mem_bypass_en_i && (mem_bypass_rd_i == rs2_o) && (rs2_o != '0)) begin
            op2_o = mem_bypass_data_i;
        end
    end

    // funct7_sub is decoded for completeness even though the ALU already gets alu_op.
    `UNUSED_OK({funct7_sub});
endmodule

`endif
