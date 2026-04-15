`ifndef __IBUSTOCBUS_SV
`define __IBUSTOCBUS_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

`endif

module IBusToCBus 
    import common::*;(
    input  logic       clk,
    input  logic       reset,
    input  ibus_req_t  ireq,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp
);
    // since IBus is a subset of DBus, we can reuse DBusToCBus.
    dbus_resp_t dresp;
    logic       inflight_q;
    logic       addr_hi_q;

    DBusToCBus inst(
        .dreq(`IREQ_TO_DREQ(ireq)),
        .dresp(dresp),
        .dcreq(icreq),
        .dcresp(icresp)
    );

    // Keep the request word-select bit stable for the returning IBus response.
    always_ff @(posedge clk) begin
        if (reset) begin
            inflight_q <= 1'b0;
            addr_hi_q  <= 1'b0;
        end else begin
            if (!inflight_q && ireq.valid) begin
                inflight_q <= 1'b1;
                addr_hi_q  <= ireq.addr[2];
            end

            if (dresp.data_ok) begin
                inflight_q <= 1'b0;
            end
        end
    end

    assign iresp.addr_ok = dresp.addr_ok;
    assign iresp.data_ok = dresp.data_ok;
    assign iresp.data    = addr_hi_q ? dresp.data[63:32] : dresp.data[31:0];
endmodule



`endif