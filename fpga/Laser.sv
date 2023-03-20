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
`define TIMEOUT_RX_LEN  8'd40
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
    input logic rxf, laser1_rx, laser2_rx,
    input logic [7:0] adbus_in,
    output logic ftdi_rd, ftdi_wr, tx_done, adbus_tri, data_valid,
    output logic [1:0] laser1_tx, laser2_tx,
    output logic [7:0] data1_in, data2_in, adbus_out
);
    logic [511:0]   rx, rx_D, read, read_D;
    logic [  9:0]   rd_ct, tx_ct, rx_ct;
    logic [  7:0]   timeout_ct, data1_tx, data2_tx,
                    data1_in_sim, data2_in_sim, data1_in_test, data2_in_test,
                    dummy_data1, dummy_data2;
    logic [  3:0]   saw_consecutive;
    logic           CLOCK_25, CLOCK_12_5, CLOCK_6_25;
    logic           timeout, data_valid_sim, data_valid_test, finished_hs,
                    data1_valid_test, data2_valid_test, data1_ready,
                    data2_ready, store_rd, store_rx,
                    saw_consecutive_en, rd_ct_en, rx_ct_en, timeout_ct_en, 
                    saw_consecutive_clear, timeout_ct_clear, rd_ct_clear,
                    tx_ct_clear, rx_ct_clear;

    //----------------------------LASER TRANSMITTER---------------------------//
    // Need to use clock at double the speed because using posedge (1/2)
    assign data1_tx = read[tx_ct*8 + 7:tx_ct*8];
    assign data2_tx = read[(tx_ct+1)*8 + 7:(tx_ct+1)*8];
    assign data1_ready = tx_ct < rd_ct;
    assign data2_ready = (tx_ct + 1) < rd_ct;

    LaserTransmitter transmit (
        .data1_transmit(data1_tx),
        .data2_transmit(data2_tx),
        .en,
        .clock(CLOCK_12_5),
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
    LaserReceiver receive (
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

    LaserReceiver receive1 (
        .laser1_in(laser1_rx),
        .laser2_in(1'b0),
        .clock,
        .simultaneous_mode(1'b0),
        .reset,
        .data_valid(data2_valid_test),
        .data1_in(data1_in_test),
        .data2_in(dummy_data2)
    );
    LaserReceiver receive2 (
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
        .clock,
        .Q(read)
    );

    Register #(512) rx_input (
        .D(rx_D),
        .en(store_rx),
        .clear(1'b0),
        .clock,
        .Q(rx)
    );
    //------------------------------------------------------------------------//
    //-----------------------------LOGIC COMPONENTS---------------------------//
    Counter #(10) rd_counter (
        .D(1'b0),
        .en(rd_ct_en),
        .clear(rd_ct_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(rd_ct)
    );

    Counter #(10) timeout_counter (
        .D(1'b0),
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
        .clock,
        .Q(tx_ct)
    );

    Register #(10) rx_counter (
        .D(rx_ct + 10'd2),
        .en(rx_ct_en),
        .clear(rx_ct_clear),
        .clock,
        .Q(rx_ct)
    );

    Counter #(4) hs_counter (
        .D(1'b0),
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
    enum logic [4:0] {
        RESET, HS_TX_INIT, HS_TX_INIT2, HS_TX_FIN, HS_TX_FIN2,
        LOAD_READ, WAIT_READ, RECEIVE, WAIT_RESEND
    } currState, nextState;

    assign finished_hs = saw_consecutive == 4'd4;
    assign timeout = timeout_ct == `TIMEOUT_RX_LEN;

    always_comb begin
        adbus_tri = 1'b0;
        data1_ready = 1'b0;
        data2_ready = 1'b0;
        data1_tx = 8'b0000_0000;
        data2_tx = 8'b0000_0000;
        saw_consecutive_en = 1'b0;
        saw_consecutive_clear = 1'b0;
        ftdi_rd = 1'b1;
        ftdi_wr = 1'b1;
        store_rd = 1'b0;
        rd_ct_en = 1'b0;
        store_rx = 1'b0;
        rx_ct_clear = 1'b0;
        rx_ct_en = 1'b0;
        timeout_ct_en = 1'b0;
        timeout_ct_clear = 1'b0;
        read_D = read;

        case (currState)
            HS_TX_INIT: begin
                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
                if (data_valid && data1_in == `HS_RX_LASER1 && data2_in == `HS_RX_LASER2)
                    saw_consecutive_en = 1'b1;
                else saw_consecutive_clear = 1'b1;
            end
            HS_TX_INIT2: begin
                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
                timeout_ct_en = 1'b1;
            end
            LOAD_READ: begin
                adbus_tri = 1'b0;
                ftdi_rd = 1'b0;
                store_rd = 1'b1;
                rd_ct_en = 1'b1;
                if (rd_ct == 10'b0)
                    read_D = { read[511:8], adbus_in };
                else if (rd_ct >= (`MAX_RD_CT - 1))
                    read_D = { adbus_in, read[503:0] };
                else
                    read_D = { read[511:(rd_ct+1)*8], adbus_in, read[rd_ct*8-1:0] };
            end
            WAIT_READ: begin
                adbus_tri = 1'b0;
                ftdi_rd = 1'b1;
            end
            RECEIVE: begin
                store_rx = data_valid;
                rx_ct_en = data_valid;
                if (rx_ct == 10'b0)
                    rx_D = { rx[511:16], laser2_in, laser1_in };
                else if (rx_ct >= (`MAX_RX_CT - 2))
                    rx_D = { laser2_in, laser1_in, rx[495:0] };
                else
                    rx_D = { rx[511:(rx_ct+2)*8], laser2_in, laser1_in, rx[rx_ct*8-1:0] };
            end
            HS_TX_FIN: begin
                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
                if (data_valid && data1_in == `HS_RX_LASER1 && data2_in == `HS_RX_LASER2)
                    saw_consecutive_en = 1'b1;
                else saw_consecutive_clear = 1'b1;
            end
            HS_TX_FIN2: begin
                data1_ready = 1'b1;
                data2_ready = 1'b1;
                data1_tx = `HS_TX_LASER1;
                data2_tx = `HS_TX_LASER2;
                timeout_ct_en = 1'b1;
            end
        endcase
    end

    //-------------------------STATE TRANSITION LOGIC-------------------------//
    always_comb begin
        rd_ct_clear = 1'b0;
        tx_ct_clear = 1'b0;
        case (currState)
            RESET: begin
                if (~rxf) nextState = HS_TX_INIT;
                else nextState = RESET;
            end
            HS_TX_INIT: begin
                nextState = finished_hs ? HS_TX_INIT2 : HS_TX_INIT;
                timeout_ct_clear = finished_hs;
            end
            HS_TX_INIT2: begin
                nextState = (timeout_ct >= 8'd2) ? LOAD_READ : HS_TX_INIT2;
                rd_ct_clear = timeout_ct >= 8'd2;
                tx_ct_clear = timeout_ct >= 8'd2;
            end
            LOAD_READ: nextState = WAIT_READ;
            WAIT_READ:
                // NOTE: Should never be >
                if ((read[7:0] == `START_SEQ && rd_ct == `START_PKT_LEN && tx_ct >= `START_PKT_LEN) ||
                    (read[7:0] == `STOP_SEQ && rd_ct == `STOP_PKT_LEN && tx_ct >= `STOP_PKT_LEN)) begin
                    nextState = RECEIVE;
                    rx_ct_clear = 1'b1;
                end
                // Transmission less. Wait until all packets sent over lasers
                else if (rxf ||
                         (read[7:0] == `START_SEQ && rd_ct == `START_PKT_LEN) ||
                         (read[7:0] == `STOP_SEQ && rd_ct == `STOP_PKT_LEN))
                    nextState = WAIT_READ;
                else nextState = LOAD_READ;
            RECEIVE:
                if (data_valid && rx[7:0] == `ACK_SEQ) begin
                    nextState = LOAD_READ;
                    tx_ct_clear = 1'b1;
                    rd_ct_clear = 1'b1;
                end
                else if (data_valid && rx[7:0] == `DONE_SEQ)
                    nextState = HS_TX_FIN;
                else if (timeout || data_valid) begin
                    nextState = WAIT_RESEND;
                    tx_ct_clear = 1'b1;
                end
                else nextState = RECEIVE;
            WAIT_RESEND:
                if ((read[7:0] == `START_SEQ && tx_ct == `START_PKT_LEN) ||
                    (read[7:0] == `STOP_SEQ && tx_ct == `STOP_PKT_LEN))
                    nextState = RECEIVE;
                else nextState = WAIT_RESEND;
            HS_TX_FIN: begin
                nextState = finished_hs ? HS_TX_FIN2 : HS_TX_FIN;
                timeout_ct_clear = finished_hs;
            end
            HS_TX_FIN2: nextState = (timeout_ct >= 8'd2) ? RESET : HS_TX_FIN2;
        endcase
    end
    //------------------------------------------------------------------------//

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= RESET;
        else currState <= nextState;
    end
endmodule: LaserDrop

// Laser Transmission module
// Transmits data_in on data_out if data_ready is asserted. Asserts done when
// transmission finished.
// NOTE: Currently, configured so it only transmits if both lasers are ready.
module LaserTransmitter(
    input logic [7:0] data1_transmit, data2_transmit,
    input logic en, clock, reset, data1_ready, data2_ready,
    output logic [1:0] laser1_out, laser2_out,
    output logic done
);
    logic [7:0] data1, data2;
    logic [10:0] data1_compiled, data2_compiled;
    logic [3:0] count;
    logic data_ready, load, count_en, count_clear, mux1_out, mux2_out;

    enum logic { WAIT, SEND } currState, nextState;

    Register laser1_data (
        .D(data1_transmit),
        .en(load),
        .clear(1'b0),
        .clock(clock),
        .Q(data1)
    );

    Register laser2_data (
        .D(data2_transmit),
        .en(load),
        .clear(1'b0),
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
        .clear(count_clear),
        .load(1'b0),
        .clock(clock),
        .up(1'b1),
        .reset(reset),
        .Q(count)
    );

    // FSM States
    assign data_ready = data1_ready & data2_ready;

    //// Transition States
    always_comb
        case (currState)
            WAIT: nextState = (data_ready && en) ? SEND : WAIT;
            // TODO: depending on timing, have space to optimize one clock cycle
            SEND: nextState = (count == 4'd10 || ~en) ? WAIT : SEND;
        endcase

    //// Logic for each state
    always_comb begin
        count_en = 1'b0;
        count_clear = ~en;
        load = 1'b0;
        done = 1'b0;
        laser1_out = { mux1_out, en };
        laser2_out = { mux2_out, en };

        case (currState)
            WAIT: load = data_ready;
            // TODO: depending on timing, have space to optimize one clock cycle
            SEND: begin
                count_en = 1'b1;
                count_clear = count == 4'd10;
                done = count == 4'd10;
            end
        endcase
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= WAIT;
        else currState <= nextState;
    end

endmodule: LaserTransmitter


// Laser Receiver module
// Listens in on laser1_in and laser2_in, asserting data_valid for a single
// clock cycle if a whole byte with valid start and stop bits read on both.
// NOTE: currently coded so this only works when data received simultaneously on
//       both lasers.
module LaserReceiver
    (input logic clock, reset,
     input logic laser1_in, laser2_in, simultaneous_mode,
     output logic data_valid,
     output logic [7:0] data1_in, data2_in);

    enum logic [2:0] {
        WAIT, RECEIVE
    } currState, nextState;

    logic clock_en, clock_clear, clock_divided;
    logic vote_en, vote_clear, vote1_en, vote2_en;
    logic sampled_bit, byte_read;
    logic data1_start, data1_stop, data2_start, data2_stop;
    logic [9:0] data1_register, data2_register;
    logic [7:0] clock_counter, bits_read;
    logic [1:0] vote1, vote2, receive_sel_D, receive_sel;

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
    assign byte_read = (bits_read == 8'd10);

    assign vote1_en = vote_en && laser1_in;
    assign vote2_en = vote_en && laser2_in;

    assign vote_clear = sampled_bit;
    assign clock_clear = sampled_bit;

    assign data_valid = simultaneous_mode ?
        (byte_read & ~data1_register[9] & ~data2_register[9]) :
        (byte_read & (~data1_register[9] | ~data2_register[9]));

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

    Register #(10) data1 (
        .D(data1_register),
        .en(data_valid),
        .clear(1'b0),
        .clock,
        .Q({ data1_stop, data1_in, data1_start })   // Sent LSB first
    );

    Register #(10) data2 (
        .D(data2_register),
        .en(data_valid),
        .clear(1'b0),
        .clock,
        .Q({ data2_stop, data2_in, data2_start })
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
        posedge laser1_in, posedge laser2_in, posedge reset, posedge byte_read
    ) begin
        if (reset) currState <= WAIT;
        else if (byte_read) currState <= WAIT;
        else if (laser1_in) currState <= RECEIVE;
        else if (laser2_in) currState <= RECEIVE;
    end

endmodule: LaserReceiver
