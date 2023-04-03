`default_nettype none

module Echo (
    input  logic clock, reset, en, echo_mode,
    input  logic rxf, txe, laser_rx,
    input  logic [7:0] adbus_in,
    output logic ftdi_rd, ftdi_wr, tx_done, adbus_tri, data_valid,
    output logic [1:0] laser_tx,
    output logic [7:0] hex1, hex2, adbus_out
);
    enum logic [2:0] { WAIT, VALID_DATA, WAIT_TRANSMISSION } currState, nextState;
    logic CLOCK_6_25, CLOCK_12_5;
    logic wrreq, rdreq, data_ready, rdq_full, rdq_empty, wrq_full, wrq_empty;
    logic [7:0] data_rd, recently_received, data_in, data_wr, data_transmit;

    //------------------------LASER TRANSMISSION/RECEIVER---------------------//
    LaserTransmitter transmit (
        .data_transmit,
        .en(~echo_mode & en),
        .clock(CLOCK_12_5),
        .clock_base(clock),
        .reset,
        .data_ready,
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

    ClockDivider clock_6_25 (
        .clk_base(clock),
        .reset,
        .en(1'b1),
        .divider(8'd8),
        .clk_divided(CLOCK_6_25)
    );

    assign hex2 = recently_received;

    always_comb begin
        wrreq = 1'b0;
        rdreq = 1'b0;
        data_wr = 8'b0;
        data_ready = 1'b0;
        data_transmit = 8'b0;
        nextState = WAIT;

        case (currState)
            WAIT: begin
                if (echo_mode) begin
                    if (!rdq_empty && !wrq_full) begin
                        rdreq = 1'b1;
                        nextState = VALID_DATA;
                    end
                end
                else begin
                    wrreq = data_valid;
                    data_wr = data_in;

                    if (!rdq_empty) begin
                        rdreq = 1'b1;
                        nextState = VALID_DATA;
                    end
                end
            end
            VALID_DATA: begin
                if (echo_mode) begin
                    wrreq = 1'b1;
                    data_wr = data_rd;

                    if (!rdq_empty && !wrq_full) begin
                        rdreq = 1'b1;
                        nextState = VALID_DATA;
                    end
                end
                else begin
                    wrreq = data_valid;
                    data_wr = data_in;

                    data_transmit = data_rd;
                    data_ready = 1'b1;

                    nextState = WAIT_TRANSMISSION;
                end
            end
            WAIT_TRANSMISSION: begin
                if (echo_mode) nextState = WAIT;
                else nextState = tx_done ? WAIT : WAIT_TRANSMISSION;
            end
        endcase
    end

    always_ff @(posedge clock, posedge reset)
        if (reset) currState <= WAIT;
        else currState <= nextState;

endmodule: Echo