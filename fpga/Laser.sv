`default_nettype none

`define START_PKT_LEN   10'd512
`define STOP_PKT_LEN    10'd6
`define ACK_PKT_LEN     10'd4
`define FAIL_PKT_LEN    10'd4
`define DONE_PKT_LEN    10'd2

`define START_SEQ       8'hcc
`define STOP_SEQ        8'h55
`define ACK_SEQ         8'h11
`define FAIL_SEQ        8'hbb
`define DONE_SEQ        8'haa

// NOTE: may need to increase depending on how fast CPU interface is
`define TIMEOUT_RX_LEN  8'd40

// SYNTAX NOTES
// rx/tx: In reference to laser transmission and receiver
// read/send: In reference to FTDI chip in/out

module LaserDrop (
    input logic clock, reset,
    input logic data_valid, rxf,
    input logic [511:0] rx
);
    logic finished_hs, timeout;
    logic [511:0]   read;
    logic [  9:0]   read_ct, tx_ct;
    logic [  7:0]   timeout_ct;
    logic [  3:0]   saw_consecutive;

    enum logic [4:0] {
        RESET, HS_INIT_TX, HS_FIN_TX,
        LOAD_READ, WAIT_READ, RECEIVE, WAIT_RESEND
    } currState, nextState;

    assign finished_hs = saw_consecutive >= 4'd4;
    assign timeout = timeout_ct == `TIMEOUT_RX_LEN;

    // State transition logic
    always_comb begin
        case (currState)
            RESET:
                if (rxf) nextState = HS_INIT_TX;
                else nextState = RESET;
            HS_INIT_TX: nextState = finished_hs ? LOAD_READ : HS_INIT_TX;
            LOAD_READ: nextState = WAIT_READ;
            WAIT_READ:
                // NOTE: Should never be >
                if ((read[7:0] == `START_SEQ && read_ct == `START_PKT_LEN && tx_ct >= `START_PKT_LEN) ||
                    (read[7:0] == `STOP_SEQ && read_ct == `STOP_PKT_LEN && tx_ct >= `STOP_PKT_LEN))
                    nextState = RECEIVE;
                // Transmission less. Wait until all packets sent over lasers
                else if (rxf ||
                         (read[7:0] == `START_SEQ && read_ct == `START_PKT_LEN) ||
                         (read[7:0] == `STOP_SEQ && read_ct == `STOP_PKT_LEN))
                    nextState = WAIT_READ;
                else nextState = LOAD_READ;
            RECEIVE:
                if (data_valid && rx[7:0] == `ACK_SEQ) nextState = LOAD_READ;
                else if (data_valid && rx[7:0] == `DONE_SEQ) nextState = HS_FIN_TX;
                else if (timeout || data_valid) nextState = WAIT_RESEND;
                else nextState = RECEIVE;
            WAIT_RESEND:
                if ((read[7:0] == `START_SEQ && tx_ct == `START_PKT_LEN) ||
                    (read[7:0] == `STOP_SEQ && tx_ct == `STOP_PKT_LEN))
                    nextState = RECEIVE;
                else nextState = WAIT_RESEND;
            HS_FIN_TX: nextState = finished_hs ? LOAD_READ : HS_FIN_TX;
        endcase
    end

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
     input logic laser1_in, laser2_in,
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
    assign byte_read = (bits_read == 8'd10);

    assign vote1_en = vote_en && laser1_in;
    assign vote2_en = vote_en && laser2_in;

    assign vote_clear = sampled_bit;
    assign clock_clear = sampled_bit;
    
    // TODO: SWITCH
    // assign data_valid = byte_read;
    assign data_valid = (byte_read & ~data1_register[9] & ~data2_register[9]);

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
        .en(byte_read),
        .clear(1'b0),
        .clock,
        .Q({ data1_stop, data1_in, data1_start })   // Sent LSB first
    );

    Register #(10) data2 (
        .D(data2_register),
        .en(byte_read),
        .clear(1'b0),
        .clock,
        .Q({ data2_stop, data2_in, data2_start })
    );

    logic switch_to_wait;

    assign switch_to_wait = byte_read || (
        bits_read == 8'b1 && (!data1_register[9] || !data2_register[9]) 
    );

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
