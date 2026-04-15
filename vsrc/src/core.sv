`ifndef __CORE_SV
`define __CORE_SV

`ifdef VERILATOR
`include "include/common.sv"
`endif



module core import common::*;(
    input  logic       clk,
    input  logic       reset,
    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp,
    input  logic       trint,
    input  logic       swint,
    input  logic       exint
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

    word_t ex_result;
    logic  ex_result_valid;
    logic  ex_stall;
    logic  front_stall;
    logic  ex_redirect_valid;
    logic  ex_redirect_fire;
    word_t ex_redirect_pc;

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

    logic  mem_valid;
    word_t mem_result;
    logic  mem_stall;
    logic  mem_store_event_valid;
    word_t mem_store_event_addr;
    word_t mem_store_event_data;
    u8     mem_store_event_mask;
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

    logic  wb_rf_wen;
    u5     wb_rf_waddr;
    word_t wb_rf_wdata;
    logic  wb_commit_valid;
    logic  wb_commit_wen;
    logic  commit_skip_q;
    logic  load_use_hazard;

    logic flush_all;

    // Trap commits flush the pipeline once they reach WB.
    assign flush_all = reset || trap_valid_q;
    assign front_stall = mem_stall || ex_stall;
    assign ex_redirect_fire = ex_redirect_valid && !mem_stall;
    assign load_use_hazard = !front_stall && if_id_valid && id_ex_valid && id_ex_is_load && (id_ex_rd != '0) &&
        ((id_rs1_used && (id_rs1 == id_ex_rd)) || (id_rs2_used && (id_rs2 == id_ex_rd)));

    // 5-stage datapath: IF -> ID -> EX -> MEM -> WB.
    if_stage u_if_stage(
        .clk          (clk),
        .reset        (reset),
        .halt_i       (halt_q || stop_fetch_q || front_stall || load_use_hazard),
        .redirect_i   (ex_redirect_fire),
        .redirect_pc_i(ex_redirect_pc),
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
        .flush_i    (flush_all || stop_fetch_q || ex_redirect_fire),
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
        .op2_o            (id_op2)
    );

    id_ex_reg u_id_ex_reg(
        .clk          (clk),
        .reset        (reset),
        .flush_i      (flush_all || ex_redirect_fire || load_use_hazard),
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
        .out_op2_o    (id_ex_op2)
    );

    ex_stage u_ex_stage(
        .clk       (clk),
        .reset     (reset),
        .flush_i   (flush_all),
        .valid_i   (id_ex_valid),
        .pc_i      (id_ex_pc),
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
        .result_o  (ex_result),
        .result_valid_o(ex_result_valid),
        .stall_o   (ex_stall),
        .redirect_valid_o(ex_redirect_valid),
        .redirect_pc_o(ex_redirect_pc)
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
        .in_wen_i    (id_ex_wen),
        .in_trap_i   (id_ex_trap),
        .in_is_load_i(id_ex_is_load),
        .in_is_store_i(id_ex_is_store),
        .in_mem_unsigned_i(id_ex_mem_unsigned),
        .in_mem_size_i(id_ex_mem_size),
        .in_store_data_i(id_ex_op2),
        .in_result_i (ex_result),
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
        .out_result_o(ex_mem_result)
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
        .mem_result_o (mem_result)
    );

    mem_wb_reg u_mem_wb_reg(
        .clk         (clk),
        .reset       (reset),
        .flush_i     (flush_all),
        .in_valid_i  (mem_valid),
        .in_pc_i     (ex_mem_pc),
        .in_instr_i  (ex_mem_instr),
        .in_rd_i     (ex_mem_rd),
        .in_wen_i    (ex_mem_wen),
        .in_trap_i   (ex_mem_trap),
        .in_is_mem_i (ex_mem_is_load || ex_mem_is_store),
        .in_mem_addr_i(ex_mem_result),
        .in_result_i (mem_result),
        .in_store_valid_i(mem_store_event_valid),
        .in_store_addr_i(mem_store_event_addr),
        .in_store_data_i(mem_store_event_data),
        .in_store_mask_i(mem_store_event_mask),
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
        .out_store_mask_o(wb_store_event_mask)
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

    `UNUSED_OK({trint, swint, exint, mem_store_event_valid, mem_store_event_addr, mem_store_event_data, mem_store_event_mask});

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
        end else begin
            cycle_cnt_q    <= cycle_cnt_q + 64'd1;
            trap_valid_q   <= 1'b0;
            commit_valid_q <= wb_commit_valid;
            commit_pc_q    <= mem_wb_pc;
            commit_instr_q <= mem_wb_instr;
            commit_wen_q   <= wb_commit_wen;
            commit_wdest_q <= mem_wb_rd;
            commit_wdata_q <= mem_wb_result;
            commit_skip_q  <= mem_wb_is_mem && (mem_wb_mem_addr[31] == 1'b0);
            diff_store_event_valid    <= wb_store_event_valid && (wb_store_event_addr[31] == 1'b1);
            diff_store_event_addr     <= wb_store_event_addr;
            diff_store_event_data     <= wb_store_event_data;
            diff_store_event_mask     <= wb_store_event_mask;
            diff_store_event_valid_d1 <= diff_store_event_valid;
            diff_store_event_addr_d1  <= diff_store_event_addr;
            diff_store_event_data_d1  <= diff_store_event_data;
            diff_store_event_mask_d1  <= diff_store_event_mask;

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
        .coreid             (0),
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
        .coreid             (0),
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
        .coreid             (0),
        .valid              (trap_valid_q),
        .code               (trap_code_q),
        .pc                 (trap_pc_q),
        .cycleCnt           (cycle_cnt_q),
        .instrCnt           (instr_cnt_q)
    );

    DifftestCSRState DifftestCSRState(
        .clock              (clk),
        .coreid             (0),
        .priviledgeMode     (3),
        .mstatus            (0),
        .sstatus            (0),
        .mepc               (0),
        .sepc               (0),
        .mtval              (0),
        .stval              (0),
        .mtvec              (0),
        .stvec              (0),
        .mcause             (0),
        .scause             (0),
        .satp               (0),
        .mip                (0),
        .mie                (0),
        .mscratch           (0),
        .sscratch           (0),
        .mideleg            (0),
        .medeleg            (0)
    );
`endif
endmodule

`endif
