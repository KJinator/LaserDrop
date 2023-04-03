`default_nettype none

module Echo (
    input  logic clock, reset, en, echo_mode,
    input  logic rxf, txe, laser_rx,
    input  logic [7:0] adbus_in,
    output logic ftdi_rd, ftdi_wr, tx_done, adbus_tri, data_valid,
    output logic [1:0] laser_tx,
    output logic [7:0] hex1, hex2, adbus_out
);
    logic CLOCK_12_5;
    logic wrreq, rdreq, data_ready, rdq_full, rdq_empty, wrq_full, wrq_empty;
    logic [7:0] data_rd, recently_received, data_in, data_wr;

    //------------------------LASER TRANSMISSION/RECEIVER---------------------//
    LaserTransmitter transmit (
        .data_transmit(data_rd),
        .en(~echo_mode),
        .clock(CLOCK_12_5),
        .clock_base(clock),
        .reset,
        .data_ready(),
        .laser_out(laser_tx),
        .done(tx_done)
    );

    // Simultaneous mode lasers
    LaserReceiver receive (
        .clock,
        .reset,
        .laser_in(laser_rx),
        .data_valid,
        .data_in
    );

    // Mux for Echo mode vs transmission
    always_comb begin
        if (echo_mode) begin
            wrreq = ~rdq_empty & ~wrq_full;
            rdreq = ~rdq_empty & ~wrq_full;
            data_wr = data_rd;
        end
        else begin
            wrreq = data_valid;
            rdreq = tx_done;
            data_wr = data_in;
        end
    end

    FTDI_Interface ftdi_if (
        .clock,
        .reset,
        .clear(1'b0),
        // FTDI Input
        .txe,
        .rxf,
        .wrreq,
        .rdreq,
        .wr_en(en),
        .rd_en(en),
        .data_wr,
        .adbus_in,
        // Out
        .adbus_tri,
        .ftdi_wr,
        .ftdi_rd,
        .rdq_full,
        .rdq_empty,
        .wrq_full,
        .wrq_empty,
        .data_rd,
        .adbus_out,
        .qsize()
    );

    Register recently_received_reg (
        .D(data_in),
        .en(data_valid),
        .clear(1'b0),
        .clock,
        .reset,
        .Q(recently_received)
    );

    ClockDivider clock_12_5 (
        .clk_base(clock),
        .reset,
        .en(1'b1),
        .divider(8'd4),
        .clk_divided(CLOCK_12_5)
    );

    assign hex2 = recently_received;

endmodule: Echo
