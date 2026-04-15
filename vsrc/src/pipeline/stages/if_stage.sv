`ifndef __IF_STAGE_SV
`define __IF_STAGE_SV

// IF stage: continuously issues the current PC until a response arrives.
module if_stage import common::*;(
    input  logic       clk,
    input  logic       reset,
    input  logic       halt_i,
    input  logic       redirect_i,
    input  word_t      redirect_pc_i,
    input  logic       drop_resp_i,
    output ibus_req_t  ireq_o,
    input  ibus_resp_t iresp_i,
    output logic       fetch_valid_o,
    output word_t      fetch_pc_o,
    output u32         fetch_instr_o
);
    word_t pc_q;
    logic  drop_pending_q;
    logic  redirect_pending_q;
    word_t redirect_pc_q;
    logic  hold_valid_q;
    word_t hold_pc_q;
    u32    hold_instr_q;
    logic  drop_now;
    logic  resp_valid;
    logic  resp_keep;

    assign drop_now = drop_resp_i || redirect_i || drop_pending_q;
    assign resp_valid = iresp_i.data_ok;
    assign resp_keep = resp_valid && !drop_now;

    assign ireq_o.valid = !halt_i;
    assign ireq_o.addr  = pc_q;

    // Drop stale responses after redirect/drain and only forward architecturally valid fetches.
    assign fetch_valid_o = !halt_i && (hold_valid_q || resp_keep);
    assign fetch_pc_o    = hold_valid_q ? hold_pc_q : pc_q;
    assign fetch_instr_o = hold_valid_q ? hold_instr_q : iresp_i.data;

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_q      <= PCINIT;
            drop_pending_q <= 1'b0;
            redirect_pending_q <= 1'b0;
            redirect_pc_q <= '0;
            hold_valid_q <= 1'b0;
            hold_pc_q <= '0;
            hold_instr_q <= '0;
        end else begin
            if (redirect_i) begin
                redirect_pending_q <= 1'b1;
                redirect_pc_q <= redirect_pc_i;
                hold_valid_q <= 1'b0;
            end

            if (resp_valid) begin
                if (redirect_pending_q || redirect_i) begin
                    pc_q <= redirect_i ? redirect_pc_i : redirect_pc_q;
                end else begin
                    pc_q <= pc_q + 64'd4;
                end
            end

            if (resp_keep && halt_i) begin
                hold_valid_q <= 1'b1;
                hold_pc_q <= pc_q;
                hold_instr_q <= iresp_i.data;
            end else if (hold_valid_q && !halt_i) begin
                hold_valid_q <= 1'b0;
            end

            if (redirect_i && !resp_valid) begin
                drop_pending_q <= 1'b1;
            end else if (resp_valid && drop_pending_q) begin
                drop_pending_q <= 1'b0;
            end

            if (resp_valid && (redirect_pending_q || redirect_i)) begin
                redirect_pending_q <= 1'b0;
            end
        end
    end
endmodule

`endif
