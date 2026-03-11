`ifndef __IF_STAGE_SV
`define __IF_STAGE_SV

// IF stage: continuously issues the current PC until a response arrives.
module if_stage import common::*;(
    input  logic       clk,
    input  logic       reset,
    input  logic       halt_i,
    input  logic       drop_resp_i,
    output ibus_req_t  ireq_o,
    input  ibus_resp_t iresp_i,
    output logic       fetch_valid_o,
    output word_t      fetch_pc_o,
    output u32         fetch_instr_o
);
    word_t pc_q;

    // Lab1 has no branch redirection yet, so fetch is strictly sequential.
    assign ireq_o.valid = !halt_i;
    assign ireq_o.addr  = pc_q;

    // A returning response can be dropped when the core is draining after trap.
    assign fetch_valid_o = iresp_i.data_ok && !drop_resp_i;
    assign fetch_pc_o    = pc_q;
    assign fetch_instr_o = iresp_i.data;

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_q      <= PCINIT;
        end else begin
            // Advance PC only after the current fetch has been accepted.
            if (iresp_i.data_ok && !halt_i) begin
                pc_q      <= pc_q + 64'd4;
            end
        end
    end
endmodule

`endif
