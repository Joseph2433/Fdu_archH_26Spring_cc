`ifndef __REGFILE_SV
`define __REGFILE_SV

// 32 x 64-bit integer register file with two read ports and one write port.
module regfile import common::*;(
	input  logic  clk,
	input  logic  reset,
	input  logic  wen_i,
	input  u5     waddr_i,
	input  word_t wdata_i,
	input  u5     raddr1_i,
	input  u5     raddr2_i,
	output word_t rdata1_o,
	output word_t rdata2_o,
	output word_t regs_o[31:0]
);
	word_t regs_q[31:0];

	// x0 is hard-wired to zero on reads.
	assign rdata1_o = (raddr1_i == '0) ? '0 : regs_q[raddr1_i];
	assign rdata2_o = (raddr2_i == '0) ? '0 : regs_q[raddr2_i];

	// Export the full architectural register state for Difftest.
	genvar idx;
	generate
		for (idx = 0; idx < 32; idx = idx + 1) begin : gen_regs_out
			assign regs_o[idx] = regs_q[idx];
		end
	endgenerate

	always_ff @(posedge clk) begin
		if (reset) begin
			// Clear architectural state on reset.
			integer i;
			for (i = 0; i < 32; i = i + 1) begin
				regs_q[i] <= '0;
			end
		end else begin
			if (wen_i && (waddr_i != '0)) begin
				regs_q[waddr_i] <= wdata_i;
			end
			// x0 must remain zero even if an illegal write is attempted.
			regs_q[0] <= '0;
		end
	end
endmodule

`endif
