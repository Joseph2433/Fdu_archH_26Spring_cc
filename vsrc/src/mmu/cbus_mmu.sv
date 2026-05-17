`ifndef __CBUS_MMU_SV
`define __CBUS_MMU_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/csr.sv"
`endif

module cbus_mmu import common::*; import csr_pkg::*;(
    input  logic      clk,
    input  logic      reset,
    input  cbus_req_t ireq,
    output cbus_resp_t iresp,
    output cbus_req_t oreq,
    input  cbus_resp_t oresp,
    input  word_t     satp_i,
    input  u2         priv_mode_i
);
    typedef enum logic [2:0] {
        S_IDLE,
        S_BYPASS,
        S_WALK_L2,
        S_WALK_L1,
        S_WALK_L0,
        S_ACCESS
    } state_t;

    localparam u2 PRIV_M = 2'b11;

    state_t state_q;
    cbus_req_t saved_req_q;
    cbus_req_t active_req_q;
    word_t vaddr_q;

    logic translate_req;
    logic mem_done;
    word_t pte;
    word_t translated_addr;
    logic pte_leaf;
    logic pte_valid;
    u9 vpn2;
    u9 vpn1;
    u9 vpn0;

    assign translate_req = ireq.valid && (priv_mode_i != PRIV_M) && (satp_i[63:60] == 4'd8);
    assign mem_done = oresp.ready && oresp.last;
    assign pte = oresp.data;
    assign vpn2 = vaddr_q[38:30];
    assign vpn1 = vaddr_q[29:21];
    assign vpn0 = vaddr_q[20:12];
    assign pte_valid = pte[0];
    assign pte_leaf = |pte[3:1];

    always_comb begin
        unique case (state_q)
            S_WALK_L2: translated_addr = {8'd0, pte[53:28], vaddr_q[29:0]};
            S_WALK_L1: translated_addr = {8'd0, pte[53:19], vaddr_q[20:0]};
            default:   translated_addr = {8'd0, pte[53:10], vaddr_q[11:0]};
        endcase
    end

    always_comb begin
        oreq = '0;
        iresp = '0;

        if (state_q == S_IDLE) begin
            if (translate_req) begin
                oreq.valid    = 1'b1;
                oreq.is_write = 1'b0;
                oreq.size     = MSIZE8;
                oreq.addr     = {8'd0, satp_i[43:0], 12'd0} + {52'd0, ireq.addr[38:30], 3'b000};
                oreq.strobe   = 8'd0;
                oreq.data     = '0;
                oreq.len      = MLEN1;
                oreq.burst    = AXI_BURST_FIXED;
            end else begin
                oreq = ireq;
                iresp = oresp;
            end
        end else if (state_q inside {S_WALK_L2, S_WALK_L1, S_WALK_L0}) begin
            oreq = active_req_q;
        end else if (state_q == S_BYPASS) begin
            oreq = active_req_q;
            iresp = oresp;
        end else begin
            oreq = active_req_q;
            iresp = oresp;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q <= S_IDLE;
            saved_req_q <= '0;
            active_req_q <= '0;
            vaddr_q <= '0;
        end else begin
            unique case (state_q)
                S_IDLE: begin
                    if (translate_req) begin
                        active_req_q.valid    <= 1'b1;
                        active_req_q.is_write <= 1'b0;
                        active_req_q.size     <= MSIZE8;
                        active_req_q.addr     <= {8'd0, satp_i[43:0], 12'd0} + {52'd0, ireq.addr[38:30], 3'b000};
                        active_req_q.strobe   <= 8'd0;
                        active_req_q.data     <= '0;
                        active_req_q.len      <= MLEN1;
                        active_req_q.burst    <= AXI_BURST_FIXED;
                        saved_req_q <= ireq;
                        vaddr_q <= ireq.addr;
                        if (mem_done) begin
                            if (pte_valid && pte_leaf) begin
                                active_req_q <= ireq;
                                active_req_q.addr <= {8'd0, pte[53:28], ireq.addr[29:0]};
                                state_q <= S_ACCESS;
                            end else begin
                                active_req_q.addr <= {8'd0, pte[53:10], 12'd0} + {52'd0, ireq.addr[29:21], 3'b000};
                                state_q <= S_WALK_L1;
                            end
                        end else begin
                            state_q <= S_WALK_L2;
                        end
                    end else if (ireq.valid && !mem_done) begin
                        active_req_q <= ireq;
                        state_q <= S_BYPASS;
                    end
                end

                S_BYPASS: begin
                    if (mem_done) begin
                        state_q <= S_IDLE;
                    end
                end

                S_WALK_L2: begin
                    if (mem_done) begin
                        if (pte_valid && pte_leaf) begin
                            active_req_q <= saved_req_q;
                            active_req_q.addr <= translated_addr;
                            state_q <= S_ACCESS;
                        end else begin
                            active_req_q.addr <= {8'd0, pte[53:10], 12'd0} + {52'd0, vpn1, 3'b000};
                            state_q <= S_WALK_L1;
                        end
                    end
                end

                S_WALK_L1: begin
                    if (mem_done) begin
                        if (pte_valid && pte_leaf) begin
                            active_req_q <= saved_req_q;
                            active_req_q.addr <= translated_addr;
                            state_q <= S_ACCESS;
                        end else begin
                            active_req_q.addr <= {8'd0, pte[53:10], 12'd0} + {52'd0, vpn0, 3'b000};
                            state_q <= S_WALK_L0;
                        end
                    end
                end

                S_WALK_L0: begin
                    if (mem_done) begin
                        active_req_q <= saved_req_q;
                        active_req_q.addr <= pte_valid ? translated_addr : '0;
                        state_q <= S_ACCESS;
                    end
                end

                S_ACCESS: begin
                    if (mem_done) begin
                        state_q <= S_IDLE;
                    end
                end

                default: state_q <= S_IDLE;
            endcase
        end
    end
endmodule

`endif
