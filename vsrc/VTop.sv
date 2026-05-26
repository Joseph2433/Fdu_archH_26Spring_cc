`ifndef __VTOP_SV
`define __VTOP_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "src/core.sv"
`include "util/IBusToCBus.sv"
`include "util/DBusToCBus.sv"
`include "util/CBusArbiter.sv"
`include "src/mmu/cbus_mmu.sv"

`endif
module VTop
	import common::*;(
	input logic clk, reset,

	output cbus_req_t  oreq,
	input  cbus_resp_t oresp,
	input logic trint, swint, exint,
	output logic [3:0] dbg_o
);

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;
    cbus_req_t  cpu_oreq;
    cbus_resp_t cpu_oresp;
    word_t satp;
    u2 priv_mode;
    logic mmu_fault;
    word_t mmu_fault_addr;
    logic mmu_fault_is_store;

    core core(
        .clk(clk), .reset(reset),
        .ireq(ireq), .iresp(iresp),
        .dreq(dreq), .dresp(dresp),
        .trint(trint), .swint(swint), .exint(exint),
        .satp_o(satp), .priv_mode_o(priv_mode),
        .mmu_fault_i(mmu_fault),
        .mmu_fault_addr_i(mmu_fault_addr),
        .mmu_fault_is_store_i(mmu_fault_is_store),
        .dbg_o(dbg_o)
    );
    IBusToCBus icvt(.*);

    DBusToCBus dcvt(.*);


    CBusArbiter mux(
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .clk(clk),
        .reset(reset),
        .oreq(cpu_oreq),
        .oresp(cpu_oresp)
    );

    cbus_mmu mmu(
        .clk(clk),
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

	always_ff @(posedge clk) begin
		if (~reset) begin
			// $display("icreq %x, %x", icreq.valid, icreq.addr);
			// if (oreq.valid || dcreq.addr == 64'h40600004) $display("dcreq %x, %x, oreq %x, %x, dcresp %x", dcreq.addr, dcreq.valid, oreq.valid, oreq.addr, dcresp.ready);
		end
	end
	

endmodule



`endif
