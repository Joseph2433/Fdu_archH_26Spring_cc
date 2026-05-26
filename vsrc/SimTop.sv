`ifdef VERILATOR
`include "include/common.sv"
`include "src/core.sv"
`include "util/IBusToCBus.sv"
`include "util/DBusToCBus.sv"
`include "util/CBusArbiter.sv"
`include "src/mmu/cbus_mmu.sv"

module SimTop import common::*;(
  input         clock,
  input         reset,
  input  [63:0] io_logCtrl_log_begin,
  input  [63:0] io_logCtrl_log_end,
  input  [63:0] io_logCtrl_log_level,
  input         io_perfInfo_clean,
  input         io_perfInfo_dump,
  output        io_uart_out_valid,
  output [7:0]  io_uart_out_ch,
  output        io_uart_in_valid,
  input  [7:0]  io_uart_in_ch
);

    cbus_req_t  oreq;
    cbus_resp_t oresp;
    cbus_req_t  cpu_oreq;
    cbus_resp_t cpu_oresp;
    logic trint, swint, exint;
    word_t satp;
    u2 priv_mode;
    logic mmu_fault;
    word_t mmu_fault_addr;
    logic mmu_fault_is_store;

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    core core(
      .clk(clock), .reset, .ireq, .iresp, .dreq, .dresp, .trint, .swint, .exint,
      .satp_o(satp), .priv_mode_o(priv_mode),
      .mmu_fault_i(mmu_fault),
      .mmu_fault_addr_i(mmu_fault_addr),
      .mmu_fault_is_store_i(mmu_fault_is_store),
      .dbg_o()
    );

    IBusToCBus icvt(
      .clk(clock),
      .reset(reset),
      .ireq(ireq),
      .iresp(iresp),
      .icreq(icreq),
      .icresp(icresp)
    );
    DBusToCBus dcvt(.*);
    CBusArbiter mux(
        .clk(clock), .reset,
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .oreq(cpu_oreq),
        .oresp(cpu_oresp)
    );

    cbus_mmu mmu(
        .clk(clock),
        .reset(reset),
        .ireq(cpu_oreq),
        .iresp(cpu_oresp),
        .oreq(oreq),
        .oresp(oresp),
        .satp_i(satp),
        .priv_mode_i(priv_mode),
        .fault_o(mmu_fault),
        .fault_addr_o(mmu_fault_addr),
        .fault_is_store_o(mmu_fault_is_store)
    );

    RAMHelper2 ram(
        .clk(clock), .reset, .oreq, .oresp, .trint, .swint, .exint
    );

    assign {io_uart_out_valid, io_uart_out_ch, io_uart_in_valid} = '0;

endmodule
`endif
