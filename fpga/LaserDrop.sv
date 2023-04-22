
`define PKT_LEN         12'd1024
// `define STOP_PKT_LEN    10'd6
// `define ACK_PKT_LEN     10'd2
// `define FAIL_PKT_LEN    10'd2
// `define DONE_PKT_LEN    10'd2

`define START_SEQ       32'hc1c2c3c4
`define DATA_SEQ        32'hd1d2d3d4
`define STOP_SEQ        32'h51525354
`define ERROR_SEQ       32'hb1b2b3b4
`define DONE_SEQ        32'ha1a2a3a4

// NOTE: may need to increase depending on how fast CPU interface is
`define TIMEOUT_RX_LEN  10'd64

`define HS_SIGNAL    8'b1010_1010
`define HS_RX_SIGNAL 8'b0001_0000

// SYNTAX NOTES
// rx/tx: In reference to laser transmission and receiver
// read/send: In reference to FTDI chip in/out

module LaserDrop (
    input logic clock, reset, en,
    input logic rxf, txe, laser_rx, clock_start,
    input logic [7:0] adbus_in,
    input logic [9:0] SW,
    output logic ftdi_rd, ftdi_wr, adbus_tri, clock_start_out, ambient_light_n,
    output logic [1:0] laser_tx,
    output logic [7:0] hex1, hex2, hex3, adbus_out,
    output logic [9:0] LEDR
);
    enum logic [5:0] {
        WAIT, HS_TX_INIT, HS_TX_WAIT, TX_ALIGN_UART, TX_SEND_DATA,
        TX_WAIT_TRANSMISSION, HS_RX_INIT, RX_RECEIVE_FIN,
        RX_RECEIVE, RX_LOAD_SEQ1, RX_LOAD_SEQ2, RX_LOAD_SEQ3, RX_LOAD_SEQ4,
        TX_FIN
    } currState, nextState;

    logic           CLOCK_25, CLOCK_12_5, CLOCK_6_25, CLOCK_UART;

    logic [ 7:0][31:0]  seq;
    logic [31:0]    seq_savedD, seq_saved;
    logic [16:0]    rd_qsize;
    logic [11:0]    rd_ct, timeout_ct, counter, tx_ct;
    logic [ 9:0]    wr_qsize;
    logic [ 7:0]    data_rd, recently_received, adbus_out_recent, data_in,
                    data_wr, data_transmit, saw_seq, last_transmitted, divider;
    logic [ 2:0]    seqI, saw_dummy;
    logic [ 1:0]    laser_out;
    logic           rd_ct_en, timeout_ct_en, timeout_ct_clear, tx_ct_clear,
                    rd_ct_clear, data_valid, tx_done, rd_en, wr_en, tx_ct_en,
                    wrreq, rdreq, data_ready, rdq_full, rdq_empty, wrq_full,
                    wrq_empty, saw_hs_signal, saw_hs_rx_signal, saw_done,
                    saw_stop, saw_start, saw_data, seq_saved_en, wr_clear,
                    rd_clear, toggle_both_lasers, constant_transmit_mode,
                    both_lasers_on, constant_receive_mode, send_any_size,
                    counter_en, counter_clear, load_1k, saw_error, debug_mode,
                    reset;

    assign constant_receive_mode = SW[1];
    // assign send_any_size = SW[3];
    assign toggle_both_lasers = SW[2];
    assign both_lasers_on = SW[3];
    assign ambient_light_n = SW[4];
    assign divider = { 3'b0, SW[8:5], 3'b0 };
    assign debug_mode = SW[9];

    assign LEDR[1:0] = laser_tx;
    assign LEDR[4] = tx_done;
    assign LEDR[5] = data_valid;
    assign LEDR[6] = clock_start;
    assign LEDR[8] = laser_rx;
    assign LEDR[9] = wrq_empty;

    //----------------------------LASER TRANSMITTER---------------------------//
    // Need to use clock at double the speed because using posedge (1/2)

    LaserTransmitter transmit (
        .data_transmit,
        .en(en),
        // .clock(CLOCK_6_25),
        .clock(CLOCK_UART),
        .clock_base(clock),
        .reset,
        .data_ready,
        .laser_out,
        .done(tx_done)
    );

    assign laser_tx[0] = toggle_both_lasers ? (laser_out[1] | both_lasers_on) : laser_out[0];
    assign laser_tx[1] = laser_out[1] | both_lasers_on;
    //------------------------------------------------------------------------//
    //------------------------------LASER RECEIVER----------------------------//
    // Simultaneous mode lasers
    LaserReceiver receive (
        .clock,
        .reset,
        .laser_in(laser_rx),
        .divider,
        .data_valid,
        .data_in
    );
    //------------------------------------------------------------------------//
    //---------------------------------REGISTERS------------------------------//
    FTDI_Interface ftdi_if (
        .clock,
        .reset,
        .clear(1'b0),
        .wr_clear,
        .rd_clear,
        .debug_mode,
        .load_1k,
        .clock_start,
        // FTDI Input
        .txe,
        .rxf,
        .wrreq,
        .rdreq,
        .wr_en(wr_en && en),
        .rd_en(rd_en && en),
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
        .rd_qsize,
        .wr_qsize
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
    
    Register last_transmitted_reg (
        .D(data_transmit),
        .en(data_ready),
        .clear(1'b0),
        .clock,
        .reset,
        .Q(last_transmitted)
    );

    // assign hex1 = wr_qsize[7:0];
    assign hex1 = last_transmitted;
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

    Counter #(12) tx_counter (
        .D(12'b0),
        .en(tx_ct_en),
        .clear(tx_ct_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(tx_ct)
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
    
    Counter #(12) gen_counter (
        .D(12'b0),
        .en(counter_en),
        .clear(counter_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(counter)
    );

    assign seq = { 32'b0, 32'b0, 32'b0, `DONE_SEQ,
                    `ERROR_SEQ, `DATA_SEQ, `STOP_SEQ, `START_SEQ };
    assign seq_savedD = seq[seqI];

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
        .seqI,
        .saw_seq({ saw_dummy, saw_done, saw_error, saw_data, saw_stop, saw_start })  // NOTE: Change this line with below D!!
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

    ClockDivider clock_uart (
        .clk_base(clock),
        .reset,
        .en(1'b1),
        .divider(divider),
        .clk_divided(CLOCK_UART)
    );
    //------------------------------------------------------------------------//
    //-------------------------STATE TRANSITION LOGIC-------------------------//
    assign saw_hs_signal = data_valid && (data_in == `HS_SIGNAL);
    assign saw_hs_rx_signal = data_valid && (data_in == `HS_RX_SIGNAL);

    always_comb begin
        data_ready = 1'b0;
        data_transmit = 8'b0;
        wrreq = 1'b0;
        rdreq = 1'b0;
        data_wr = 8'b0;
        seq_saved_en = 1'b0;
        rd_en = 1'b1;
        wr_en = 1'b1;
        rd_clear = 1'b0;
        wr_clear = 1'b0;
        load_1k = 1'b0;

        rd_ct_en = 1'b0;
        rd_ct_clear = 1'b0;

        timeout_ct_en = 1'b0;
        timeout_ct_clear = 1'b0;

        counter_en = 1'b0;
        counter_clear = 1'b0;

        tx_ct_en = 1'b0;
        tx_ct_clear = 1'b0;

        nextState = WAIT;
        clock_start_out = 1'b0;

        case (currState)
            WAIT: begin
                timeout_ct_clear = 1'b1;
                tx_ct_clear = 1'b1;
                rd_ct_clear = 1'b1;

                if (!rdq_empty) begin
                    nextState = HS_TX_INIT;
                    rdreq = 1'b1;
                    clock_start_out = 1'b1;
                    counter_clear = 1'b1;
                end
                else if (saw_hs_signal) begin
                    nextState = HS_RX_INIT;
                end
                else begin
                    nextState = WAIT;
                end
            end
            HS_TX_INIT: begin
                if (saw_hs_rx_signal) begin
                    nextState = HS_TX_WAIT;
                    counter_clear = 1'b1;
                end
                else nextState = HS_TX_INIT;

                data_ready = 1'b1;
                data_transmit = `HS_SIGNAL;

                counter_en = 1'b1;
                if (counter < 32'd5) begin
                    clock_start_out = 1'b1;
                end

                if (constant_receive_mode && !wrq_full) begin
                    wrreq = data_valid;
                    data_wr = data_in;
                end
            end
            HS_TX_WAIT: begin
                if (tx_done) begin
                    nextState = TX_ALIGN_UART;
                    timeout_ct_clear = 1'b1;
                end
                else nextState = HS_TX_WAIT;
            end
            TX_ALIGN_UART: begin
                nextState = TX_ALIGN_UART;
                timeout_ct_en = 1'b1;
                if (timeout_ct == 12'd12 << 4'd4) begin
                    nextState = TX_SEND_DATA;
                    timeout_ct_clear = 1'b1;
                end
            end
            TX_SEND_DATA: begin
                nextState = TX_WAIT_TRANSMISSION;
                data_transmit = data_rd;
                data_ready = 1'b1;

                if (constant_receive_mode && !wrq_full) begin
                    wrreq = data_valid;
                    data_wr = data_in;
                end
            end
            TX_WAIT_TRANSMISSION: begin
                if (tx_done && !rdq_empty && tx_ct < 12'd1023) begin
                    nextState = TX_SEND_DATA;
                    rdreq = 1'b1;
                end
                else if (tx_done) begin
                    nextState = TX_FIN;
                    tx_ct_clear = 1'b1;
                    timeout_ct_clear = 1'b1;
                end
                else begin
                    nextState = TX_WAIT_TRANSMISSION;
                end

                tx_ct_en = tx_done;
                if (constant_receive_mode && !wrq_full) begin
                    wrreq = data_valid;
                    data_wr = data_in;
                end
            end
            HS_RX_INIT: begin
                nextState = HS_RX_INIT;

                data_ready = saw_hs_signal;
                data_transmit = `HS_RX_SIGNAL;
                timeout_ct_en = 1'b1;
                timeout_ct_clear = data_valid;

                if (saw_start || saw_data || saw_stop || saw_error || saw_done) begin
                    nextState = RX_LOAD_SEQ1;

                    counter_clear = 1'b1;
                    seq_saved_en = 1'b1;
                    rd_ct_en = 1'b1;
                    timeout_ct_clear = 1'b1;
                end
                else if (timeout_ct == 12'd1024) begin  // ~20ms
                    nextState = WAIT;

                    timeout_ct_clear = 1'b1;
                end

                if (constant_receive_mode && !wrq_full) begin
                    wrreq = data_valid;
                    data_wr = data_in;
                end
            end
            RX_LOAD_SEQ1: begin
                nextState = RX_LOAD_SEQ1;
                counter_en = 1'b1;

                if (!wrq_full) begin
                    nextState = RX_LOAD_SEQ2;

                    data_wr = seq_saved[31:24];
                    wrreq = 1'b1;
                    rd_ct_en = 1'b1;
                end
            end
            RX_LOAD_SEQ2: begin
                nextState = RX_LOAD_SEQ2;
                counter_en = 1'b1;

                if (!wrq_full) begin
                    nextState = RX_LOAD_SEQ3;

                    data_wr = seq_saved[23:16];
                    wrreq = 1'b1;
                    rd_ct_en = 1'b1;
                end
            end
            RX_LOAD_SEQ3: begin
                nextState = RX_LOAD_SEQ3;
                counter_en = 1'b1;
                
                if (!wrq_full) begin
                    nextState = RX_LOAD_SEQ4;

                    data_wr = seq_saved[15:8];
                    wrreq = 1'b1;
                    rd_ct_en = 1'b1;
                end
            end
            RX_LOAD_SEQ4: begin
                nextState = RX_LOAD_SEQ4;
                counter_en = 1'b1;

                if (!wrq_full) begin
                    nextState = RX_RECEIVE;
                
                    data_wr = seq_saved[7:0];
                    wrreq = 1'b1;
                    timeout_ct_clear = 1'b1;
                    rd_ct_en = 1'b1;
                end
            end
            RX_RECEIVE: begin
                nextState = RX_RECEIVE;
                timeout_ct_en = 1'b1;
                timeout_ct_clear = data_valid;

                if (rd_ct > 12'd1024) begin
                    nextState = WAIT;
                    
                    load_1k = 1'b1;
                    rd_ct_clear = 1'b1;
                    timeout_ct_clear = 1'b1;
                end
                else if (timeout_ct == 12'd1024) begin  // ~20ms
                    nextState = WAIT;

                    load_1k = 1'b1;
                    rd_ct_clear = 1'b1;
                    timeout_ct_clear = 1'b1;
                end
                else if (!wrq_full) begin
                    wrreq = data_valid;
                    data_wr = (data_in[2:0] == 3'b000 && debug_mode) ? rd_ct[7:0] : data_in;
                    rd_ct_en = data_valid;
                end
            end
            RX_RECEIVE_FIN: begin
                nextState = WAIT;
            end
            TX_FIN: begin
                timeout_ct_en = 1'b1;

                if (timeout_ct > (12'd16 << 4'd4)) begin
                    nextState = WAIT;

                    timeout_ct_clear = 1'b1;
                end
            end
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
    output  logic [2:0] seqI,
    output  logic [7:0] saw_seq
);
    enum logic [2:0] { WAIT, SAW1, SAW2, SAW3 } currState, nextState;
    logic [7:0] seeD, see;
    logic see_en, see_clear;

    genvar seeI;
    generate
        for (seeI = 0; seeI < 8; seeI++) begin: forLoopSee
            assign seeD[seeI] = (seq[seeI][31:24] == data_in);

            Register #(1) saw_seq_reg (
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
                if (seeD > 8'b0 && data_valid && en) begin
                    see_en = 1'b1;
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
                else nextState = SAW3;
            end
        endcase
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= WAIT;
        else currState <= nextState;
    end

endmodule: SequenceDetector