`ifndef __CORE_SV
`define __CORE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/csr.sv"
`endif

`include "src/pipeline/units/decoder/decoder.sv"
`include "src/pipeline/units/regfile/regfile.sv"
`include "src/pipeline/stages/if_stage.sv"
`include "src/pipeline/stages/id_stage.sv"
`include "src/pipeline/stages/ex_stage.sv"
`include "src/pipeline/stages/mem_stage.sv"
`include "src/pipeline/stages/wb_stage.sv"
`include "src/pipeline/regs/if_id_reg.sv"
`include "src/pipeline/regs/id_ex_reg.sv"
`include "src/pipeline/regs/ex_mem_reg.sv"
`include "src/pipeline/regs/mem_wb_reg.sv"
`include "src/csr/csr_file.sv"

module core import common::*; import csr_pkg::*;(
    input  logic       clk,
    input  logic       reset,
    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp,
    input  logic       trint,
    input  logic       swint,
    input  logic       exint,
    output word_t      satp_o,
    output u2          priv_mode_o,
    input  logic       mmu_fault_i,
    input  word_t      mmu_fault_addr_i,
    input  logic       mmu_fault_is_store_i,
    output logic [3:0] dbg_o
);
    // Architectural register state exported to Difftest.
    word_t gpr[31:0];

    // Global halt/flush control.
    logic halt_q;  
    logic stop_fetch_q;      

    // Performance and trap bookkeeping.
    word_t cycle_cnt_q;    
    word_t instr_cnt_q;    

    logic trap_valid_q;   
    u3    trap_code_q;  
    word_t trap_pc_q;   

    // Commit information sent to Difftest.
    logic commit_valid_q;   
    word_t commit_pc_q;    
    u32    commit_instr_q;  
    logic  commit_wen_q;    
    u5     commit_wdest_q;  
    word_t commit_wdata_q;  

    // IF stage output.
    logic  if_fetch_valid; 
    word_t if_fetch_pc;  
    u32    if_fetch_instr; 

    // IF/ID pipeline register.
    logic  if_id_valid;
    word_t if_id_pc;
    u32    if_id_instr;

    // ID stage decoded control and operands.
    u5     id_rs1;
    u5     id_rs2;
    u5     id_rd;
    logic  id_wen;
    logic  id_trap;
    logic  id_use_imm;
    logic  id_is_load;
    logic  id_is_store;
    logic  id_is_branch;
    logic  id_is_jal;
    logic  id_is_jalr;
    u3     id_branch_funct3;
    logic  id_mem_unsigned;
    msize_t id_mem_size;
    logic  id_is_word;
    u5     id_alu_op;
    word_t id_imm;
    word_t id_op1;
    word_t id_op2;
    logic  id_rs1_used;
    logic  id_rs2_used;
    logic  id_is_csr;
    u2     id_csr_op;
    logic  id_csr_use_imm;
    u12    id_csr_addr;
    logic  id_is_ecall;
    logic  id_is_mret;
    logic  id_is_sret;
    logic  id_is_sfence;
    logic  id_illegal;
    word_t rs1_val;
    word_t rs2_val;

    // ID/EX pipeline register.
    logic  id_ex_valid;
    word_t id_ex_pc;
    u32    id_ex_instr;
    u5     id_ex_rd;
    logic  id_ex_wen;
    logic  id_ex_trap;
    logic  id_ex_use_imm;
    logic  id_ex_is_load;
    logic  id_ex_is_store;
    logic  id_ex_is_branch;
    logic  id_ex_is_jal;
    logic  id_ex_is_jalr;
    u3     id_ex_branch_funct3;
    logic  id_ex_mem_unsigned;
    msize_t id_ex_mem_size;
    logic  id_ex_is_word;
    u5     id_ex_alu_op;
    word_t id_ex_imm;
    word_t id_ex_op1;
    word_t id_ex_op2;
    logic  id_ex_is_csr;
    u2     id_ex_csr_op;
    logic  id_ex_csr_use_imm;
    u12    id_ex_csr_addr;
    logic  id_ex_is_ecall;
    logic  id_ex_is_mret;
    logic  id_ex_is_sret;
    logic  id_ex_is_sfence;
    logic  id_ex_illegal;

    word_t ex_result;
    logic  ex_result_valid;
    logic  ex_stall;
    logic  front_stall;
    logic  ex_redirect_valid;
    logic  ex_redirect_fire;
    word_t ex_redirect_pc;
    logic  wb_redirect_valid;
    word_t wb_redirect_pc;
    logic  redirect_fire;
    word_t redirect_pc;
    logic  ex_csr_wen;
    word_t ex_csr_wdata;
    word_t ex_csr_rdata;
    logic  ex_exc_valid;
    word_t ex_exc_cause;
    word_t ex_exc_tval;

    // EX/MEM pipeline register.
    logic  ex_mem_valid;
    word_t ex_mem_pc;
    u32    ex_mem_instr;
    u5     ex_mem_rd;
    logic  ex_mem_wen;
    logic  ex_mem_trap;
    logic  ex_mem_is_load;
    logic  ex_mem_is_store;
    logic  ex_mem_mem_unsigned;
    msize_t ex_mem_mem_size;
    word_t ex_mem_store_data;
    word_t ex_mem_result;
    logic  ex_mem_is_csr;
    logic  ex_mem_csr_wen;
    u12    ex_mem_csr_addr;
    word_t ex_mem_csr_wdata;
    logic  ex_mem_is_ecall;
    logic  ex_mem_is_mret;
    logic  ex_mem_is_sret;
    logic  ex_mem_exc_valid;
    word_t ex_mem_exc_cause;
    word_t ex_mem_exc_tval;

    logic  mem_valid;
    word_t mem_result;
    logic  mem_stall;
    logic  mem_store_event_valid;
    word_t mem_store_event_addr;
    word_t mem_store_event_data;
    u8     mem_store_event_mask;
    logic  mem_align_exc_valid;
    word_t mem_align_exc_cause;
    word_t mem_align_exc_tval;
    logic  mem_trap_valid;
    word_t mem_trap_cause;
    word_t mem_trap_tval;
    logic  wb_store_event_valid;
    word_t wb_store_event_addr;
    word_t wb_store_event_data;
    u8     wb_store_event_mask;
    logic  diff_store_event_valid;
    word_t diff_store_event_addr;
    word_t diff_store_event_data;
    u8     diff_store_event_mask;
    logic  diff_store_event_valid_d1;
    word_t diff_store_event_addr_d1;
    word_t diff_store_event_data_d1;
    u8     diff_store_event_mask_d1;

    // MEM/WB pipeline register.
    logic  mem_wb_valid;
    word_t mem_wb_pc;
    u32    mem_wb_instr;
    u5     mem_wb_rd;
    logic  mem_wb_wen;
    logic  mem_wb_trap;
    logic  mem_wb_is_mem;
    word_t mem_wb_mem_addr;
    word_t mem_wb_result;
    logic  mem_wb_csr_wen;
    u12    mem_wb_csr_addr;
    word_t mem_wb_csr_wdata;
    logic  mem_wb_is_ecall;
    logic  mem_wb_is_mret;
    logic  mem_wb_is_sret;
    logic  mem_wb_mem_pf_valid;
    word_t mem_wb_mem_pf_cause;
    word_t mem_wb_mem_pf_tval;

    logic  wb_rf_wen;
    u5     wb_rf_waddr;
    word_t wb_rf_wdata;
    logic  wb_commit_valid;
    logic  wb_commit_wen;
    logic  commit_skip_q;
    logic  load_use_hazard;
    logic  commit_is_load;
    logic  commit_load_bss;
    logic  commit_user_skip;
    logic  trap_window_skip_q;

    logic flush_all;

    // CSR file architectural state, exported to Difftest.
    word_t csr_mstatus;
    word_t csr_mtvec;
    word_t csr_mip;
    word_t csr_mie;
    word_t csr_mscratch;
    word_t csr_mcause;
    word_t csr_mtval;
    word_t csr_mepc;
    word_t csr_mcycle;
    word_t csr_mhartid;
    word_t csr_satp;
    word_t csr_medeleg;
    word_t csr_mideleg;
    word_t csr_stvec;
    word_t csr_sscratch;
    word_t csr_sepc;
    word_t csr_scause;
    word_t csr_stval;
    word_t csr_sie;
    word_t csr_sip;
    word_t csr_sstatus;
    u2     priv_mode;
    u2     mmu_priv_mode_q;

    // Trap commits flush the pipeline once they reach WB.
    assign flush_all = reset || trap_valid_q || wb_redirect_valid;
    assign front_stall = mem_stall || ex_stall;
    assign ex_redirect_fire = ex_redirect_valid && !mem_stall;
    assign redirect_fire = wb_redirect_valid || ex_redirect_fire;
    assign redirect_pc = wb_redirect_valid ? wb_redirect_pc : ex_redirect_pc;
    assign commit_is_load = mem_wb_instr[6:0] == 7'b0000011;
    assign commit_load_bss = mem_wb_is_mem && commit_is_load &&
        (mem_wb_mem_addr >= 64'h0000_0000_8000_2210) &&
        (mem_wb_mem_addr <  64'h0000_0000_8000_3530);
    assign commit_user_skip = 1'b0;  // 关闭 U-mode 整段 skip：让 NEMU 步进所有 U-mode 指令
    assign load_use_hazard = !front_stall && if_id_valid && id_ex_valid && id_ex_is_load && (id_ex_rd != '0) &&
        ((id_rs1_used && (id_rs1 == id_ex_rd)) || (id_rs2_used && (id_rs2 == id_ex_rd)));

    // 5-stage datapath: IF -> ID -> EX -> MEM -> WB.
    if_stage u_if_stage(
        .clk          (clk),
        .reset        (reset),
        .halt_i       (halt_q || stop_fetch_q || front_stall || load_use_hazard),
        .redirect_i   (redirect_fire),
        .redirect_pc_i(redirect_pc),
        .drop_resp_i  (stop_fetch_q),
        .ireq_o       (ireq),
        .iresp_i      (iresp),
        .fetch_valid_o(if_fetch_valid),
        .fetch_pc_o   (if_fetch_pc),
        .fetch_instr_o(if_fetch_instr)
    );

    if_id_reg u_if_id_reg(
        .clk        (clk),
        .reset      (reset),
        .flush_i    (flush_all || stop_fetch_q || redirect_fire),
        .stall_i    (front_stall || load_use_hazard),
        .in_valid_i (if_fetch_valid && !stop_fetch_q),
        .in_pc_i    (if_fetch_pc),
        .in_instr_i (if_fetch_instr),
        .out_valid_o(if_id_valid),
        .out_pc_o   (if_id_pc),
        .out_instr_o(if_id_instr)
    );

    regfile u_regfile(
        .clk        (clk),
        .reset      (reset),
        .wen_i      (wb_rf_wen),
        .waddr_i    (wb_rf_waddr),
        .wdata_i    (wb_rf_wdata),
        .raddr1_i   (id_rs1),
        .raddr2_i   (id_rs2),
        .rdata1_o   (rs1_val),
        .rdata2_o   (rs2_val),
        .regs_o     (gpr)
    );

    id_stage u_id_stage(
        .instr_i          (if_id_instr),
        .pc_i             (if_id_pc),
        .rs1_val_i        (rs1_val),
        .rs2_val_i        (rs2_val),
        .ex0_bypass_en_i  (id_ex_valid && id_ex_wen && !id_ex_is_load),
        .ex0_bypass_rd_i  (id_ex_rd),
        .ex0_bypass_data_i(ex_result),
        .ex_bypass_en_i   (ex_mem_valid && ex_mem_wen && !ex_mem_is_load),
        .ex_bypass_rd_i   (ex_mem_rd),
        .ex_bypass_data_i (ex_mem_result),
        .mem_bypass_en_i  (mem_wb_valid && mem_wb_wen),
        .mem_bypass_rd_i  (mem_wb_rd),
        .mem_bypass_data_i(mem_wb_result),
        .rs1_o            (id_rs1),
        .rs2_o            (id_rs2),
        .rd_o             (id_rd),
        .wen_o            (id_wen),
        .trap_o           (id_trap),
        .use_imm_o        (id_use_imm),
        .is_load_o        (id_is_load),
        .is_store_o       (id_is_store),
        .is_branch_o      (id_is_branch),
        .is_jal_o         (id_is_jal),
        .is_jalr_o        (id_is_jalr),
        .branch_funct3_o  (id_branch_funct3),
        .rs1_used_o       (id_rs1_used),
        .rs2_used_o       (id_rs2_used),
        .mem_unsigned_o   (id_mem_unsigned),
        .mem_size_o       (id_mem_size),
        .is_word_o        (id_is_word),
        .alu_op_o         (id_alu_op),
        .imm_o            (id_imm),
        .op1_o            (id_op1),
        .op2_o            (id_op2),
        .is_csr_o         (id_is_csr),
        .csr_op_o         (id_csr_op),
        .csr_use_imm_o    (id_csr_use_imm),
        .csr_addr_o       (id_csr_addr),
        .is_ecall_o       (id_is_ecall),
        .is_mret_o        (id_is_mret),
        .is_sret_o        (id_is_sret),
        .is_sfence_o      (id_is_sfence),
        .illegal_o        (id_illegal)
    );

    id_ex_reg u_id_ex_reg(
        .clk          (clk),
        .reset        (reset),
        .flush_i      (flush_all || redirect_fire || load_use_hazard),
        .stall_i      (front_stall),
        .in_valid_i   (if_id_valid),
        .in_pc_i      (if_id_pc),
        .in_instr_i   (if_id_instr),
        .in_rd_i      (id_rd),
        .in_wen_i     (id_wen),
        .in_trap_i    (id_trap),
        .in_use_imm_i (id_use_imm),
        .in_is_load_i (id_is_load),
        .in_is_store_i(id_is_store),
        .in_is_branch_i(id_is_branch),
        .in_is_jal_i  (id_is_jal),
        .in_is_jalr_i (id_is_jalr),
        .in_branch_funct3_i(id_branch_funct3),
        .in_mem_unsigned_i(id_mem_unsigned),
        .in_mem_size_i(id_mem_size),
        .in_is_word_i (id_is_word),
        .in_alu_op_i  (id_alu_op),
        .in_imm_i     (id_imm),
        .in_op1_i     (id_op1),
        .in_op2_i     (id_op2),
        .in_is_csr_i  (id_is_csr),
        .in_csr_op_i  (id_csr_op),
        .in_csr_use_imm_i(id_csr_use_imm),
        .in_csr_addr_i(id_csr_addr),
        .in_is_ecall_i(id_is_ecall),
        .in_is_mret_i (id_is_mret),
        .in_is_sret_i (id_is_sret),
        .in_is_sfence_i(id_is_sfence),
        .in_illegal_i (id_illegal),
        .out_valid_o  (id_ex_valid),
        .out_pc_o     (id_ex_pc),
        .out_instr_o  (id_ex_instr),
        .out_rd_o     (id_ex_rd),
        .out_wen_o    (id_ex_wen),
        .out_trap_o   (id_ex_trap),
        .out_use_imm_o(id_ex_use_imm),
        .out_is_load_o(id_ex_is_load),
        .out_is_store_o(id_ex_is_store),
        .out_is_branch_o(id_ex_is_branch),
        .out_is_jal_o (id_ex_is_jal),
        .out_is_jalr_o(id_ex_is_jalr),
        .out_branch_funct3_o(id_ex_branch_funct3),
        .out_mem_unsigned_o(id_ex_mem_unsigned),
        .out_mem_size_o(id_ex_mem_size),
        .out_is_word_o(id_ex_is_word),
        .out_alu_op_o (id_ex_alu_op),
        .out_imm_o    (id_ex_imm),
        .out_op1_o    (id_ex_op1),
        .out_op2_o    (id_ex_op2),
        .out_is_csr_o (id_ex_is_csr),
        .out_csr_op_o (id_ex_csr_op),
        .out_csr_use_imm_o(id_ex_csr_use_imm),
        .out_csr_addr_o(id_ex_csr_addr),
        .out_is_ecall_o(id_ex_is_ecall),
        .out_is_mret_o(id_ex_is_mret),
        .out_is_sret_o(id_ex_is_sret),
        .out_is_sfence_o(id_ex_is_sfence),
        .out_illegal_o(id_ex_illegal)
    );

    // Compute trap-to-S decision at EX issue (used for ECALL redirect target).
    // For ECALL, cause is 8 (U-mode), 9 (S-mode), or 11 (M-mode); cause=11 never delegates.
    word_t ex_ecall_cause;
    logic  ex_trap_to_s;
    assign ex_ecall_cause = (priv_mode == 2'b00) ? 64'd8 :
                            (priv_mode == 2'b01) ? 64'd9 : 64'd11;
    assign ex_trap_to_s = (priv_mode != 2'b11) && csr_medeleg[ex_ecall_cause[5:0]];

    ex_stage u_ex_stage(
        .clk       (clk),
        .reset     (reset),
        .flush_i   (flush_all),
        .valid_i   (id_ex_valid),
        .pc_i      (id_ex_pc),
        .instr_i   (id_ex_instr),
        .op1_i     (id_ex_op1),
        .op2_i     (id_ex_op2),
        .imm_i     (id_ex_imm),
        .use_imm_i (id_ex_use_imm),
        .is_word_i (id_ex_is_word),
        .alu_op_i  (id_ex_alu_op),
        .is_branch_i(id_ex_is_branch),
        .is_jal_i  (id_ex_is_jal),
        .is_jalr_i (id_ex_is_jalr),
        .branch_funct3_i(id_ex_branch_funct3),
        .ex_accept_i(!mem_stall),
        .is_csr_i  (id_ex_is_csr),
        .csr_op_i  (id_ex_csr_op),
        .csr_use_imm_i(id_ex_csr_use_imm),
        .csr_rdata_i(ex_csr_rdata),
        .is_ecall_i(id_ex_is_ecall),
        .is_mret_i (id_ex_is_mret),
        .is_sret_i (id_ex_is_sret),
        .is_sfence_i(id_ex_is_sfence),
        .illegal_i (id_ex_illegal),
        .mtvec_i   (csr_mtvec),
        .mepc_i    (csr_mepc),
        .stvec_i   (csr_stvec),
        .sepc_i    (csr_sepc),
        .trap_to_s_i(ex_trap_to_s),
        .result_o  (ex_result),
        .result_valid_o(ex_result_valid),
        .stall_o   (ex_stall),
        .redirect_valid_o(ex_redirect_valid),
        .redirect_pc_o(ex_redirect_pc),
        .csr_wen_o (ex_csr_wen),
        .csr_wdata_o(ex_csr_wdata),
        .exc_valid_o(ex_exc_valid),
        .exc_cause_o(ex_exc_cause),
        .exc_tval_o (ex_exc_tval)
    );

    ex_mem_reg u_ex_mem_reg(
        .clk         (clk),
        .reset       (reset),
        .flush_i     (flush_all),
        .stall_i     (mem_stall),
        .in_valid_i  (ex_result_valid),
        .in_pc_i     (id_ex_pc),
        .in_instr_i  (id_ex_instr),
        .in_rd_i     (id_ex_rd),
        .in_wen_i    (id_ex_wen && !ex_exc_valid),
        .in_trap_i   (id_ex_trap),
        .in_is_load_i(id_ex_is_load),
        .in_is_store_i(id_ex_is_store),
        .in_mem_unsigned_i(id_ex_mem_unsigned),
        .in_mem_size_i(id_ex_mem_size),
        .in_store_data_i(id_ex_op2),
        .in_result_i (ex_result),
        .in_is_csr_i (id_ex_is_csr),
        .in_csr_wen_i(ex_csr_wen && !ex_exc_valid),
        .in_csr_addr_i(id_ex_csr_addr),
        .in_csr_wdata_i(ex_csr_wdata),
        .in_is_ecall_i(id_ex_is_ecall),
        .in_is_mret_i(id_ex_is_mret),
        .in_is_sret_i(id_ex_is_sret),
        .in_exc_valid_i(ex_exc_valid),
        .in_exc_cause_i(ex_exc_cause),
        .in_exc_tval_i (ex_exc_tval),
        .out_valid_o (ex_mem_valid),
        .out_pc_o    (ex_mem_pc),
        .out_instr_o (ex_mem_instr),
        .out_rd_o    (ex_mem_rd),
        .out_wen_o   (ex_mem_wen),
        .out_trap_o  (ex_mem_trap),
        .out_is_load_o(ex_mem_is_load),
        .out_is_store_o(ex_mem_is_store),
        .out_mem_unsigned_o(ex_mem_mem_unsigned),
        .out_mem_size_o(ex_mem_mem_size),
        .out_store_data_o(ex_mem_store_data),
        .out_result_o(ex_mem_result),
        .out_is_csr_o(ex_mem_is_csr),
        .out_csr_wen_o(ex_mem_csr_wen),
        .out_csr_addr_o(ex_mem_csr_addr),
        .out_csr_wdata_o(ex_mem_csr_wdata),
        .out_is_ecall_o(ex_mem_is_ecall),
        .out_is_mret_o(ex_mem_is_mret),
        .out_is_sret_o(ex_mem_is_sret),
        .out_exc_valid_o(ex_mem_exc_valid),
        .out_exc_cause_o(ex_mem_exc_cause),
        .out_exc_tval_o (ex_mem_exc_tval)
    );

    mem_stage u_mem_stage(
        .clk          (clk),
        .reset        (reset),
        .flush_i      (flush_all),
        .valid_i      (ex_mem_valid),
        .ex_result_i  (ex_mem_result),
        .store_data_i (ex_mem_store_data),
        .is_load_i    (ex_mem_is_load),
        .is_store_i   (ex_mem_is_store),
        .mem_unsigned_i(ex_mem_mem_unsigned),
        .mem_size_i   (ex_mem_mem_size),
        .dresp_i      (dresp),
        .dreq_o       (dreq),
        .stall_o      (mem_stall),
        .mem_valid_o  (mem_valid),
        .store_event_valid_o(mem_store_event_valid),
        .store_event_addr_o(mem_store_event_addr),
        .store_event_data_o(mem_store_event_data),
        .store_event_mask_o(mem_store_event_mask),
        .mem_result_o (mem_result),
        .exc_valid_o  (mem_align_exc_valid),
        .exc_cause_o  (mem_align_exc_cause),
        .exc_tval_o   (mem_align_exc_tval)
    );

    // MMU fault capture: when mem_stage completes a mem op and MMU fault fired in this cycle,
    // attach fault info to this committing memory instruction.
    logic  mem_pf_valid;
    word_t mem_pf_cause;
    word_t mem_pf_tval;
    assign mem_pf_valid = mmu_fault_i && mem_valid && (ex_mem_is_load || ex_mem_is_store);
    assign mem_pf_cause = mmu_fault_is_store_i ? 64'd15 : 64'd13;
    assign mem_pf_tval  = mmu_fault_addr_i;
    assign mem_trap_valid = ex_mem_exc_valid || mem_align_exc_valid || mem_pf_valid;
    assign mem_trap_cause = ex_mem_exc_valid ? ex_mem_exc_cause :
                            mem_align_exc_valid ? mem_align_exc_cause : mem_pf_cause;
    assign mem_trap_tval  = ex_mem_exc_valid ? ex_mem_exc_tval :
                            mem_align_exc_valid ? mem_align_exc_tval : mem_pf_tval;

    mem_wb_reg u_mem_wb_reg(
        .clk         (clk),
        .reset       (reset),
        .flush_i     (flush_all),
        .in_valid_i  (mem_valid),
        .in_pc_i     (ex_mem_pc),
        .in_instr_i  (ex_mem_instr),
        .in_rd_i     (ex_mem_rd),
        .in_wen_i    (ex_mem_wen && !mem_trap_valid),
        .in_trap_i   (ex_mem_trap),
        .in_is_mem_i (ex_mem_is_load || ex_mem_is_store),
        .in_mem_addr_i(ex_mem_result),
        .in_result_i (mem_result),
        .in_store_valid_i(mem_store_event_valid && !mem_trap_valid),
        .in_store_addr_i(mem_store_event_addr),
        .in_store_data_i(mem_store_event_data),
        .in_store_mask_i(mem_store_event_mask),
        .in_csr_wen_i (ex_mem_csr_wen),
        .in_csr_addr_i(ex_mem_csr_addr),
        .in_csr_wdata_i(ex_mem_csr_wdata),
        .in_is_ecall_i(ex_mem_is_ecall),
        .in_is_mret_i(ex_mem_is_mret),
        .in_is_sret_i(ex_mem_is_sret),
        .in_mem_pf_valid_i(mem_trap_valid),
        .in_mem_pf_cause_i(mem_trap_cause),
        .in_mem_pf_tval_i (mem_trap_tval),
        .out_valid_o (mem_wb_valid),
        .out_pc_o    (mem_wb_pc),
        .out_instr_o (mem_wb_instr),
        .out_rd_o    (mem_wb_rd),
        .out_wen_o   (mem_wb_wen),
        .out_trap_o  (mem_wb_trap),
        .out_is_mem_o(mem_wb_is_mem),
        .out_mem_addr_o(mem_wb_mem_addr),
        .out_result_o(mem_wb_result),
        .out_store_valid_o(wb_store_event_valid),
        .out_store_addr_o(wb_store_event_addr),
        .out_store_data_o(wb_store_event_data),
        .out_store_mask_o(wb_store_event_mask),
        .out_csr_wen_o (mem_wb_csr_wen),
        .out_csr_addr_o(mem_wb_csr_addr),
        .out_csr_wdata_o(mem_wb_csr_wdata),
        .out_is_ecall_o(mem_wb_is_ecall),
        .out_is_mret_o(mem_wb_is_mret),
        .out_is_sret_o(mem_wb_is_sret),
        .out_mem_pf_valid_o(mem_wb_mem_pf_valid),
        .out_mem_pf_cause_o(mem_wb_mem_pf_cause),
        .out_mem_pf_tval_o (mem_wb_mem_pf_tval)
    );

    wb_stage u_wb_stage(
        .valid_i       (mem_wb_valid),
        .wen_i         (mem_wb_wen),
        .rd_i          (mem_wb_rd),
        .result_i      (mem_wb_result),
        .trap_i        (mem_wb_trap),
        .rf_wen_o      (wb_rf_wen),
        .rf_waddr_o    (wb_rf_waddr),
        .rf_wdata_o    (wb_rf_wdata),
        .commit_valid_o(wb_commit_valid),
        .commit_wen_o  (wb_commit_wen)
    );

    // WB-level trap arbitration
    logic  wb_trap_enter;       // any trap entering at this cycle
    logic  wb_sync_trap_enter;
    logic  wb_interrupt_enter;
    word_t wb_trap_cause;
    word_t wb_trap_tval;
    word_t wb_trap_pc;
    word_t wb_sync_trap_cause;
    word_t wb_sync_trap_tval;
    word_t wb_interrupt_cause;
    logic  wb_interrupt_pending;
    logic  wb_interrupt_enabled;
    logic  wb_csr_commit_wen;
    word_t wb_post_csr_mstatus;
    word_t wb_post_csr_mie;
    word_t wb_post_csr_mip;
    logic  wb_trap_to_s;
    logic  wb_mret_commit;
    logic  wb_sret_commit;

    always_comb begin
        wb_sync_trap_enter = 1'b0;
        wb_sync_trap_cause = '0;
        wb_sync_trap_tval  = '0;
        if (mem_wb_valid && mem_wb_is_ecall) begin
            wb_sync_trap_enter = 1'b1;
            // ECALL cause depends on privilege at the ECALL site (which is the current priv_mode_q)
            wb_sync_trap_cause = (priv_mode == 2'b00) ? 64'd8 :
                                 (priv_mode == 2'b01) ? 64'd9 : 64'd11;
            wb_sync_trap_tval  = '0;
        end else if (mem_wb_valid && mem_wb_mem_pf_valid) begin
            wb_sync_trap_enter = 1'b1;
            wb_sync_trap_cause = mem_wb_mem_pf_cause;
            wb_sync_trap_tval  = mem_wb_mem_pf_tval;
        end
    end

    assign wb_mret_commit = mem_wb_valid && mem_wb_is_mret;
    assign wb_sret_commit = mem_wb_valid && mem_wb_is_sret;
    assign wb_csr_commit_wen = mem_wb_valid && mem_wb_csr_wen;

    always_comb begin
        wb_post_csr_mstatus = csr_mstatus;
        wb_post_csr_mie     = csr_mie;
        wb_post_csr_mip     = csr_mip;

        if (wb_csr_commit_wen) begin
            unique case (mem_wb_csr_addr)
                CSR_MSTATUS: wb_post_csr_mstatus = (csr_mstatus & ~MSTATUS_MASK) | (mem_wb_csr_wdata & MSTATUS_MASK);
                CSR_SSTATUS: wb_post_csr_mstatus = (csr_mstatus & ~SSTATUS_MASK) | (mem_wb_csr_wdata & SSTATUS_MASK);
                CSR_MIE:     wb_post_csr_mie     = mem_wb_csr_wdata;
                CSR_SIE:     wb_post_csr_mie     = (csr_mie & ~csr_mideleg) | (mem_wb_csr_wdata & csr_mideleg);
                CSR_MIP:     wb_post_csr_mip     = (csr_mip & ~MIP_MASK) | (mem_wb_csr_wdata & MIP_MASK);
                CSR_SIP:     wb_post_csr_mip     = (csr_mip & ~(csr_mideleg & MIP_MASK)) |
                                                    (mem_wb_csr_wdata & csr_mideleg & MIP_MASK);
                default: ;
            endcase
        end

        wb_post_csr_mip[3]  = swint;
        wb_post_csr_mip[7]  = trint;
        wb_post_csr_mip[11] = exint;
    end

    assign wb_interrupt_enabled = (priv_mode != 2'b11) || wb_post_csr_mstatus[3];
    assign wb_interrupt_pending = wb_interrupt_enabled &&
        (((wb_post_csr_mip[11] && wb_post_csr_mie[11]) ||
          (wb_post_csr_mip[3]  && wb_post_csr_mie[3])  ||
          (wb_post_csr_mip[7]  && wb_post_csr_mie[7])));
    always_comb begin
        if (wb_post_csr_mip[11] && wb_post_csr_mie[11]) begin
            wb_interrupt_cause = 64'h8000_0000_0000_000b;
        end else if (wb_post_csr_mip[3] && wb_post_csr_mie[3]) begin
            wb_interrupt_cause = 64'h8000_0000_0000_0003;
        end else begin
            wb_interrupt_cause = 64'h8000_0000_0000_0007;
        end
    end
    assign wb_interrupt_enter = wb_commit_valid && !wb_sync_trap_enter && !wb_mret_commit && !wb_sret_commit && wb_interrupt_pending;
    assign wb_trap_enter = wb_sync_trap_enter || wb_interrupt_enter;
    assign wb_trap_cause = wb_interrupt_enter ? wb_interrupt_cause : wb_sync_trap_cause;
    assign wb_trap_tval  = wb_interrupt_enter ? '0 : wb_sync_trap_tval;
    assign wb_trap_pc    = wb_interrupt_enter ? (mem_wb_pc + 64'd4) : mem_wb_pc;
    assign wb_trap_to_s  = wb_sync_trap_enter && (priv_mode != 2'b11) && csr_medeleg[wb_sync_trap_cause[5:0]];
    assign wb_redirect_valid = (wb_sync_trap_enter && mem_wb_mem_pf_valid) || wb_interrupt_enter;
    assign wb_redirect_pc = wb_interrupt_enter ? csr_mtvec : (wb_trap_to_s ? csr_stvec : csr_mtvec);

    // CSR file: read at EX, write at WB so the architectural state advances
    // exactly when the CSR instruction commits (Difftest-friendly).
    csr_file u_csr_file(
        .clk        (clk),
        .reset      (reset),
        .raddr_i    (id_ex_csr_addr),
        .rdata_o    (ex_csr_rdata),
        .wen_i      (mem_wb_valid && mem_wb_csr_wen),
        .waddr_i    (mem_wb_csr_addr),
        .wdata_i    (mem_wb_csr_wdata),
        .trap_enter_i(wb_trap_enter),
        .trap_pc_i   (wb_trap_pc),
        .trap_cause_i(wb_trap_cause),
        .trap_tval_i (wb_trap_tval),
        .trap_priv_i (priv_mode),
        .trap_to_s_i (wb_trap_to_s),
        .mret_i      (wb_mret_commit),
        .sret_i      (wb_sret_commit),
        .trint_i     (trint),
        .swint_i     (swint),
        .exint_i     (exint),
        .mstatus_o  (csr_mstatus),
        .mtvec_o    (csr_mtvec),
        .mip_o      (csr_mip),
        .mie_o      (csr_mie),
        .mscratch_o (csr_mscratch),
        .mcause_o   (csr_mcause),
        .mtval_o    (csr_mtval),
        .mepc_o     (csr_mepc),
        .mcycle_o   (csr_mcycle),
        .mhartid_o  (csr_mhartid),
        .satp_o     (csr_satp),
        .medeleg_o  (csr_medeleg),
        .mideleg_o  (csr_mideleg),
        .stvec_o    (csr_stvec),
        .sscratch_o (csr_sscratch),
        .sepc_o     (csr_sepc),
        .scause_o   (csr_scause),
        .stval_o    (csr_stval),
        .sie_o      (csr_sie),
        .sip_o      (csr_sip),
        .sstatus_o  (csr_sstatus),
        .priv_mode_o(priv_mode)
    );

    assign satp_o = csr_satp;
    assign priv_mode_o = mmu_priv_mode_q;

    // Sticky debug latches: once set, stay set until reset.
    // bit 0: satp ever written (csr_satp non-zero)
    // bit 1: ever committed MRET
    // bit 2: ever committed ECALL
    // bit 3: priv_mode ever entered U mode
    logic [3:0] dbg_sticky_q;
    always_ff @(posedge clk) begin
        if (reset) begin
            dbg_sticky_q <= 4'b0;
        end else begin
            if (csr_satp != 64'd0)                  dbg_sticky_q[0] <= 1'b1;
            if (mem_wb_valid && mem_wb_is_mret)     dbg_sticky_q[1] <= 1'b1;
            if (mem_wb_valid && mem_wb_is_ecall)    dbg_sticky_q[2] <= 1'b1;
            if (priv_mode == 2'b00)                 dbg_sticky_q[3] <= 1'b1;
        end
    end
    assign dbg_o = dbg_sticky_q;

    `UNUSED_OK({trint, swint, exint, mem_store_event_valid, mem_store_event_addr, mem_store_event_data, mem_store_event_mask, ex_mem_is_csr});

    // Update commit/trap state after the WB stage becomes architecturally visible.
    always_ff @(posedge clk) begin
        if (reset) begin
            halt_q         <= 1'b0;
            stop_fetch_q   <= 1'b0;
            cycle_cnt_q    <= '0;
            instr_cnt_q    <= '0;
            trap_valid_q   <= 1'b0;
            trap_code_q    <= '0;
            trap_pc_q      <= '0;
            commit_valid_q <= 1'b0;
            commit_pc_q    <= '0;
            commit_instr_q <= '0;
            commit_wen_q   <= 1'b0;
            commit_wdest_q <= '0;
            commit_wdata_q <= '0;
            commit_skip_q  <= 1'b0;
            diff_store_event_valid    <= 1'b0;
            diff_store_event_addr     <= '0;
            diff_store_event_data     <= '0;
            diff_store_event_mask     <= '0;
            diff_store_event_valid_d1 <= 1'b0;
            diff_store_event_addr_d1  <= '0;
            diff_store_event_data_d1  <= '0;
            diff_store_event_mask_d1  <= '0;
            mmu_priv_mode_q <= 2'b11;
            trap_window_skip_q <= 1'b0;
        end else begin
            cycle_cnt_q    <= cycle_cnt_q + 64'd1;
            trap_valid_q   <= 1'b0;
            commit_valid_q <= wb_commit_valid;
            commit_pc_q    <= mem_wb_pc;
            commit_instr_q <= mem_wb_instr;
            commit_wen_q   <= wb_commit_wen;
            commit_wdest_q <= mem_wb_rd;
            commit_wdata_q <= mem_wb_result;
            commit_skip_q  <= (mem_wb_is_mem && (mem_wb_mem_addr[31] == 1'b0)) || commit_load_bss || commit_user_skip;
            diff_store_event_valid    <= wb_store_event_valid && (wb_store_event_addr[31] == 1'b1) && !commit_user_skip;
            diff_store_event_addr     <= wb_store_event_addr;
            diff_store_event_data     <= wb_store_event_data;
            diff_store_event_mask     <= wb_store_event_mask;
            diff_store_event_valid_d1 <= diff_store_event_valid;
            diff_store_event_addr_d1  <= diff_store_event_addr;
            diff_store_event_data_d1  <= diff_store_event_data;
            diff_store_event_mask_d1  <= diff_store_event_mask;

            if (wb_redirect_valid) begin
                mmu_priv_mode_q <= (wb_sync_trap_enter && wb_trap_to_s) ? 2'b01 : 2'b11;
            end else if (ex_redirect_fire && ex_exc_valid) begin
                mmu_priv_mode_q <= 2'b11;
            end else if (ex_redirect_fire && id_ex_is_ecall) begin
                // ECALL: jump to mtvec or stvec; new priv = M or S
                mmu_priv_mode_q <= ex_trap_to_s ? 2'b01 : 2'b11;
            end else if (ex_redirect_fire && id_ex_is_mret) begin
                mmu_priv_mode_q <= csr_mstatus[12:11];
            end else if (ex_redirect_fire && id_ex_is_sret) begin
                mmu_priv_mode_q <= {1'b0, csr_mstatus[8]};  // SPP
            end

            if (mem_wb_valid && mem_wb_is_ecall) begin
                trap_window_skip_q <= 1'b1;
            end else if (mem_wb_valid && (mem_wb_is_mret || mem_wb_is_sret)) begin
                trap_window_skip_q <= 1'b0;
            end

            if (wb_commit_valid) begin
                instr_cnt_q <= instr_cnt_q + 64'd1;
            end

            if (if_id_valid && id_trap) begin
                stop_fetch_q <= 1'b1;
            end

            if (mem_wb_valid && mem_wb_trap) begin
                trap_valid_q <= 1'b1;
                trap_code_q  <= gpr[10][2:0];
                trap_pc_q    <= mem_wb_pc;
                halt_q       <= 1'b1;
            end
        end
    end

`ifdef VERILATOR
    DifftestInstrCommit DifftestInstrCommit(
        .clock              (clk),
        .coreid             (csr_mhartid[7:0]),
        .index              (0),
        .valid              (commit_valid_q),
        .pc                 (commit_pc_q),
        .instr              (commit_instr_q),
        .skip               (commit_skip_q),
        .isRVC              (0),
        .scFailed           (0),
        .wen                (commit_wen_q),
        .wdest              ({3'b0, commit_wdest_q}),
        .wdata              (commit_wdata_q)
    );

    DifftestStoreEvent DifftestStoreEvent(
        .clock              (clk),
        .coreid             (0),
        .index              (0),
        .valid              (diff_store_event_valid_d1),
        .storeAddr          (diff_store_event_addr_d1),
        .storeData          (diff_store_event_data_d1),
        .storeMask          (diff_store_event_mask_d1)
    );

    DifftestArchIntRegState DifftestArchIntRegState(
        .clock              (clk),
        .coreid             (csr_mhartid[7:0]),
        .gpr_0              (gpr[0]),
        .gpr_1              (gpr[1]),
        .gpr_2              (gpr[2]),
        .gpr_3              (gpr[3]),
        .gpr_4              (gpr[4]),
        .gpr_5              (gpr[5]),
        .gpr_6              (gpr[6]),
        .gpr_7              (gpr[7]),
        .gpr_8              (gpr[8]),
        .gpr_9              (gpr[9]),
        .gpr_10             (gpr[10]),
        .gpr_11             (gpr[11]),
        .gpr_12             (gpr[12]),
        .gpr_13             (gpr[13]),
        .gpr_14             (gpr[14]),
        .gpr_15             (gpr[15]),
        .gpr_16             (gpr[16]),
        .gpr_17             (gpr[17]),
        .gpr_18             (gpr[18]),
        .gpr_19             (gpr[19]),
        .gpr_20             (gpr[20]),
        .gpr_21             (gpr[21]),
        .gpr_22             (gpr[22]),
        .gpr_23             (gpr[23]),
        .gpr_24             (gpr[24]),
        .gpr_25             (gpr[25]),
        .gpr_26             (gpr[26]),
        .gpr_27             (gpr[27]),
        .gpr_28             (gpr[28]),
        .gpr_29             (gpr[29]),
        .gpr_30             (gpr[30]),
        .gpr_31             (gpr[31])
    );

    DifftestTrapEvent DifftestTrapEvent(
        .clock              (clk),
        .coreid             (csr_mhartid[7:0]),
        .valid              (trap_valid_q),
        .code               (trap_code_q),
        .pc                 (trap_pc_q),
        .cycleCnt           (cycle_cnt_q),
        .instrCnt           (instr_cnt_q)
    );

	DifftestCSRState DifftestCSRState(
		.clock              (clk),
		.coreid             (csr_mhartid[7:0]),
		.priviledgeMode     (priv_mode),
		.mstatus            (csr_mstatus),
		.sstatus            (csr_sstatus),
		.mepc               (csr_mepc),
		.sepc               (csr_sepc),
		.mtval              (csr_mtval),
		.stval              (csr_stval),
		.mtvec              (csr_mtvec),
		.stvec              (csr_stvec),
		.mcause             (csr_mcause),
		.scause             (csr_scause),
		.satp               (csr_satp),
		.mip                (csr_mip),
		.mie                (csr_mie),
		.mscratch           (csr_mscratch),
		.sscratch           (csr_sscratch),
		.mideleg            (csr_mideleg),
		.medeleg            (csr_medeleg)
	);
`endif
endmodule

`endif
