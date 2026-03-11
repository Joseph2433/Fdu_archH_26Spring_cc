`ifndef __DECODER_SV
`define __DECODER_SV

// Decode the Lab1 instruction subset into pipeline control signals.
module decoder import common::*;(
	input  u32    instr_i,
	output u5     rs1_o,
	output u5     rs2_o,
	output u5     rd_o,
	output logic  wen_o,
	output logic  trap_o,
	output logic  use_imm_o,
	output logic  is_word_o,
	output u3     alu_op_o,
	output word_t imm_o,
	output logic  rs1_used_o,
	output logic  rs2_used_o,
	output logic  funct7_sub_o
);
	u7 opcode;
	u3 funct3;
	u7 funct7;
	word_t imm_i;

	// Common instruction fields used by all supported formats.
	assign opcode    = instr_i[6:0];
	assign funct3    = instr_i[14:12];
	assign funct7    = instr_i[31:25];
	assign rs1_o     = instr_i[19:15];
	assign rs2_o     = instr_i[24:20];
	assign rd_o      = instr_i[11:7];
	assign imm_i     = {{52{instr_i[31]}}, instr_i[31:20]};
	assign imm_o     = imm_i;
	assign funct7_sub_o = funct7[5];

	always_comb begin
		// Default to NOP-like control so unsupported encodings do not write state.
		wen_o       = 1'b0;
		trap_o      = 1'b0;
		use_imm_o   = 1'b0;
		is_word_o   = 1'b0;
		alu_op_o    = 3'b000;
		rs1_used_o  = 1'b0;
		rs2_used_o  = 1'b0;

		case (opcode)
			// 0010011: OP-IMM -> addi/xori/ori/andi
			7'b0010011: begin
				wen_o      = 1'b1;
				use_imm_o  = 1'b1;
				rs1_used_o = 1'b1;
				unique case (funct3)
					3'b000: alu_op_o = 3'b000; // addi
					3'b100: alu_op_o = 3'b100; // xori
					3'b110: alu_op_o = 3'b011; // ori
					3'b111: alu_op_o = 3'b010; // andi
					default: begin
						wen_o = 1'b0;
					end
				endcase
			end
			// 0110011: OP -> add/sub/xor/or/and
			7'b0110011: begin
				wen_o      = 1'b1;
				rs1_used_o = 1'b1;
				rs2_used_o = 1'b1;
				unique case (funct3)
					3'b000: alu_op_o = funct7[5] ? 3'b001 : 3'b000; // sub/add
					3'b100: alu_op_o = 3'b100; // xor
					3'b110: alu_op_o = 3'b011; // or
					3'b111: alu_op_o = 3'b010; // and
					default: begin
						wen_o = 1'b0;
					end
				endcase
			end
			// 0011011: OP-IMM-32 -> addiw
			7'b0011011: begin
				wen_o      = 1'b1;
				use_imm_o  = 1'b1;
				is_word_o  = 1'b1;
				rs1_used_o = 1'b1;
				if (funct3 == 3'b000) begin
					alu_op_o = 3'b000; // addiw
				end else begin
					wen_o = 1'b0;
				end
			end
			// 0111011: OP-32 -> addw/subw
			7'b0111011: begin
				wen_o      = 1'b1;
				is_word_o  = 1'b1;
				rs1_used_o = 1'b1;
				rs2_used_o = 1'b1;
				if (funct3 == 3'b000) begin
					alu_op_o = funct7[5] ? 3'b001 : 3'b000; // subw/addw
				end else begin
					wen_o = 1'b0;
				end
			end
			// 1101011: custom trap instruction (0x0005006b in lab test image)
			7'b1101011: begin
				trap_o = 1'b1;
			end
			default: begin
				wen_o = 1'b0;
			end
		endcase
	end
endmodule

`endif
