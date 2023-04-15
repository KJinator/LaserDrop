
`define PKT_LEN         10'd1024
`define STOP_PKT_LEN    10'd6
`define ACK_PKT_LEN     10'd2
`define FAIL_PKT_LEN    10'd2
`define DONE_PKT_LEN    10'd2

`define START_SEQ       32'hc1c2c3c4
`define DATA_SEQ        32'hd1d2d3d4
`define STOP_SEQ        32'h51525354
`define ACK_SEQ         32'ha1a2a3a4
`define FAIL_SEQ        8'hbb
`define DONE_SEQ        8'haa
`define CLOSE_SEQ       8'h22

// NOTE: may need to increase depending on how fast CPU interface is
`define TIMEOUT_RX_LEN  10'd64

`define HS_SIGNAL    8'b0101_0101

// SYNTAX NOTES
// rx/tx: In reference to laser transmission and receiver
// read/send: In reference to FTDI chip in/out

module LaserDrop (
    input logic clock, reset, en,
    input logic rxf, txe, laser_rx,
    input logic [7:0] adbus_in,
    input logic [9:0] SW,
    output logic ftdi_rd, ftdi_wr, tx_done, adbus_tri, data_valid,
    output logic [1:0] laser_tx,
    output logic [7:0] hex1, hex2, hex3, adbus_out
);
    logic [11:0]    rd_ct, timeout_ct;
    logic [ 3:0]    saw_consecutive, saw_dummy;
    logic [ 2:0]    seq_index;
    logic           CLOCK_25, CLOCK_12_5, CLOCK_6_25, CLOCK_3_125;
    logic [ 1:0]    laser_out;
    logic           timeout, data_valid_sim, data_valid_test,
                    rd_ct_en, timeout_ct_en, timeout_ct_clear,
                    rd_ct_clear, queue_clear;
    logic           wrreq, rdreq, data_ready, rdq_full, rdq_empty, wrq_full,
                    wrq_empty, saw_hs_signal, saw_ack, saw_stop, saw_start,
                    saw_data, seq_saved_en;
    logic [ 7:0]    data_rd, recently_received, adbus_out_recent, data_in,
                    data_wr, data_transmit, saw_seq;
    logic [31:0]    seq_savedD, seq_saved;
    logic [ 7:0][31:0]  seq;
    logic           constant_transmit_mode;

    assign constant_transmit_mode = SW[8];


    //----------------------------LASER TRANSMITTER---------------------------//
    // Need to use clock at double the speed because using posedge (1/2)

    LaserTransmitter transmit (
        .data_transmit,
        .en(en),
        // .clock(CLOCK_6_25),
        .clock(CLOCK_3_125),
        .clock_base(clock),
        .reset,
        .data_ready,
        .laser_out,
        .done(tx_done)
    );

    assign laser_tx[0] = SW[6] ? (laser_out[1] | SW[7]) : laser_out[0];
    assign laser_tx[1] = laser_out[1] | SW[7];
    //------------------------------------------------------------------------//
    //------------------------------LASER RECEIVER----------------------------//
    // Simultaneous mode lasers
    LaserReceiver #(16) receive (
        .clock,
        .reset,
        .laser_in(laser_rx),
        .data_valid,
        .data_in
    );
    //------------------------------------------------------------------------//
    //---------------------------------REGISTERS------------------------------//
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

    Register adbus_out_recent_reg (
        .D(adbus_out),
        .en(~ftdi_wr),
        .clear(1'b0),
        .clock,
        .reset,
        .Q(adbus_out_recent)
    );

    assign hex1 = 8'h00;
    assign hex2 = recently_received;
    assign hex3 = adbus_out_recent;
    //------------------------------------------------------------------------//
    //-----------------------------LOGIC COMPONENTS---------------------------//
    Counter #(12) rd_counter (
        .D(12'b0),
        .en(rd_ct_en),
        .clear(rd_ct_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(rd_ct)
    );

    Counter #(12) timeout_counter (
        .D(12'b0),
        .en(timeout_ct_en),
        .clear(timeout_ct_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(timeout_ct)
    );

    assign seq = { 32'b0, 32'b0, 32'b0, 32'b0, `ACK_SEQ, `DATA_SEQ, `STOP_SEQ, `START_SEQ };
    assign seq_savedD = seq[seq_index];

    Register #(32) seq_saved_reg (
        .D(seq_savedD),
        .en(seq_saved_en),
        .clear(1'b0),
        .clock,
        .reset,
        .Q(seq_saved)
    );

    SequenceDetector seq_detector (
        .clock,
        .reset,
        .en(1'b1),
        .data_valid,
        .data_in,
        .seq,
        .saw_seq({ saw_dummy, saw_ack, saw_data, saw_stop, saw_start })  // NOTE: Change this line with below D!!
    ); 

    Encoder seq_encoder (
        .D({ 4'b0, saw_ack, saw_data, saw_stop, saw_start }),
        .en(1'b1),
        .Y(seq_index)
    );
    //------------------------------------------------------------------------//
    //-------------------------------CLOCK DIVIDERS---------------------------//
    ClockDivider clock_25 (
        .clk_base(clock),
        .reset,
        .en(1'b1),
        .divider(8'b1),
        .clk_divided(CLOCK_25)
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

    ClockDivider clock_3_125 (
        .clk_base(clock),
        .reset,
        .en(1'b1),
        .divider(8'd16),
        .clk_divided(CLOCK_3_125)
    );
    //------------------------------------------------------------------------//
    //-------------------------STATE TRANSITION LOGIC-------------------------//
    enum logic [5:0] {
        WAIT, HS_TX_INIT, TX_SEND_DATA, TX_WAIT_TRANSMISSION, HS_RX_INIT,
        RX_RECEIVE, RX_LOAD_SEQ1, RX_LOAD_SEQ2, RX_LOAD_SEQ3, RX_LOAD_SEQ4
    } currState, nextState;

    assign saw_hs_signal = data_valid && (data_in == `HS_SIGNAL);

    always_comb begin
        data_ready = 1'b0;
        data_transmit = 8'b0;
        wrreq = 1'b0;
        rdreq = 1'b0;
        data_wr = 8'b0;
        seq_saved_en = 1'b0;

        rd_ct_en = 1'b0;
        rd_ct_clear = 1'b0;

        timeout_ct_en = 1'b0;
        timeout_ct_clear = 1'b0;

        nextState = WAIT;

        case (currState)
            WAIT: begin
                if (!rdq_empty) begin
                    nextState = HS_TX_INIT;
                end
                else if (saw_hs_signal) begin
                    nextState = HS_RX_INIT;
                    timeout_ct_clear = 1'b1;
                end
                else begin
                    nextState = WAIT;
                end
            end
            HS_TX_INIT: begin
                nextState = saw_hs_signal ? TX_SEND_DATA : HS_TX_INIT;

                data_ready = 1'b1;
                data_transmit = `HS_SIGNAL;
                rdreq = saw_hs_signal;

                if (!wrq_full) begin
                    wrreq = data_valid;
                    data_wr = data_in;
                end
            end
            TX_SEND_DATA: begin
                nextState = TX_WAIT_TRANSMISSION;
                data_transmit = data_rd;
                data_ready = 1'b1;

                if (!wrq_full) begin
                    wrreq = data_valid;
                    data_wr = data_in;
                end
            end
            TX_WAIT_TRANSMISSION: begin
                if (tx_done && !rdq_empty) begin
                    nextState = TX_SEND_DATA;
                    rdreq = 1'b1;
                end
                else if (tx_done) begin
                    nextState = WAIT;
                end
                else nextState = TX_WAIT_TRANSMISSION;

                if (!wrq_full) begin
                    wrreq = data_valid;
                    data_wr = data_in;
                end
            end
            // HS_TX_FIN: begin
            //     nextState = saw_hs_signal ? HS_TX_FIN2 : HS_TX_FIN;

            //     data_ready = 1'b1;
            //     data_tx = `HS_SIGNAL;
            // end
            // HS_TX_FIN2: begin
            //     nextState = finished_hs2 ? WAIT : HS_TX_FIN2;
            //     timeout_ct_clear = finished_hs2;

            //     data_ready = 1'b1;
            //     data2_ready = 1'b1;
            //     data1_tx = `HS_TX_LASER1;
            //     data2_tx = `HS_TX_LASER2;
            // end
            HS_RX_INIT: begin
                nextState = HS_RX_INIT;

                data_ready = saw_hs_signal;
                data_transmit = `HS_SIGNAL;

                if (saw_start || saw_data || saw_stop) begin
                    nextState = RX_LOAD_SEQ1;
                    seq_saved_en = 1'b1;
                    rd_ct_clear = 1'b1;
                end

                if (!wrq_full) begin
                    wrreq = data_valid;
                    data_wr = data_in;
                end
            end
            RX_LOAD_SEQ1: begin
                nextState = RX_LOAD_SEQ1;

                if (!wrq_full) begin
                    nextState = RX_LOAD_SEQ2;

                    data_wr = seq_saved[31:24];
                    wrreq = 1'b1;
                    rd_ct_en = 1'b1;
                end
            end
            RX_LOAD_SEQ2: begin
                nextState = RX_LOAD_SEQ2;

                if (!wrq_full) begin
                    nextState = RX_LOAD_SEQ3;

                    data_wr = seq_saved[23:16];
                    wrreq = 1'b1;
                    rd_ct_en = 1'b1;
                end
            end
            RX_LOAD_SEQ3: begin
                nextState = RX_LOAD_SEQ3;
                
                if (!wrq_full) begin
                    nextState = RX_LOAD_SEQ4;

                    data_wr = seq_saved[15:8];
                    wrreq = 1'b1;
                    rd_ct_en = 1'b1;
                end
            end
            RX_LOAD_SEQ4: begin
                nextState = RX_LOAD_SEQ4;

                if (!wrq_full) begin
                    nextState = RX_RECEIVE;
                
                    data_wr = seq_saved[7:0];
                    wrreq = 1'b1;
                    rd_ct_en = 1'b1;
                end
            end
            RX_RECEIVE: begin
                timeout_ct_en = 1'b1;
                timeout_ct_clear = data_valid;

                if (!wrq_full) begin
                    nextState = RX_RECEIVE;

                    wrreq = data_valid;
                    data_wr = data_in;
                    rd_ct_en = 1'b1;
                end

                if (rd_ct == 12'd1024 || timeout_ct == 12'd1024) begin  // ~20ms
                    nextState = WAIT;

                    rd_ct_clear = 1'b1;
                    timeout_ct_clear = 1'b1;
                end
            end
            // HS_RX_FIN: begin
            //     nextState = finished_hs ? HS_RX_FIN2 : HS_RX_FIN;
            //     tx_ct_clear = finished_hs;

            //     data1_ready = 1'b1;
            //     data2_ready = 1'b1;
            //     data1_tx = `HS_RX_LASER1;
            //     data2_tx = `HS_RX_LASER2;
            //     if (
            //         data_valid && data1_in == `HS_TX_LASER1
            //         && data2_in == `HS_TX_LASER2
            //     )
            //         saw_consecutive_en = 1'b1;
            //     else if (data_valid) saw_consecutive_clear = 1'b1;
            // end
            // HS_RX_FIN2: begin
            //     nextState = finished_hs2 ? WAIT : HS_RX_FIN2;
            //     tx_ct_clear = finished_hs2;

            //     data1_ready = 1'b1;
            //     data2_ready = 1'b1;
            //     data1_tx = `HS_RX_LASER1;
            //     data2_tx = `HS_RX_LASER2;
            // end
        endcase
    end
    //------------------------------------------------------------------------//
    //-----------------------------FLIP FLOP!!--------------------------------//
    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= WAIT;
        else currState <= nextState;
    end
    //------------------------------------------------------------------------//
endmodule: LaserDrop


// Constraint: None of the sequence bytes can be identical.
module SequenceDetector (
    input   logic clock, reset, en, data_valid,
    input   logic [7:0] data_in,
    input   logic [7:0][31:0] seq,
    output  logic [7:0] saw_seq
);
    enum logic [2:0] { WAIT, SAW1, SAW2, SAW3 } currState, nextState;
    logic [7:0] seeD, see;
    logic [2:0] seqI;
    logic see_en, see_clear;

    genvar seeI;
    generate
        for (seeI = 0; seeI < 8; seeI++) begin: forLoopSee
            assign seeD[seeI] = (seq[seeI][31:24] == data_in);

            Register saw_seq_reg (
                .D(seeD[seeI]),
                .en(see_en),
                .clear(see_clear),
                .clock,
                .reset,
                .Q(see[seeI])
            );
        end: forLoopSee
    endgenerate

    Encoder saw_seq_encoder (
        .D(see),
        .en(1'b1),
        .Y(seqI)
    );

    always_comb begin
        see_en = 1'b0;
        see_clear = 1'b0;
        saw_seq = 8'b0;

        case (currState)
            WAIT: begin
                if (seeD > 8'b0 && data_valid) begin
                    see_en = 1'b0;
                    nextState = SAW1;
                end
                else nextState = WAIT;
            end
            SAW1: begin
                if (seq[seqI][23:16] == data_in && data_valid) nextState = SAW2;
                else if (data_valid) nextState = WAIT;
                else nextState = SAW1;
            end
            SAW2: begin
                if (seq[seqI][15:8] == data_in && data_valid) nextState = SAW3;
                else if (data_valid) nextState = WAIT;
                else nextState = SAW2;
            end
            SAW3: begin
                if (data_valid) begin
                    nextState = WAIT;
                    if (seq[seqI][7:0] == data_in) saw_seq = see;
                end
                else nextState = SAW1;
            end
        endcase
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= WAIT;
        else currState <= nextState;
    end

endmodule: SequenceDetector