`ifndef __IF_ID_REG_SV
`define __IF_ID_REG_SV

// Pipeline register between IF and ID.
module if_id_reg import common::*;(
    input  logic  clk,
    input  logic  reset,
    input  logic  flush_i,
    input  logic  in_valid_i,
    input  word_t in_pc_i,
    input  u32    in_instr_i,
    output logic  out_valid_o,
    output word_t out_pc_o,
    output u32    out_instr_o
);
    always_ff @(posedge clk) begin
        if (reset || flush_i) begin
			// Flushing inserts a bubble into the next stage.
            out_valid_o <= 1'b0;
            out_pc_o    <= '0;
            out_instr_o <= '0;
        end else begin
            out_valid_o <= in_valid_i;
            out_pc_o    <= in_pc_i;
            out_instr_o <= in_instr_i;
        end
    end
endmodule

`endif
