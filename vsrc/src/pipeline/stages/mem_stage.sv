`ifndef __MEM_STAGE_SV
`define __MEM_STAGE_SV

// MEM stage placeholder for Lab1. Later labs can insert load/store logic here.
module mem_stage import common::*;(
    input  word_t ex_result_i,
    output word_t mem_result_o
);
    assign mem_result_o = ex_result_i;
endmodule

`endif
