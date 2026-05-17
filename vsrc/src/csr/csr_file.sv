`ifndef __CSR_FILE_SV
`define __CSR_FILE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/csr.sv"
`endif

// CSR file storing the Lab4 required registers and exposing them to Difftest.
// - mcycle is incremented every cycle; explicit writes override the increment.
// - mhartid is hard-wired to zero and ignores writes.
// - Writes apply per-CSR masks defined in csr_pkg.
module csr_file import common::*; import csr_pkg::*;(
    input  logic    clk,
    input  logic    reset,
    // Combinational read port used by the EX stage.
    input  csr_addr_t raddr_i,
    output word_t   rdata_o,
    // Synchronous write port driven from the WB stage at commit time.
    input  logic    wen_i,
    input  csr_addr_t waddr_i,
    input  word_t   wdata_i,
    input  logic    trap_enter_i,
    input  word_t   trap_pc_i,
    input  u2       trap_priv_i,
    input  logic    mret_i,
    // Architectural state outputs for Difftest connection.
    output word_t   mstatus_o,
    output word_t   mtvec_o,
    output word_t   mip_o,
    output word_t   mie_o,
    output word_t   mscratch_o,
    output word_t   mcause_o,
    output word_t   mtval_o,
    output word_t   mepc_o,
    output word_t   mcycle_o,
    output word_t   mhartid_o,
    output word_t   satp_o,
    output u2       priv_mode_o
);
    word_t mstatus_q;
    word_t mtvec_q;
    word_t mip_q;
    word_t mie_q;
    word_t mscratch_q;
    word_t mcause_q;
    word_t mtval_q;
    word_t mepc_q;
    word_t mcycle_q;
    word_t satp_q;
    u2     priv_mode_q;
    u2     mret_ret_priv;

    localparam u2 PRIV_U = 2'b00;
    localparam u2 PRIV_M = 2'b11;
    localparam int MSTATUS_MIE_BIT  = 3;
    localparam int MSTATUS_MPIE_BIT = 7;
    localparam int MSTATUS_MPP_LSB  = 11;
    localparam int MSTATUS_MPRV_BIT = 17;

    // mhartid is read-only zero in our single-core implementation.
    assign mhartid_o  = '0;
    assign mstatus_o  = mstatus_q;
    assign mtvec_o    = mtvec_q;
    assign mip_o      = mip_q;
    assign mie_o      = mie_q;
    assign mscratch_o = mscratch_q;
    assign mcause_o   = mcause_q;
    assign mtval_o    = mtval_q;
    assign mepc_o     = mepc_q;
    assign mcycle_o   = mcycle_q;
    assign satp_o     = satp_q;
    assign priv_mode_o = priv_mode_q;
    assign mret_ret_priv = mstatus_q[MSTATUS_MPP_LSB +: 2];

    // Combinational read with masks applied where ISA requires it.
    always_comb begin
        unique case (raddr_i)
            CSR_MSTATUS:  rdata_o = mstatus_q;
            CSR_MTVEC:    rdata_o = mtvec_q;
            CSR_MIP:      rdata_o = mip_q;
            CSR_MIE:      rdata_o = mie_q;
            CSR_MSCRATCH: rdata_o = mscratch_q;
            CSR_MCAUSE:   rdata_o = mcause_q;
            CSR_MTVAL:    rdata_o = mtval_q;
            CSR_MEPC:     rdata_o = mepc_q;
            CSR_MCYCLE:   rdata_o = mcycle_q;
            CSR_MHARTID:  rdata_o = '0;
            CSR_SATP:     rdata_o = satp_q;
            default:      rdata_o = '0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            mstatus_q  <= '0;
            mtvec_q    <= '0;
            mip_q      <= '0;
            mie_q      <= '0;
            mscratch_q <= '0;
            mcause_q   <= '0;
            mtval_q    <= '0;
            mepc_q     <= '0;
            mcycle_q   <= '0;
            satp_q     <= '0;
            priv_mode_q <= PRIV_M;
        end else begin
            // Default: mcycle increments every cycle (wraps automatically on overflow).
            mcycle_q <= mcycle_q + 64'd1;

            if (wen_i) begin
                unique case (waddr_i)
                    CSR_MSTATUS:  mstatus_q  <= (mstatus_q  & ~MSTATUS_MASK) | (wdata_i & MSTATUS_MASK);
                    CSR_MTVEC:    mtvec_q    <= wdata_i & MTVEC_MASK;
                    CSR_MIP:      mip_q      <= (mip_q      & ~MIP_MASK)     | (wdata_i & MIP_MASK);
                    CSR_MIE:      mie_q      <= wdata_i;
                    CSR_MSCRATCH: mscratch_q <= wdata_i;
                    CSR_MCAUSE:   mcause_q   <= wdata_i;
                    CSR_MTVAL:    mtval_q    <= wdata_i;
                    CSR_MEPC:     mepc_q     <= wdata_i;
                    CSR_MCYCLE:   mcycle_q   <= wdata_i;
                    CSR_SATP:     satp_q     <= wdata_i;
                    // CSR_MHARTID is read-only zero and ignores writes.
                    default: ;
                endcase
            end

            if (trap_enter_i) begin
                mcause_q <= (trap_priv_i == PRIV_U) ? 64'd8 : 64'd11;
                mepc_q   <= trap_pc_i;
                mtval_q  <= '0;

                mstatus_q[MSTATUS_MPIE_BIT] <= mstatus_q[MSTATUS_MIE_BIT];
                mstatus_q[MSTATUS_MIE_BIT]  <= 1'b0;
                mstatus_q[MSTATUS_MPP_LSB +: 2] <= trap_priv_i;
                priv_mode_q <= PRIV_M;
            end else if (mret_i) begin
                mstatus_q[MSTATUS_MIE_BIT] <= mstatus_q[MSTATUS_MPIE_BIT];
                mstatus_q[MSTATUS_MPIE_BIT] <= 1'b1;
                mstatus_q[MSTATUS_MPP_LSB +: 2] <= PRIV_U;
                if (mret_ret_priv != PRIV_M) begin
                    mstatus_q[MSTATUS_MPRV_BIT] <= 1'b0;
                end
                priv_mode_q <= mret_ret_priv;
            end
        end
    end
endmodule

`endif
