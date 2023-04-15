`default_nettype none

`define START_PKT_LEN   10'd512
`define STOP_PKT_LEN    10'd6
`define ACK_PKT_LEN     10'd2
`define FAIL_PKT_LEN    10'd2
`define DONE_PKT_LEN    10'd2

`define START_SEQ       8'hcc
`define STOP_SEQ        8'h55
`define ACK_SEQ         8'h11
`define FAIL_SEQ        8'hbb
`define DONE_SEQ        8'haa

// NOTE: may need to increase depending on how fast CPU interface is
`define TIMEOUT_RX_LEN  10'd64
`define MAX_RD_CT       8'd64
`define MAX_RX_CT       8'd64

`define HS_TX_LASER1    8'b0101_0101
`define HS_TX_LASER2    8'b1010_1010

`define HS_RX_LASER1    8'b1010_1010
`define HS_RX_LASER2    8'b0101_0101

// SYNTAX NOTES
// rx/tx: In reference to laser transmission and receiver
// read/send: In reference to FTDI chip in/out

module LaserDrop (
    input logic clock, reset, en, non_sim_mode,
    input logic rxf, txe, laser1_rx, laser2_rx,
    input logic [7:0] adbus_in,
    output logic ftdi_rd, ftdi_wr, tx_done, adbus_tri, data_valid,
    output logic [1:0] laser1_tx, laser2_tx,
    output logic [7:0] data1_in, data2_in, adbus_out
);
    logic [511:0]   read, read_D;
    logic [  9:0]   rd_ct, tx_ct, rx_ct, timeout_ct;
    logic [  7:0]   data1_tx, data2_tx, rx_out, rx_q,
                    data1_in_sim, data2_in_sim, data1_in_test, data2_in_test,
                    dummy_data1, dummy_data2;
    logic [  3:0]   saw_consecutive;
    logic           CLOCK_25, CLOCK_12_5, CLOCK_6_25;
    logic           timeout, data_valid_sim, data_valid_test, finished_hs,
                    data1_valid_test, data2_valid_test, data1_ready,
                    data2_ready, store_rd, store_rx, rx_read, rx_empty, rx_full,
                    saw_consecutive_en, rd_ct_en, rx_ct_en, timeout_ct_en,
                    saw_consecutive_clear, timeout_ct_clear, rd_ct_clear,
                    tx_ct_clear, rx_ct_clear, queue_clear, finished_hs2;

    //----------------------------LASER TRANSMITTER---------------------------//
    // Need to use clock at double the speed because using posedge (1/2)

    LaserTransmitter_DEPRICATED transmit (
        .data1_transmit(data1_tx),
        .data2_transmit(data2_tx),
        .en,
        .clock(CLOCK_6_25),
        .clock_base(clock),
        .reset,
        .data1_ready,
        .data2_ready,
        .laser1_out(laser1_tx),
        .laser2_out(laser2_tx),
        .done(tx_done)
    );
    //------------------------------------------------------------------------//
    //------------------------------LASER RECEIVER----------------------------//
    // Simultaneous mode lasers
    LaserReceiver_DEPRICATED receive (
        .laser1_in(laser1_rx),
        .laser2_in(laser2_rx),
        .clock,
        .simultaneous_mode(1'b1),
        .reset,
        .data_valid(data_valid_sim),
        .data1_in(data1_in_sim),
        .data2_in(data2_in_sim)
    );

    // Non-simultaneous (test mode lasers)
    assign data_valid_test = data1_valid_test | data2_valid_test;

    LaserReceiver_DEPRICATED receive1 (
        .laser1_in(laser1_rx),
        .laser2_in(1'b0),
        .clock,
        .simultaneous_mode(1'b0),
        .reset,
        .data_valid(data2_valid_test),
        .data1_in(data1_in_test),
        .data2_in(dummy_data2)
    );
    LaserReceiver_DEPRICATED receive2 (
        .laser1_in(1'b0),
        .laser2_in(laser2_rx),
        .clock,
        .simultaneous_mode(1'b0),
        .reset,
        .data_valid(data1_valid_test),
        .data1_in(dummy_data1),
        .data2_in(data2_in_test)
    );

    assign data_valid = non_sim_mode ? data_valid_test : data_valid_sim;
    assign data1_in = non_sim_mode ? data1_in_test : data1_in_sim;
    assign data2_in = non_sim_mode ? data2_in_test : data2_in_sim;
    //------------------------------------------------------------------------//
    //---------------------------------REGISTERS------------------------------//
    Register #(512) ftdi_input (
        .D(read_D),
        .en(store_rd),
        .clear(1'b0),
        .reset,
        .clock,
        .Q(read)
    );

    LaserDropQueue laser_drop_queue (
        .D({ data2_in, data1_in }),
        .clock,
        .load(store_rx),
        .read(rx_read),
        .reset,
        .clear(queue_clear),
        .Q(rx_q),
        .size(),
        .empty(rx_empty),
        .full(rx_full)
    );
    //------------------------------------------------------------------------//
    //-----------------------------LOGIC COMPONENTS---------------------------//
    Counter #(10) rd_counter (
        .D(10'b0),
        .en(rd_ct_en),
        .clear(rd_ct_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(rd_ct)
    );

    Counter #(10) timeout_counter (
        .D(10'b0),
        .en(timeout_ct_en),
        .clear(timeout_ct_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(timeout_ct)
    );

    Register #(10) tx_counter (
        .D(tx_ct + 10'd2),
        .en(tx_done),
        .clear(tx_ct_clear),
        .reset,
        .clock,
        .Q(tx_ct)
    );

    Register #(10) rx_counter (
        .D(rx_ct + 10'd2),
        .en(rx_ct_en),
        .clear(rx_ct_clear),
        .reset,
        .clock,
        .Q(rx_ct)
    );

    Counter #(4) hs_counter (
        .D(4'b0),
        .en(saw_consecutive_en),
        .clear(saw_consecutive_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(saw_consecutive)
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
    //------------------------------------------------------------------------//
    //-------------------------STATE TRANSITION LOGIC-------------------------//
    enum logic [5:0] {
        RESET, HS_TX_INIT, HS_TX_INIT2, HS_TX_FIN, HS_TX_FIN2, LOAD_TX_READ,
        WAIT_TX_READ, RECEIVE, WAIT_RESEND, WAIT_TX_WRITE, SET_TX_WRITE,
        TX_WRITE1, TX_WRITE2, HS_RX_INIT, HS_RX_INIT2, HS_RX_FIN, HS_RX_FIN2,
        WAIT_RX_WRITE, SET_RX_WRITE, RX_WRITE1, RX_WRITE2, LOAD_RX_READ,
        WAIT_RX_READ, WAIT_RX_TRANSMIT
    } currState, nextState;

    assign finished_hs = saw_consecutive == 4'd4;
    assign finished_hs2 = tx_ct == 10'd4;
    assign timeout = timeout_ct == `TIMEOUT_RX_LEN;
    logic [12:0] tx_ct_wide;
    assign tx_ct_wide = {3'd0, tx_ct};

    always_comb begin
        data1_tx = (read & (512'hff << (tx_ct_wide<<3))) >> (tx_ct_wide<<3);
        data2_tx = (read & (512'hff << ((tx_ct_wide+1)<<3))) >> ((tx_ct_wide+1)<<3);
        data1_ready = tx_ct < rd_ct;
        data2_ready = (tx_ct + 1) < rd_ct;
        ftdi_rd = 1'b1;
        ftdi_wr = 1'b1;
        adbus_tri = 1'b0;
        store_rx = 1'b0;
        store_rd = 1'b0;
        rx_read = 1'b0;
        read_D = read;

        rx_ct_en = 1'b0;
        rd_ct_en = 1'b0;
        timeout_ct_en = 1'b0;
        saw_consecutive_en = 1'b0;
        rx_ct_clear = 1'b0;
        rd_ct_clear = 1'b0;
        tx_ct_clear = 1'b0;
        timeout_ct_clear = 1'b0;
        saw_consecutive_clear = 1'b0;

        case (currState)
            RESET: begin
                if (~rxf) begin
                    nextState = HS_TX_INIT;
                    saw_consecutive_clear = 1'b1;
                end
                else if (data_valid && data1_in == `HS_TX_LASER1 && data2_in == `HS_TX_LASER2) begin
                    nextState = HS_RX_INIT;
                    timeout_ct_clear = 1'b1;
                    saw_consecutive_en = 1'b1;
                end
                else begin
                    nextState = RESET;
                    saw_consecutive_clear = 1'b1;
                end
            end
            HS_TX_INIT: begin
                nextState = finished_hs ? HS_TX_INIT2 : HS_TX_INIT;
                tx_ct_clear = finished_hs;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
                if (
                    data_valid && data1_in == `HS_RX_LASER1 &&
                    data2_in == `HS_RX_LASER2
                )
                    saw_consecutive_en = 1'b1;
                else if (data_valid) saw_consecutive_clear = 1'b1;
            end
            HS_TX_INIT2: begin
                nextState = finished_hs2 ? LOAD_TX_READ : HS_TX_INIT2;
                rd_ct_clear = finished_hs2;
                tx_ct_clear = finished_hs2;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
            end
            LOAD_TX_READ: begin
                nextState = WAIT_TX_READ;

                adbus_tri = 1'b0;
                ftdi_rd = 1'b0;
                store_rd = 1'b1;
                rd_ct_en = 1'b1;
                read_D = (
                    (read & ~(512'hff << ({3'd0, rd_ct} << 3))) +
                    ({504'd0, adbus_in} << ({3'd0, rd_ct} << 3))
                );
            end
            WAIT_TX_READ: begin
                if ((read[7:0] == `START_SEQ && rd_ct == `START_PKT_LEN && tx_ct >= `START_PKT_LEN) ||
                    (read[7:0] == `STOP_SEQ && rd_ct == `STOP_PKT_LEN && tx_ct >= `STOP_PKT_LEN)) begin
                    nextState = RECEIVE;
                    rx_ct_clear = 1'b1;
                end
                // Transmission less. Wait until all packets sent over lasers
                else if (rxf ||
                         (read[7:0] == `START_SEQ && rd_ct == `START_PKT_LEN) ||
                         (read[7:0] == `STOP_SEQ && rd_ct == `STOP_PKT_LEN))
                    nextState = WAIT_TX_READ;
                else nextState = LOAD_TX_READ;

                adbus_tri = 1'b0;
                ftdi_rd = 1'b1;
            end
            RECEIVE: begin
                if (data_valid && rx_q == `ACK_SEQ) begin
                    nextState = LOAD_TX_READ;
                    tx_ct_clear = 1'b1;
                    rd_ct_clear = 1'b1;
                    queue_clear = 1'b1;
                end
                else if (data_valid && rx_q == `DONE_SEQ) begin
                    nextState = HS_TX_FIN;
                    queue_clear = 1'b1;
                end
                else if (timeout || data_valid) begin
                    nextState = WAIT_RESEND;
                    tx_ct_clear = 1'b1;
                    queue_clear = 1'b1;
                end
                else nextState = RECEIVE;

                store_rx = data_valid;
                rx_ct_en = data_valid;
            end
            WAIT_TX_WRITE: begin
                if (~txe & ~rx_empty) begin
                    nextState = SET_TX_WRITE;
                end
                else nextState = WAIT_TX_WRITE;
            end
            WAIT_RESEND: begin
                if ((read[7:0] == `START_SEQ && tx_ct == `START_PKT_LEN) ||
                    (read[7:0] == `STOP_SEQ && tx_ct == `STOP_PKT_LEN))
                    nextState = RECEIVE;
                else nextState = WAIT_RESEND;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
                if (data_valid && data1_in == `HS_RX_LASER1 && data2_in == `HS_RX_LASER2)
                    saw_consecutive_en = 1'b1;
                else if (data_valid) saw_consecutive_clear = 1'b1;
            end
            HS_TX_FIN: begin
                nextState = finished_hs ? HS_TX_FIN2 : HS_TX_FIN;
                tx_ct_clear = finished_hs;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
                if (
                    data_valid && data1_in == `HS_RX_LASER1 &&
                    data2_in == `HS_RX_LASER2
                )
                    saw_consecutive_en = 1'b1;
                else if (data_valid) saw_consecutive_clear = 1'b1;
            end
            HS_TX_FIN2: begin
                nextState = finished_hs2 ? RESET : HS_TX_FIN2;
                timeout_ct_clear = finished_hs2;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
            end
            HS_RX_INIT: begin
                nextState = finished_hs ? HS_RX_INIT2 : HS_RX_INIT;
                tx_ct_clear = finished_hs;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_RX_LASER1;
                data2_tx = `HS_RX_LASER2;
                if (
                    data_valid && data1_in == `HS_TX_LASER1
                    && data2_in == `HS_TX_LASER2
                )
                    saw_consecutive_en = 1'b1;
                else if (data_valid) saw_consecutive_clear = 1'b1;
            end
            HS_RX_INIT2: begin
                nextState = finished_hs2 ? WAIT_RX_WRITE : HS_RX_INIT2;
                timeout_ct_clear = finished_hs2;
                rx_ct_clear = finished_hs2;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_RX_LASER1;
                data2_tx = `HS_RX_LASER2;
            end
            WAIT_RX_WRITE: begin
                if (~rxf) begin
                    nextState = LOAD_RX_READ;
                    ftdi_rd = 1'b0;
                    rd_ct_en = 1'b1;
                end
                else if (~txe & ~rx_empty) begin
                    nextState = SET_RX_WRITE;
                end
                else nextState = WAIT_RX_WRITE;

                store_rx = data_valid;
            end
            SET_RX_WRITE: begin
                nextState = RX_WRITE1;

                adbus_out = rx_q;
                store_rx = data_valid;
            end
            RX_WRITE1: begin
                nextState = RX_WRITE2;

                adbus_tri = 1'b1;
                ftdi_wr = 1'b0;
                adbus_out = rx_q;
                store_rx = data_valid;
            end
            RX_WRITE2: begin
                nextState = WAIT_RX_WRITE;

                rx_read = 1'b1;
                adbus_tri = 1'b1;
                ftdi_wr = 1'b0;
                adbus_out = rx_q;
                store_rx = data_valid;
            end
            LOAD_RX_READ: begin
                if (rd_ct < 10'd2) nextState = WAIT_RX_READ;
                else if (rd_ct >= 10'd2 && data1_in == `DONE_SEQ)
                    nextState = HS_RX_FIN;
                else begin
                    nextState = WAIT_RX_TRANSMIT;
                    timeout_ct_clear = 1'b1;
                end

                adbus_tri = 1'b0;
                ftdi_rd = 1'b0;
                store_rd = 1'b1;
                rd_ct_en = 1'b1;
                read_D = (
                    (read & ~(512'hff << ({3'd0, rd_ct} << 3))) +
                    ({504'd0, adbus_in} << ({3'd0, rd_ct} << 3))
                );

                store_rx = data_valid;
            end
            WAIT_RX_TRANSMIT: begin
                if (tx_ct >= rd_ct) begin
                    nextState = WAIT_RX_READ;
                    tx_ct_clear = 1'b1;
                    rd_ct_clear = 1'b1;
                end
                else nextState = WAIT_RX_READ;

                store_rx = data_valid;
            end
            WAIT_RX_READ: begin
                nextState = rxf ? WAIT_RX_READ : LOAD_RX_READ;

                rd_ct_en = ~rxf;
                store_rx = data_valid;
            end
            HS_RX_FIN: begin
                nextState = finished_hs ? HS_RX_FIN2 : HS_RX_FIN;
                tx_ct_clear = finished_hs;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_RX_LASER1;
                data2_tx = `HS_RX_LASER2;
                if (
                    data_valid && data1_in == `HS_TX_LASER1
                    && data2_in == `HS_TX_LASER2
                )
                    saw_consecutive_en = 1'b1;
                else if (data_valid) saw_consecutive_clear = 1'b1;
            end
            HS_RX_FIN2: begin
                nextState = finished_hs2 ? RESET : HS_RX_FIN2;
                tx_ct_clear = finished_hs2;

                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_RX_LASER1;
                data2_tx = `HS_RX_LASER2;
            end
        endcase
    end
    //------------------------------------------------------------------------//
    //-----------------------------FLIP FLOP!!--------------------------------//
    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= RESET;
        else currState <= nextState;
    end
    //------------------------------------------------------------------------//
endmodule: LaserDrop

// Laser Transmission module
// Transmits data_in on data_out if data_ready is asserted. Asserts done when
// transmission finished.
// NOTE: Currently, configured so it only transmits if both lasers are ready.
module LaserTransmitter(
    input logic [7:0] data_transmit,
    input logic en, clock, clock_base, reset, data_ready,
    output logic [1:0] laser_out,
    output logic done
);
    logic [7:0] data;
    logic [10:0] data_compiled;
    logic [3:0] count;
    logic load, count_en, count_reset, mux_out;

    enum logic [1:0] { WAIT, SEND, DONE } currState, nextState;

    Register laser_data (
        .D(data_transmit),
        .en(load),
        .clear(1'b0),
        .reset,
        .clock(clock_base),
        .Q(data)
    );

    // 1'b1 is start bit, and it wraps around to 0 at the end -> sent LSB first
    assign data_compiled = { data, 1'b1, 1'b0};

    assign mux_out = data_compiled[count];

    Counter #(4) bit_count (
        .D(4'b0),
        .en(count_en),
        .clear(1'b0),
        .load(1'b0),
        .clock(clock),
        .up(1'b1),
        .reset(reset || count_reset),
        .Q(count)
    );

    //// Transition States
    always_comb
        case (currState)
            WAIT: nextState = (data_ready && en) ? SEND : WAIT;
            // TODO: depending on timing, have space to optimize one clock cycle
            SEND: begin
                if (~en) nextState = WAIT;
                else if (count == 4'd10) nextState = DONE;
                else nextState = SEND;
            end
            DONE: nextState = WAIT;
        endcase

    //// Logic for each state
    always_comb begin
        count_en = 1'b0;
        count_reset = ~en;
        load = 1'b0;
        done = 1'b0;
        laser_out = { mux_out, en };

        case (currState)
            WAIT: load = data_ready;
            // TODO: depending on timing, have space to optimize one clock cycle
            SEND: begin
                count_en = 1'b1;
            end
            DONE: begin
                done = 1'b1;
                count_reset = 1'b1;
            end
        endcase
    end

    always_ff @(posedge clock_base, posedge reset) begin
        if (reset) currState <= WAIT;
        else currState <= nextState;
    end
endmodule: LaserTransmitter

// Laser Transmission module
// Transmits data_in on data_out if data_ready is asserted. Asserts done when
// transmission finished.
// NOTE: Currently, configured so it only transmits if both lasers are ready.
module LaserTransmitter_DEPRICATED (
    input logic [7:0] data1_transmit, data2_transmit,
    input logic en, clock, clock_base, reset, data1_ready, data2_ready,
    output logic [1:0] laser1_out, laser2_out,
    output logic done
);
    logic [7:0] data1, data2;
    logic [10:0] data1_compiled, data2_compiled;
    logic [3:0] count;
    logic data_ready, load, count_en, count_reset, mux1_out, mux2_out;

    enum logic [1:0] { WAIT, SEND, DONE } currState, nextState;

    Register laser1_data (
        .D(data1_transmit),
        .en(load),
        .clear(1'b0),
        .reset,
        .clock(clock),
        .Q(data1)
    );

    Register laser2_data (
        .D(data2_transmit),
        .en(load),
        .clear(1'b0),
        .reset,
        .clock(clock),
        .Q(data2)
    );

    // 1'b1 is start bit, and it wraps around to 0 at the end -> sent LSB first
    assign data1_compiled = { data1_transmit, 1'b1, 1'b0};
    assign data2_compiled = { data2_transmit, 1'b1, 1'b0};

    assign mux1_out = data1_compiled[count];
    assign mux2_out = data2_compiled[count];

    Counter #(4) bit_count (
        .D(4'b0),
        .en(count_en),
        .clear(1'b0),
        .load(1'b0),
        .clock(clock),
        .up(1'b1),
        .reset(reset || count_reset),
        .Q(count)
    );

    // FSM States
    assign data_ready = data1_ready & data2_ready;

    //// Transition States
    always_comb
        case (currState)
            WAIT: nextState = (data_ready && en) ? SEND : WAIT;
            // TODO: depending on timing, have space to optimize one clock cycle
            SEND: begin
                if (~en) nextState = WAIT;
                else if (count == 4'd10) nextState = DONE;
                else nextState = SEND;
            end
            DONE: nextState = WAIT;
        endcase

    //// Logic for each state
    always_comb begin
        count_en = 1'b0;
        count_reset = ~en;
        load = 1'b0;
        done = 1'b0;
        laser1_out = { mux1_out, en };
        laser2_out = 2'b0; // NOT Using IR laser

        case (currState)
            WAIT: load = data_ready;
            // TODO: depending on timing, have space to optimize one clock cycle
            SEND: begin
                count_en = 1'b1;
            end
            DONE: begin
                done = 1'b1;
                count_reset = 1'b1;
            end
        endcase
    end

    always_ff @(posedge clock_base, posedge reset) begin
        if (reset) currState <= WAIT;
        else currState <= nextState;
    end
endmodule: LaserTransmitter_DEPRICATED


// Laser Receiver module
// Listens in on laser1_in and laser2_in, asserting data_valid for a single
// clock cycle if a whole byte with valid start and stop bits read on both.
// NOTE: currently coded so this only works when data received simultaneously on
//       both lasers.
module LaserReceiver #(CLKS_PER_BIT=8)
    (input logic clock, reset,
     input logic laser_in,
     output logic data_valid,
     output logic [7:0] data_in);

    enum logic [2:0] {
        WAIT, START, RECEIVE, STOP, FINISH
    } currState, nextState;

    logic laser_in1, laser_in2, clk_ctr_en, clk_ctr_clear, bits_read_en,
        bits_read_clear;
    logic laser_in1, laser_in2;
    logic [7:0] clock_counter, bits_read;

    always_ff @(posedge clock) begin
        laser_in1 <= laser_in;
        laser_in2 <= laser_in1;
    end

    Counter #(8) clock_ctr (
        .D(8'b0),
        .en(clk_ctr_en),
        .clear(clk_ctr_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(clock_counter)
    );

    Counter #(8) bits_read_ctr (
        .D(8'b0),
        .en(bits_read_en),
        .clear(bits_read_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(bits_read)
    );

    // Referenced https://nandland.com/uart-serial-port-module/
    always_comb begin
        clk_ctr_clear = 1'b0;
        clk_ctr_en = 1'b0;
        bits_read_en = 1'b0;
        bits_read_clear = 1'b0;
        data_valid = 1'b0;

        case (currState)
            WAIT: begin
                clk_ctr_clear = 1'b1;
                bits_read_clear = 1'b0;

                if (laser_in == 1'b1) nextState = START;
                else nextState = WAIT;
            end
            START: begin
                if (clock_counter == ((CLKS_PER_BIT-1) >> 1'b1)) begin
                    if (laser_in == 1'b1) begin
                        clk_ctr_clear = 1'b1;
                        nextState = RECEIVE;
                    end
                    else nextState = WAIT;
                end
                else begin
                    clk_ctr_en = 1'b1;
                    nextState = START;
                end
            end
            RECEIVE: begin
                if (clock_counter < CLKS_PER_BIT - 1) begin
                    clk_ctr_en = 1'b1;
                    nextState = RECEIVE;
                end
                else begin
                    clk_ctr_clear = 1'b1;

                    if (bits_read < 8'd7) begin
                        bits_read_en = 1'b1;
                        nextState = RECEIVE;
                    end
                    else begin
                        bits_read_clear = 1'b1;
                        nextState = STOP;
                    end
                end
            end
            STOP: begin
                if (clock_counter < CLKS_PER_BIT - 8'b1) begin
                    clk_ctr_en = 1'b1;
                    nextState = STOP;
                end
                else begin
                    clk_ctr_clear = 1'b1;
                    if (laser_in == 1'b0) begin
                        nextState = FINISH;
                    end
		    else nextState = WAIT;
                end
            end
            FINISH: begin
                data_valid = 1'b1;
                nextState = WAIT;
            end
        endcase
    end

    always_ff @(posedge clock) begin
        if (currState == RECEIVE && clock_counter == CLKS_PER_BIT - 1) begin
            data_in[bits_read] <= laser_in;
        end
        else if (currState == WAIT) begin
            data_in <= 8'b0;
        end
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= WAIT;
        else currState <= nextState;
    end

endmodule: LaserReceiver


// Laser Receiver module
// Listens in on laser1_in and laser2_in, asserting data_valid for a single
// clock cycle if a whole byte with valid start and stop bits read on both.
// NOTE: currently coded so this only works when data received simultaneously on
//       both lasers.
module LaserReceiver_DEPRICATED
    (input logic clock, reset,
     input logic laser1_in, laser2_in, simultaneous_mode,
     output logic data_valid,
     output logic [7:0] data1_in, data2_in);

    enum logic [2:0] {
        WAIT, RECEIVE
    } currState, nextState;

    logic clock_en, clock_clear;
    logic vote_en, vote_clear, vote1_en, vote2_en;
    logic sampled_bit, byte_read, uart_valid;
    logic data1_start, data1_stop, data2_start, data2_stop;
    logic [9:0] data1_register, data2_register;
    logic [7:0] clock_counter, bits_read;
    logic [1:0] vote1, vote2;

    // NOTE: May become bottleneck if speed becomes extremely slow
    // eg. DIVIDER >= 8
    Counter #(8) counter_divided (
        .D(8'b1),
        .en(clock_en),
        .clear(1'b0),
        .load(clock_clear),
        .clock,
        .up(1'b1),
        .reset,
        .Q(clock_counter)
    );

    assign vote_en = (
        (clock_counter == 8'd4) | (clock_counter == 8'd5) |
        (clock_counter == 8'd3)
    );
    assign sampled_bit = (clock_counter == 8'd8);
    assign byte_read = (bits_read == 8'd9);

    assign vote1_en = vote_en && laser1_in;
    assign vote2_en = vote_en && laser2_in;

    assign vote_clear = sampled_bit;
    assign clock_clear = sampled_bit;

    assign uart_valid = byte_read;

    Counter #(8) num_bits (
        .D(8'b0),
        .en(sampled_bit),
        .clear(byte_read),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(bits_read)
    );

    Counter #(2) majority_vote1 (
        .D(2'b0),
        .en(vote1_en),
        .clear(vote_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(vote1)
    );

    Counter #(2) majority_vote2 (
        .D(2'b0),
        .en(vote2_en),
        .clear(vote_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(vote2)
    );

    ShiftRegister #(10) data_shift1 (
        .D(vote1[1]),
        .en(sampled_bit),
        .left(1'd0),
        .clock,
        .reset,
        .Q(data1_register)
    );

    ShiftRegister #(10) data_shift2 (
        .D(vote2[1]),
        .en(sampled_bit),
        .left(1'd0),
        .clock,
        .reset,
        .Q(data2_register)
    );

    Register #(9) data1 (
        .D(data1_register[9:1]),
        .en(uart_valid),
        .clear(1'b0),
        .reset,
        .clock,
        .Q({ data1_in, data1_start })   // Sent LSB first
    );

    Register #(9) data2 (
        .D(data2_register[9:1]),
        .en(uart_valid),
        .clear(1'b0),
        .reset,
        .clock,
        .Q({ data2_in, data2_start })
    );

    logic switch_to_wait;

    assign switch_to_wait = simultaneous_mode ?
        (byte_read | (bits_read == 8'b1 & ~data1_register[9] & ~data2_register[9])) :
        (byte_read | (bits_read == 8'b1 & (~data1_register[9] | ~data2_register[9])));

    always_comb begin
        case (currState)
            WAIT: nextState = WAIT;
            RECEIVE: nextState = switch_to_wait ? WAIT : RECEIVE;
        endcase
    end

    always_comb begin
        clock_en = 1'b0;
        case (currState)
            RECEIVE: clock_en = 1'b1;
        endcase
    end

    always_ff @(
        posedge laser1_in, posedge laser2_in, posedge reset, posedge clock
    ) begin
        if (reset) currState <= WAIT;
        else if (byte_read) currState <= WAIT;
        else if (laser1_in) currState <= RECEIVE;
        else if (laser2_in) currState <= RECEIVE;
    end

endmodule: LaserReceiver_DEPRICATED
