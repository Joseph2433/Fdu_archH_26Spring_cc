`ifndef __MEM_STAGE_SV
`define __MEM_STAGE_SV

// MEM stage: executes Lab2 load/store accesses and keeps request stable until completion.
module mem_stage import common::*;(
    input  logic      clk,
    input  logic      reset,
    input  logic      flush_i,
    input  logic      valid_i,
    input  word_t     ex_result_i,
    input  word_t     store_data_i,
    input  logic      is_load_i,
    input  logic      is_store_i,
    input  logic      mem_unsigned_i,
    input  msize_t    mem_size_i,
    input  dbus_resp_t dresp_i,
    output dbus_req_t dreq_o,
    output logic      stall_o,
    output logic      mem_valid_o,
    output logic      store_event_valid_o,
    output word_t     store_event_addr_o,
    output word_t     store_event_data_o,
    output u8         store_event_mask_o,
    output word_t     mem_result_o
);
    logic mem_access;
    logic completed_q;
    u3    byte_off;
    u6    shift_bits;
    u8    base_strobe;
    u8    write_strobe;
    word_t shifted_store_data;
    word_t masked_store_data;
    word_t store_data_mask64;
    word_t shifted_load_data;
    word_t load_result;
    integer i;

    assign mem_access = is_load_i || is_store_i;
    assign byte_off   = ex_result_i[2:0];
    assign shift_bits = {byte_off, 3'b000};

    always_comb begin
        unique case (mem_size_i)
            MSIZE1: base_strobe = 8'b0000_0001;
            MSIZE2: base_strobe = 8'b0000_0011;
            MSIZE4: base_strobe = 8'b0000_1111;
            default: base_strobe = 8'b1111_1111;
        endcase
    end

    assign write_strobe       = base_strobe << byte_off;
    assign shifted_store_data = store_data_i << shift_bits;
    always_comb begin
        store_data_mask64 = '0;
        for (i = 0; i < 8; i = i + 1) begin
            store_data_mask64[i*8 +: 8] = {8{write_strobe[i]}};
        end
    end
    assign masked_store_data  = shifted_store_data & store_data_mask64;
    assign shifted_load_data  = dresp_i.data >> shift_bits;

    always_comb begin
        unique case (mem_size_i)
            MSIZE1: load_result = mem_unsigned_i ? {{56{1'b0}}, shifted_load_data[7:0]} : {{56{shifted_load_data[7]}}, shifted_load_data[7:0]};
            MSIZE2: load_result = mem_unsigned_i ? {{48{1'b0}}, shifted_load_data[15:0]} : {{48{shifted_load_data[15]}}, shifted_load_data[15:0]};
            MSIZE4: load_result = mem_unsigned_i ? {{32{1'b0}}, shifted_load_data[31:0]} : {{32{shifted_load_data[31]}}, shifted_load_data[31:0]};
            default: load_result = shifted_load_data;
        endcase
    end

    assign dreq_o.valid  = valid_i && mem_access && !completed_q;
    assign dreq_o.addr   = ex_result_i;
    assign dreq_o.size   = mem_size_i;
    assign dreq_o.strobe = is_store_i ? write_strobe : 8'b0;
    assign dreq_o.data   = is_store_i ? shifted_store_data : '0;

    // Keep the memory stage frozen until current memory op gets a response.
    assign stall_o = valid_i && mem_access && !completed_q;

    assign mem_valid_o = mem_access ? (valid_i && !completed_q && dresp_i.data_ok) : valid_i;
    assign store_event_valid_o = mem_valid_o && is_store_i;
    assign store_event_addr_o  = {ex_result_i[63:3], 3'b000};
    assign store_event_data_o  = masked_store_data;
    assign store_event_mask_o  = write_strobe;
    assign mem_result_o = is_load_i ? load_result : ex_result_i;

    always_ff @(posedge clk) begin
        if (reset || flush_i) begin
            completed_q <= 1'b0;
        end else if (completed_q) begin
            completed_q <= 1'b0;
        end else if (valid_i && mem_access && dresp_i.data_ok) begin
            completed_q <= 1'b1;
        end else begin
            completed_q <= 1'b0;
        end
    end
endmodule

`endif
