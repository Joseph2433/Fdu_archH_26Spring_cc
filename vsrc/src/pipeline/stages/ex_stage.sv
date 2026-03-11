`ifndef __EX_STAGE_SV
`define __EX_STAGE_SV

// EX stage: integer ALU for the Lab1 arithmetic/logic subset.
module ex_stage import common::*;(
    input  word_t op1_i,
    input  word_t op2_i,
    input  word_t imm_i,
    input  logic  use_imm_i,
    input  logic  is_word_i,
    input  u3     alu_op_i,
    output word_t result_o
);
    word_t rhs;
    word_t full_res;
    u32    low32;

    // Immediate instructions reuse the same ALU datapath as register-register ops.
    assign rhs = use_imm_i ? imm_i : op2_i;

    always_comb begin
        low32    = '0;
        result_o = '0;

        unique case (alu_op_i)
            3'b000: full_res = op1_i + rhs; // ADD/ADDI/ADDW/ADDIW
            3'b001: full_res = op1_i - rhs; // SUB/SUBW
            3'b010: full_res = op1_i & rhs; // AND/ANDI
            3'b011: full_res = op1_i | rhs; // OR/ORI
            3'b100: full_res = op1_i ^ rhs; // XOR/XORI
            default: full_res = '0;
        endcase

        if (is_word_i) begin
			// RV64 W-type instructions write back sign-extended 32-bit results.
            low32    = full_res[31:0];
            result_o = {{32{low32[31]}}, low32};
        end else begin
            result_o = full_res;
        end
    end
endmodule

`endif
