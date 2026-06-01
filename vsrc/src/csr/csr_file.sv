`ifndef __CSR_FILE_SV
`define __CSR_FILE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/csr.sv"
`endif

// CSR file storing the Lab4/5/Bonus required registers and exposing them to Difftest.
// - M-mode: mstatus/mtvec/mip/mie/mscratch/mcause/mtval/mepc/mcycle/mhartid/satp/medeleg/mideleg
// - S-mode: stvec/sscratch/sepc/scause/stval/sie/sip (sstatus is a masked view of mstatus)
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
    // Trap/return inputs (multi-source: ECALL, page fault, ...)
    input  logic    trap_enter_i,
    input  word_t   trap_pc_i,
    input  word_t   trap_cause_i,
    input  word_t   trap_tval_i,
    input  u2       trap_priv_i,
    input  logic    trap_to_s_i,
    input  logic    mret_i,
    input  logic    sret_i,
    input  logic    trint_i,
    input  logic    swint_i,
    input  logic    exint_i,
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
    output word_t   medeleg_o,
    output word_t   mideleg_o,
    output word_t   stvec_o,
    output word_t   sscratch_o,
    output word_t   sepc_o,
    output word_t   scause_o,
    output word_t   stval_o,
    output word_t   sie_o,
    output word_t   sip_o,
    output word_t   sstatus_o,
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
    word_t medeleg_q;
    word_t mideleg_q;
    word_t stvec_q;
    word_t sscratch_q;
    word_t sepc_q;
    word_t scause_q;
    word_t stval_q;
    word_t effective_mip;
    word_t mstatus_after_write;
    u2     priv_mode_q;
    u2     mret_ret_priv;
    u1     sret_ret_priv_bit;
    u2     sret_ret_priv;

    localparam u2 PRIV_U = 2'b00;
    localparam u2 PRIV_S = 2'b01;
    localparam u2 PRIV_M = 2'b11;
    localparam int MSTATUS_SIE_BIT  = 1;
    localparam int MSTATUS_MIE_BIT  = 3;
    localparam int MSTATUS_SPIE_BIT = 5;
    localparam int MSTATUS_MPIE_BIT = 7;
    localparam int MSTATUS_SPP_BIT  = 8;
    localparam int MSTATUS_MPP_LSB  = 11;
    localparam int MSTATUS_MPRV_BIT = 17;
    localparam int MIP_MSIP_BIT      = 3;
    localparam int MIP_MTIP_BIT      = 7;
    localparam int MIP_MEIP_BIT      = 11;

    always_comb begin
        effective_mip = mip_q;
        effective_mip[MIP_MSIP_BIT] = swint_i;
        effective_mip[MIP_MTIP_BIT] = trint_i;
        effective_mip[MIP_MEIP_BIT] = exint_i;
    end

    always_comb begin
        mstatus_after_write = mstatus_q;
        if (wen_i) begin
            unique case (waddr_i)
                CSR_MSTATUS: mstatus_after_write = (mstatus_q & ~MSTATUS_MASK) | (wdata_i & MSTATUS_MASK);
                CSR_SSTATUS: mstatus_after_write = (mstatus_q & ~SSTATUS_MASK) | (wdata_i & SSTATUS_MASK);
                default: ;
            endcase
        end
    end

    // mhartid is read-only zero in our single-core implementation.
    assign mhartid_o  = '0;
    assign mstatus_o  = mstatus_q;
    assign mtvec_o    = mtvec_q;
    assign mip_o      = effective_mip;
    assign mie_o      = mie_q;
    assign mscratch_o = mscratch_q;
    assign mcause_o   = mcause_q;
    assign mtval_o    = mtval_q;
    assign mepc_o     = mepc_q;
    assign mcycle_o   = mcycle_q;
    assign satp_o     = satp_q;
    assign medeleg_o  = medeleg_q;
    assign mideleg_o  = mideleg_q;
    assign stvec_o    = stvec_q;
    assign sscratch_o = sscratch_q;
    assign sepc_o     = sepc_q;
    assign scause_o   = scause_q;
    assign stval_o    = stval_q;
    // sie/sip are views of mie/mip filtered by mideleg
    assign sie_o      = mie_q & mideleg_q;
    assign sip_o      = effective_mip & mideleg_q;
    assign sstatus_o  = mstatus_q & SSTATUS_MASK;
    assign priv_mode_o = priv_mode_q;
    assign mret_ret_priv     = mstatus_q[MSTATUS_MPP_LSB +: 2];
    assign sret_ret_priv_bit = mstatus_q[MSTATUS_SPP_BIT];
    assign sret_ret_priv     = {1'b0, sret_ret_priv_bit};  // SPP is 1 bit: 1=S, 0=U

    // Combinational read with masks applied where ISA requires it.
    always_comb begin
        unique case (raddr_i)
            CSR_MSTATUS:  rdata_o = mstatus_q;
            CSR_MTVEC:    rdata_o = mtvec_q;
            CSR_MIP:      rdata_o = effective_mip;
            CSR_MIE:      rdata_o = mie_q;
            CSR_MSCRATCH: rdata_o = mscratch_q;
            CSR_MCAUSE:   rdata_o = mcause_q;
            CSR_MTVAL:    rdata_o = mtval_q;
            CSR_MEPC:     rdata_o = mepc_q;
            CSR_MCYCLE:   rdata_o = mcycle_q;
            CSR_MHARTID:  rdata_o = '0;
            CSR_SATP:     rdata_o = satp_q;
            CSR_MEDELEG:  rdata_o = medeleg_q;
            CSR_MIDELEG:  rdata_o = mideleg_q;
            CSR_STVEC:    rdata_o = stvec_q;
            CSR_SSCRATCH: rdata_o = sscratch_q;
            CSR_SEPC:     rdata_o = sepc_q;
            CSR_SCAUSE:   rdata_o = scause_q;
            CSR_STVAL:    rdata_o = stval_q;
            CSR_SIE:      rdata_o = mie_q & mideleg_q;
            CSR_SIP:      rdata_o = effective_mip & mideleg_q;
            CSR_SSTATUS:  rdata_o = mstatus_q & SSTATUS_MASK;
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
            medeleg_q  <= '0;
            mideleg_q  <= '0;
            stvec_q    <= '0;
            sscratch_q <= '0;
            sepc_q     <= '0;
            scause_q   <= '0;
            stval_q    <= '0;
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
                    CSR_MEDELEG:  medeleg_q  <= wdata_i & MEDELEG_MASK;
                    CSR_MIDELEG:  mideleg_q  <= wdata_i & MIDELEG_MASK;
                    CSR_STVEC:    stvec_q    <= wdata_i & MTVEC_MASK;
                    CSR_SSCRATCH: sscratch_q <= wdata_i;
                    CSR_SEPC:     sepc_q     <= wdata_i;
                    CSR_SCAUSE:   scause_q   <= wdata_i;
                    CSR_STVAL:    stval_q    <= wdata_i;
                    CSR_SIE:      mie_q      <= (mie_q & ~mideleg_q) | (wdata_i & mideleg_q);
                    CSR_SIP:      mip_q      <= (mip_q & ~(mideleg_q & MIP_MASK)) | (wdata_i & mideleg_q & MIP_MASK);
                    CSR_SSTATUS:  mstatus_q  <= (mstatus_q & ~SSTATUS_MASK) | (wdata_i & SSTATUS_MASK);
                    // CSR_MHARTID is read-only zero and ignores writes.
                    default: ;
                endcase
            end

            if (trap_enter_i) begin
                if (trap_to_s_i) begin
                    // Delegated to S-mode
                    scause_q                        <= trap_cause_i;
                    sepc_q                          <= trap_pc_i;
                    stval_q                         <= trap_tval_i;
                    mstatus_q[MSTATUS_SPIE_BIT]     <= mstatus_after_write[MSTATUS_SIE_BIT];
                    mstatus_q[MSTATUS_SIE_BIT]      <= 1'b0;
                    mstatus_q[MSTATUS_SPP_BIT]      <= trap_priv_i[0];  // SPP is 1 bit (1=S, 0=U)
                    priv_mode_q                     <= PRIV_S;
                end else begin
                    // M-mode trap
                    mcause_q                        <= trap_cause_i;
                    mepc_q                          <= trap_pc_i;
                    mtval_q                         <= trap_tval_i;
                    mstatus_q[MSTATUS_MPIE_BIT]     <= mstatus_after_write[MSTATUS_MIE_BIT];
                    mstatus_q[MSTATUS_MIE_BIT]      <= 1'b0;
                    mstatus_q[MSTATUS_MPP_LSB +: 2] <= trap_priv_i;
                    priv_mode_q                     <= PRIV_M;
                end
            end else if (mret_i) begin
                mstatus_q[MSTATUS_MIE_BIT]      <= mstatus_q[MSTATUS_MPIE_BIT];
                mstatus_q[MSTATUS_MPIE_BIT]     <= 1'b1;
                mstatus_q[MSTATUS_MPP_LSB +: 2] <= PRIV_U;
                mstatus_q[16:15]                 <= 2'b00;  // XS <- Off
                if (mret_ret_priv != PRIV_M) begin
                    mstatus_q[MSTATUS_MPRV_BIT] <= 1'b0;
                end
                priv_mode_q <= mret_ret_priv;
            end else if (sret_i) begin
                mstatus_q[MSTATUS_SIE_BIT]  <= mstatus_q[MSTATUS_SPIE_BIT];
                mstatus_q[MSTATUS_SPIE_BIT] <= 1'b1;
                mstatus_q[MSTATUS_SPP_BIT]  <= 1'b0;  // SPP <- U
                if (sret_ret_priv != PRIV_M) begin
                    mstatus_q[MSTATUS_MPRV_BIT] <= 1'b0;
                end
                priv_mode_q <= sret_ret_priv;
            end
        end
    end
endmodule

`endif
