`ifndef __EX_STAGE_SV
`define __EX_STAGE_SV

// EX stage: integer ALU for the Lab1 arithmetic/logic subset.
module ex_stage import common::*;(
    input  logic  clk,
    input  logic  reset,
    input  logic  flush_i,
    input  logic  valid_i,
    input  word_t pc_i,
    input  word_t op1_i,
    input  word_t op2_i,
    input  word_t imm_i,
    input  logic  use_imm_i,
    input  logic  is_word_i,
    input  u5     alu_op_i,
    input  logic  is_branch_i,
    input  logic  is_jal_i,
    input  logic  is_jalr_i,
    input  u3     branch_funct3_i,
    input  logic  ex_accept_i,
    output word_t result_o,
    output logic  result_valid_o,
    output logic  stall_o,
    output logic  redirect_valid_o,
    output word_t redirect_pc_o
);
    word_t rhs;
    word_t full_res;
    word_t comb_result;
    u32    low32;
    logic  branch_taken;
    logic  is_mdu;
    logic  is_mul;
    logic  is_div;

    typedef enum logic [2:0] {
        MDU_IDLE   = 3'b000,
        MDU_MUL    = 3'b001,
        MDU_DIV    = 3'b010,
        MDU_FINISH = 3'b011,
        MDU_DONE   = 3'b100
    } mdu_state_t;

    mdu_state_t mdu_state_q;
    (* max_fanout = 50 *) logic  mdu_busy_q;
    u7     mdu_cnt_q;
    u7     mdu_target_q;
    word_t mdu_res_buffer_q;
    logic  mdu_is_mul_saved_q;

    // MUL datapath registers.
    logic [127:0] mul_acc_q;
    logic [127:0] mul_mcand_q;
    logic [63:0]  mul_mult_q;
    logic         mul_neg_q;
    logic         mul_hi_q;
    logic         mul_word_q;

    // DIV datapath registers.
    logic [63:0]  div_dividend_q;
    logic [63:0]  div_divisor_q;
    logic [64:0]  div_rem_q;
    logic [63:0]  div_quot_q;
    logic         div_signed_q;
    logic         div_is_rem_q;
    logic         div_word_q;
    logic         div_quot_neg_q;
    logic         div_rem_neg_q;
    logic         div_by_zero_q;
    logic         div_overflow_q;
    logic [63:0]  div_dividend_orig_q;

    localparam u5 ALU_ADD  = 5'd0;
    localparam u5 ALU_SUB  = 5'd1;
    localparam u5 ALU_AND  = 5'd2;
    localparam u5 ALU_OR   = 5'd3;
    localparam u5 ALU_XOR  = 5'd4;
    localparam u5 ALU_SLL  = 5'd5;
    localparam u5 ALU_SRL  = 5'd6;
    localparam u5 ALU_SRA  = 5'd7;
    localparam u5 ALU_SLT  = 5'd8;
    localparam u5 ALU_SLTU = 5'd9;
    localparam u5 ALU_MUL  = 5'd10;
    localparam u5 ALU_MULH = 5'd11;
    localparam u5 ALU_MULHSU = 5'd12;
    localparam u5 ALU_MULHU = 5'd13;
    localparam u5 ALU_DIV  = 5'd14;
    localparam u5 ALU_DIVU = 5'd15;
    localparam u5 ALU_REM  = 5'd16;
    localparam u5 ALU_REMU = 5'd17;

    localparam logic [63:0] I64_MIN = 64'h8000_0000_0000_0000;
    localparam logic [31:0] I32_MIN = 32'h8000_0000;

    function automatic logic [63:0] abs64(
        input logic [63:0] v,
        input logic signed_mode,
        input logic is_word,
        output logic neg
    );
        logic [63:0] ext_v;
        begin
            if (is_word) begin
                ext_v = {{32{v[31]}}, v[31:0]};
                neg = signed_mode && ext_v[31];
            end else begin
                ext_v = v;
                neg = signed_mode && ext_v[63];
            end

            if (neg) begin
                abs64 = ~ext_v + 64'd1;
            end else begin
                abs64 = ext_v;
            end
        end
    endfunction

    function automatic logic [63:0] div_word_signed_ext(input logic [63:0] v);
        begin
            div_word_signed_ext = {{32{v[31]}}, v[31:0]};
        end
    endfunction

    function automatic logic [127:0] mul_partial_2bit(
        input logic [127:0] x,
        input logic [1:0] bits
    );
        logic [127:0] p;
        begin
            p = 128'd0;
            unique case (bits)
                2'b00: p = 128'd0;
                2'b01: p = x;
                2'b10: p = x << 1;
                2'b11: p = x + (x << 1);
                default: p = 128'd0;
            endcase
            mul_partial_2bit = p;
        end
    endfunction

    // Immediate instructions reuse the same ALU datapath as register-register ops.
    assign rhs = use_imm_i ? imm_i : op2_i;
    assign is_mdu = (alu_op_i >= ALU_MUL) && (alu_op_i <= ALU_REMU);
    assign is_mul = (alu_op_i >= ALU_MUL) && (alu_op_i <= ALU_MULHU);
    assign is_div = (alu_op_i >= ALU_DIV) && (alu_op_i <= ALU_REMU);

    always_ff @(posedge clk) begin
        if (reset || flush_i) begin
            mdu_state_q <= MDU_IDLE;
            mdu_busy_q <= 1'b0;
            mdu_cnt_q <= '0;
            mdu_target_q <= '0;
            mdu_res_buffer_q <= '0;
            mdu_is_mul_saved_q <= 1'b0;
            mul_acc_q <= '0;
            mul_mcand_q <= '0;
            mul_mult_q <= '0;
            mul_neg_q <= 1'b0;
            mul_hi_q <= 1'b0;
            mul_word_q <= 1'b0;
            div_dividend_q <= '0;
            div_divisor_q <= '0;
            div_rem_q <= '0;
            div_quot_q <= '0;
            div_signed_q <= 1'b0;
            div_is_rem_q <= 1'b0;
            div_word_q <= 1'b0;
            div_quot_neg_q <= 1'b0;
            div_rem_neg_q <= 1'b0;
            div_by_zero_q <= 1'b0;
            div_overflow_q <= 1'b0;
            div_dividend_orig_q <= '0;
        end else begin
            case (mdu_state_q)
                MDU_IDLE: begin
                    if (valid_i && is_mdu && !mdu_busy_q) begin
                        logic op1_neg;
                        logic rhs_neg;
                        logic mul_lhs_signed;
                        logic mul_rhs_signed;
                        logic div_signed;
                        logic div_op1_neg;
                        logic div_rhs_neg;
                        logic [63:0] div_op1_ext;
                        logic [63:0] div_rhs_ext;

                        mdu_busy_q <= 1'b1;
                        mdu_cnt_q <= 7'd1;
                        mdu_is_mul_saved_q <= is_mul;

                        if (is_mul) begin
                            mdu_state_q <= MDU_MUL;
                            mdu_target_q <= 7'd32;
                            mul_hi_q <= (alu_op_i != ALU_MUL);
                            mul_word_q <= is_word_i;

                            mul_lhs_signed = (alu_op_i == ALU_MUL) || (alu_op_i == ALU_MULH) || (alu_op_i == ALU_MULHSU);
                            mul_rhs_signed = (alu_op_i == ALU_MUL) || (alu_op_i == ALU_MULH);

                            mul_acc_q <= 128'd0;
                            mul_mcand_q <= {64'd0, abs64(is_word_i ? div_word_signed_ext(op1_i) : op1_i, mul_lhs_signed, 1'b0, op1_neg)};
                            mul_mult_q <= abs64(is_word_i ? div_word_signed_ext(rhs) : rhs, mul_rhs_signed, 1'b0, rhs_neg);
                            mul_neg_q <= op1_neg ^ rhs_neg;
                        end else if (is_div) begin
                            mdu_state_q <= MDU_DIV;
                            mdu_target_q <= 7'd64;

                            div_signed = (alu_op_i == ALU_DIV) || (alu_op_i == ALU_REM);
                            div_signed_q <= div_signed;
                            div_is_rem_q <= (alu_op_i == ALU_REM) || (alu_op_i == ALU_REMU);
                            div_word_q <= is_word_i;

                            if (is_word_i) begin
                                div_op1_ext = div_signed ? div_word_signed_ext(op1_i) : {32'd0, op1_i[31:0]};
                                div_rhs_ext = div_signed ? div_word_signed_ext(rhs) : {32'd0, rhs[31:0]};
                                div_by_zero_q <= (rhs[31:0] == 32'd0);
                                div_overflow_q <= div_signed && (op1_i[31:0] == I32_MIN) && (rhs[31:0] == 32'hffff_ffff);
                            end else begin
                                div_op1_ext = op1_i;
                                div_rhs_ext = rhs;
                                div_by_zero_q <= (rhs == 64'd0);
                                div_overflow_q <= div_signed && (op1_i == I64_MIN) && (rhs == 64'hffff_ffff_ffff_ffff);
                            end

                            div_dividend_q <= abs64(div_op1_ext, div_signed, 1'b0, div_op1_neg);
                            div_divisor_q <= abs64(div_rhs_ext, div_signed, 1'b0, div_rhs_neg);
                            div_rem_q <= 65'd0;
                            div_quot_q <= 64'd0;
                            div_quot_neg_q <= div_signed && (div_op1_neg ^ div_rhs_neg);
                            div_rem_neg_q <= div_signed && div_op1_neg;
                            div_dividend_orig_q <= div_op1_ext;
                        end
                    end
                end

                MDU_MUL: begin
                    logic [127:0] mul_partial;
                    logic [127:0] mul_acc_next;

                    mul_partial = mul_partial_2bit(mul_mcand_q, mul_mult_q[1:0]);
                    mul_acc_next = mul_acc_q + mul_partial;

                    mul_acc_q <= mul_acc_next;
                    mul_mcand_q <= mul_mcand_q << 2;
                    mul_mult_q <= mul_mult_q >> 2;

                    if (mdu_cnt_q == mdu_target_q) begin
                        mdu_state_q <= MDU_FINISH;
                    end else begin
                        mdu_cnt_q <= mdu_cnt_q + 7'd1;
                    end
                end

                MDU_DIV: begin
                    logic [64:0] rem_shift;
                    logic [64:0] rem_sub;
                    logic [64:0] rem_nxt;
                    logic [63:0] quot_nxt;
                    logic ge_div;
                    rem_nxt = div_rem_q;
                    quot_nxt = div_quot_q;

                    if (!div_by_zero_q && !div_overflow_q) begin
                        rem_shift = {div_rem_q[63:0], div_dividend_q[63]};
                        rem_sub = rem_shift - {1'b0, div_divisor_q};
                        ge_div = !rem_sub[64];

                        rem_nxt = ge_div ? rem_sub : rem_shift;
                        quot_nxt = {div_quot_q[62:0], ge_div};
                        div_rem_q <= rem_nxt;
                        div_quot_q <= quot_nxt;
                        div_dividend_q <= {div_dividend_q[62:0], 1'b0};
                    end

                    if (mdu_cnt_q == mdu_target_q) begin
                        mdu_state_q <= MDU_FINISH;
                    end else begin
                        mdu_cnt_q <= mdu_cnt_q + 7'd1;
                    end
                end

                MDU_FINISH: begin
                    if (mdu_is_mul_saved_q) begin
                        logic [127:0] mul_prod;
                        mul_prod = mul_acc_q;
                        if (mul_neg_q) begin
                            mul_prod = ~mul_prod + 128'd1;
                        end

                        if (mul_word_q) begin
                            mdu_res_buffer_q <= {{32{mul_prod[31]}}, mul_prod[31:0]};
                        end else if (mul_hi_q) begin
                            mdu_res_buffer_q <= mul_prod[127:64];
                        end else begin
                            mdu_res_buffer_q <= mul_prod[63:0];
                        end
                    end else begin
                        logic [63:0] q_fin;
                        logic [63:0] r_fin;
                        logic [63:0] div_res;

                        q_fin = div_quot_q;
                        r_fin = div_rem_q[63:0];
                        if (div_quot_neg_q) begin
                            q_fin = ~q_fin + 64'd1;
                        end
                        if (div_rem_neg_q) begin
                            r_fin = ~r_fin + 64'd1;
                        end

                        if (div_by_zero_q) begin
                            div_res = div_is_rem_q ? div_dividend_orig_q : 64'hffff_ffff_ffff_ffff;
                        end else if (div_overflow_q) begin
                            if (div_is_rem_q) begin
                                div_res = 64'd0;
                            end else if (div_word_q) begin
                                div_res = div_word_signed_ext({32'd0, I32_MIN});
                            end else begin
                                div_res = I64_MIN;
                            end
                        end else begin
                            div_res = div_is_rem_q ? r_fin : q_fin;
                        end

                        if (div_word_q) begin
                            mdu_res_buffer_q <= {{32{div_res[31]}}, div_res[31:0]};
                        end else begin
                            mdu_res_buffer_q <= div_res;
                        end
                    end

                    mdu_state_q <= MDU_DONE;
                end

                MDU_DONE: begin
                    if (ex_accept_i) begin
                        mdu_busy_q <= 1'b0;
                        mdu_state_q <= MDU_IDLE;
                    end
                end

                default: begin
                    mdu_state_q <= MDU_IDLE;
                    mdu_busy_q <= 1'b0;
                end
            endcase
        end
    end

    always_comb begin
        low32    = '0;
        full_res = '0;
        comb_result = '0;
        result_o = '0;
        result_valid_o = 1'b0;
        stall_o = 1'b0;
        branch_taken = 1'b0;
        redirect_valid_o = 1'b0;
        redirect_pc_o = '0;

        unique case (alu_op_i)
            ALU_ADD:  full_res = op1_i + rhs;
            ALU_SUB:  full_res = op1_i - rhs;
            ALU_AND:  full_res = op1_i & rhs;
            ALU_OR:   full_res = op1_i | rhs;
            ALU_XOR:  full_res = op1_i ^ rhs;
            ALU_SLL:  full_res = op1_i << rhs[5:0];
            ALU_SRL:  full_res = op1_i >> rhs[5:0];
            ALU_SRA:  full_res = $signed(op1_i) >>> rhs[5:0];
            ALU_SLT:  full_res = {{63{1'b0}}, ($signed(op1_i) < $signed(rhs))};
            ALU_SLTU: full_res = {{63{1'b0}}, (op1_i < rhs)};
            default: full_res = '0;
        endcase

        if (is_word_i) begin
            unique case (alu_op_i)
                ALU_ADD: low32 = op1_i[31:0] + rhs[31:0];
                ALU_SUB: low32 = op1_i[31:0] - rhs[31:0];
                ALU_SLL: low32 = op1_i[31:0] << rhs[4:0];
                ALU_SRL: low32 = op1_i[31:0] >> rhs[4:0];
                ALU_SRA: low32 = $signed(op1_i[31:0]) >>> rhs[4:0];
                default: low32 = full_res[31:0];
            endcase
            comb_result = {{32{low32[31]}}, low32};
        end else begin
            comb_result = full_res;
        end

        if (!is_mdu) begin
            result_o = comb_result;
            result_valid_o = valid_i;
        end else begin
            result_o = mdu_res_buffer_q;
            result_valid_o = valid_i && (mdu_state_q == MDU_DONE);
            stall_o = valid_i && (!mdu_busy_q || !((mdu_state_q == MDU_DONE) && ex_accept_i));
        end

        if (is_branch_i) begin
            unique case (branch_funct3_i)
                3'b000: branch_taken = (op1_i == op2_i); // beq
                3'b001: branch_taken = (op1_i != op2_i); // bne
                3'b100: branch_taken = ($signed(op1_i) < $signed(op2_i)); // blt
                3'b101: branch_taken = ($signed(op1_i) >= $signed(op2_i)); // bge
                3'b110: branch_taken = (op1_i < op2_i); // bltu
                3'b111: branch_taken = (op1_i >= op2_i); // bgeu
                default: branch_taken = 1'b0;
            endcase
            if (valid_i && branch_taken) begin
                redirect_valid_o = 1'b1;
                redirect_pc_o = pc_i + imm_i;
            end
        end else if (is_jal_i && valid_i) begin
            redirect_valid_o = 1'b1;
            redirect_pc_o = pc_i + imm_i;
            result_o = pc_i + 64'd4;
        end else if (is_jalr_i && valid_i) begin
            redirect_valid_o = 1'b1;
            redirect_pc_o = (op1_i + imm_i) & ~64'd1;
            result_o = pc_i + 64'd4;
        end
    end

    `UNUSED_OK({mdu_target_q, is_mul, is_div});
endmodule

`endif
