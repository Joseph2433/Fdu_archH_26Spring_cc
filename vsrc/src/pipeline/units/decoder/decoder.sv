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
	output logic  op1_zero_o,
	output logic  op1_pc_o,
	output logic  is_word_o,
	output u5     alu_op_o,
	output word_t imm_o,
	output logic  is_load_o,
	output logic  is_store_o,
	output logic  is_branch_o,
	output logic  is_jal_o,
	output logic  is_jalr_o,
	output u3     branch_funct3_o,
	output logic  mem_unsigned_o,
	output msize_t mem_size_o,
	output logic  rs1_used_o,
	output logic  rs2_used_o,
	output logic  funct7_sub_o
);
	u7 opcode;
	u3 funct3;
	u7 funct7;
	word_t imm_i;
	word_t imm_s;
	word_t imm_b;
	word_t imm_u;
	word_t imm_j;

	localparam u5 ALU_ADD  = 5'd0;
	localparam u5 ALU_SUB  = 5'd1;
	localparam u5 ALU_AND  = 5'd2;
	localparam u5 ALU_OR   = 5'd3;
	localparam u5 ALU_XOR  = 5'd4;
	localparam u5 ALU_SLL  = 5'd5;
	localparam u5 ALU_SRL  = 5'd6;
	localparam u5 ALU_SRA  = 5'd7;
	localparam u5 ALU_SLT  = 5'd8;
	localparam u5 ALU_SLTU = 5'd9;
	localparam u5 ALU_MUL  = 5'd10;
	localparam u5 ALU_MULH = 5'd11;
	localparam u5 ALU_MULHSU = 5'd12;
	localparam u5 ALU_MULHU = 5'd13;
	localparam u5 ALU_DIV  = 5'd14;
	localparam u5 ALU_DIVU = 5'd15;
	localparam u5 ALU_REM  = 5'd16;
	localparam u5 ALU_REMU = 5'd17;

	// Common instruction fields used by all supported formats.
	assign opcode    = instr_i[6:0];
	assign funct3    = instr_i[14:12];
	assign funct7    = instr_i[31:25];
	assign rs1_o     = instr_i[19:15];
	assign rs2_o     = instr_i[24:20];
	assign rd_o      = instr_i[11:7];
	assign imm_i     = {{52{instr_i[31]}}, instr_i[31:20]};
	assign imm_s     = {{52{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
	assign imm_b     = {{51{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
	assign imm_u     = {{32{instr_i[31]}}, instr_i[31:12], 12'b0};
	assign imm_j     = {{43{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
	assign funct7_sub_o = funct7[5];

	always_comb begin
		// Default to NOP-like control so unsupported encodings do not write state.
		wen_o       = 1'b0;
		trap_o      = 1'b0;
		use_imm_o   = 1'b0;
		op1_zero_o  = 1'b0;
		op1_pc_o    = 1'b0;
		is_word_o   = 1'b0;
		alu_op_o    = ALU_ADD;
		imm_o       = imm_i;
		is_load_o   = 1'b0;
		is_store_o  = 1'b0;
		is_branch_o = 1'b0;
		is_jal_o    = 1'b0;
		is_jalr_o   = 1'b0;
		branch_funct3_o = 3'b000;
		mem_unsigned_o = 1'b0;
		mem_size_o  = MSIZE8;
		rs1_used_o  = 1'b0;
		rs2_used_o  = 1'b0;

		case (opcode)
			// 0010011: OP-IMM
			7'b0010011: begin
				wen_o      = 1'b1;
				use_imm_o  = 1'b1;
				imm_o      = imm_i;
				rs1_used_o = 1'b1;
				unique case (funct3)
					3'b000: alu_op_o = ALU_ADD; // addi
					3'b001: begin // slli
						if (instr_i[31:26] == 6'b000000) begin
							alu_op_o = ALU_SLL;
							imm_o = {58'd0, instr_i[25:20]};
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b010: alu_op_o = ALU_SLT; // slti
					3'b011: alu_op_o = ALU_SLTU; // sltiu
					3'b100: alu_op_o = ALU_XOR; // xori
					3'b101: begin // srli/srai
						if (instr_i[31:26] == 6'b000000) begin
							alu_op_o = ALU_SRL;
							imm_o = {58'd0, instr_i[25:20]};
						end else if (instr_i[31:26] == 6'b010000) begin
							alu_op_o = ALU_SRA;
							imm_o = {58'd0, instr_i[25:20]};
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b110: alu_op_o = ALU_OR; // ori
					3'b111: alu_op_o = ALU_AND; // andi
					default: begin
						wen_o = 1'b0;
					end
				endcase
			end
			// 0110011: OP
			7'b0110011: begin
				wen_o      = 1'b1;
				rs1_used_o = 1'b1;
				rs2_used_o = 1'b1;
				unique case (funct3)
					3'b000: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_ADD; // add
						end else if (funct7 == 7'b0100000) begin
							alu_op_o = ALU_SUB; // sub
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_MUL; // mul
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b001: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_SLL;
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_MULH; // mulh
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b010: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_SLT;
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_MULHSU; // mulhsu
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b011: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_SLTU;
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_MULHU; // mulhu
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b100: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_XOR;
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_DIV; // div
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b101: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_SRL;
						end else if (funct7 == 7'b0100000) begin
							alu_op_o = ALU_SRA;
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_DIVU; // divu
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b110: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_OR;
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_REM; // rem
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b111: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_AND;
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_REMU; // remu
						end else begin
							wen_o = 1'b0;
						end
					end
					default: begin
						wen_o = 1'b0;
					end
				endcase
			end
			// 0011011: OP-IMM-32
			7'b0011011: begin
				wen_o      = 1'b1;
				use_imm_o  = 1'b1;
				imm_o      = imm_i;
				is_word_o  = 1'b1;
				rs1_used_o = 1'b1;
				unique case (funct3)
					3'b000: alu_op_o = ALU_ADD; // addiw
					3'b001: begin // slliw
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_SLL;
							imm_o = {59'd0, instr_i[24:20]};
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b101: begin // srliw/sraiw
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_SRL;
							imm_o = {59'd0, instr_i[24:20]};
						end else if (funct7 == 7'b0100000) begin
							alu_op_o = ALU_SRA;
							imm_o = {59'd0, instr_i[24:20]};
						end else begin
							wen_o = 1'b0;
						end
					end
					default: wen_o = 1'b0;
				endcase
			end
			// 0111011: OP-32
			7'b0111011: begin
				wen_o      = 1'b1;
				is_word_o  = 1'b1;
				rs1_used_o = 1'b1;
				rs2_used_o = 1'b1;
				unique case (funct3)
					3'b000: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_ADD; // addw
						end else if (funct7 == 7'b0100000) begin
							alu_op_o = ALU_SUB; // subw
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_MUL; // mulw
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b001: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_SLL; // sllw
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b101: begin
						if (funct7 == 7'b0000000) begin
							alu_op_o = ALU_SRL; // srlw
						end else if (funct7 == 7'b0100000) begin
							alu_op_o = ALU_SRA; // sraw
						end else if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_DIVU; // divuw
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b100: begin
						if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_DIV; // divw
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b110: begin
						if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_REM; // remw
						end else begin
							wen_o = 1'b0;
						end
					end
					3'b111: begin
						if (funct7 == 7'b0000001) begin
							alu_op_o = ALU_REMU; // remuw
						end else begin
							wen_o = 1'b0;
						end
					end
					default: wen_o = 1'b0;
				endcase
			end
			// 0110111: LUI
			7'b0110111: begin
				wen_o      = 1'b1;
				use_imm_o  = 1'b1;
				op1_zero_o = 1'b1;
				imm_o      = imm_u;
				alu_op_o   = ALU_ADD;
			end
			// 0010111: AUIPC
			7'b0010111: begin
				wen_o      = 1'b1;
				use_imm_o  = 1'b1;
				op1_pc_o   = 1'b1;
				imm_o      = imm_u;
				alu_op_o   = ALU_ADD;
			end
			// 1101111: JAL
			7'b1101111: begin
				wen_o      = 1'b1;
				use_imm_o  = 1'b1;
				is_jal_o   = 1'b1;
				imm_o      = imm_j;
			end
			// 1100111: JALR
			7'b1100111: begin
				if (funct3 == 3'b000) begin
					wen_o      = 1'b1;
					use_imm_o  = 1'b1;
					is_jalr_o  = 1'b1;
					imm_o      = imm_i;
					rs1_used_o = 1'b1;
				end
			end
			// 1100011: BRANCH
			7'b1100011: begin
				is_branch_o = 1'b1;
				rs1_used_o  = 1'b1;
				rs2_used_o  = 1'b1;
				imm_o       = imm_b;
				branch_funct3_o = funct3;
				if (!(funct3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111})) begin
					is_branch_o = 1'b0;
				end
			end
			// 0000011: LOAD
			7'b0000011: begin
				wen_o      = 1'b1;
				use_imm_o  = 1'b1;
				imm_o      = imm_i;
				is_load_o  = 1'b1;
				rs1_used_o = 1'b1;
				alu_op_o   = ALU_ADD;
				unique case (funct3)
					3'b000: begin mem_size_o = MSIZE1; mem_unsigned_o = 1'b0; end // lb
					3'b001: begin mem_size_o = MSIZE2; mem_unsigned_o = 1'b0; end // lh
					3'b010: begin mem_size_o = MSIZE4; mem_unsigned_o = 1'b0; end // lw
					3'b011: begin mem_size_o = MSIZE8; mem_unsigned_o = 1'b0; end // ld
					3'b100: begin mem_size_o = MSIZE1; mem_unsigned_o = 1'b1; end // lbu
					3'b101: begin mem_size_o = MSIZE2; mem_unsigned_o = 1'b1; end // lhu
					3'b110: begin mem_size_o = MSIZE4; mem_unsigned_o = 1'b1; end // lwu
					default: begin
						wen_o = 1'b0;
						is_load_o = 1'b0;
					end
				endcase
			end
			// 0100011: STORE
			7'b0100011: begin
				use_imm_o  = 1'b1;
				imm_o      = imm_s;
				is_store_o = 1'b1;
				rs1_used_o = 1'b1;
				rs2_used_o = 1'b1;
				alu_op_o   = ALU_ADD;
				unique case (funct3)
					3'b000: mem_size_o = MSIZE1; // sb
					3'b001: mem_size_o = MSIZE2; // sh
					3'b010: mem_size_o = MSIZE4; // sw
					3'b011: mem_size_o = MSIZE8; // sd
					default: begin
						is_store_o = 1'b0;
					end
				endcase
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
