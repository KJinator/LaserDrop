`default_nettype none

module LaserTransmitter(
    input logic [7:0] data_in1, data_in2,
    input logic en, clock, reset, data_ready1, data_ready2,
    output logic [1:0] laser1_out, laser2_out,
    output logic done
);
    logic [7:0] data1, data2;
    logic [10:0] data1_compiled, data2_compiled;
    logic [3:0] count;
    logic data_ready, load, count_en, count_clear, mux1_out, mux2_out;

    enum logic [1:0] {RESET, WAIT, SEND}
        currState, nextState;

    Register laser1_data (
        .D(data_in1),
        .en(load),
        .clear(1'b0),
        .clock(clock),
        .Q(data1)
    );

    Register laser2_data (
        .D(data_in2),
        .en(load),
        .clear(1'b0),
        .clock(clock),
        .Q(data2)
    );

    assign data1_compiled = { data_in1, 1'b1, 1'b0};
    assign data2_compiled = { data_in2, 1'b1, 1'b0};

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
    assign data_ready = data_ready1 & data_ready2;

    //// Transition States
    always_comb
        case (currState)
            RESET: nextState = WAIT;
            WAIT: nextState = data_ready ? SEND : WAIT;
            // TODO: depending on timing, have space to optimize one clock cycle
            SEND: nextState = (count == 'd10) ? WAIT : SEND;
        endcase

    //// Logic for each state
    always_comb begin
        count_en = 'b0;
        count_clear = 'b0;
        load = 'b0;
        done = 'b0;
        laser1_out = { mux1_out, en };
        laser2_out = { mux2_out, en };

        case (currState)
            WAIT: load = data_ready;
            // TODO: depending on timing, have space to optimize one clock cycle
            SEND: begin
                count_en = 'b1;
                count_clear = count == 'd10;
                done = count == 'd10;
            end
        endcase
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= RESET;
        else currState <= nextState;
    end

endmodule: LaserTransmitter


module LaserReceiver
    #(parameter DIVIDER=3)
    (input logic clock, reset,
     input logic laser1_in, laser2_in,
     output logic data_valid,
     output logic [7:0] data1_in, data2_in);

    enum logic [2:0] {
        WAIT, RECEIVE
    } currState, nextState;

    logic clock_en, clock_clear, clock_divided;
    logic vote_en, vote_clear, vote1_en, vote2_en;
    logic byte_read, data1_start, data1_end, data2_start, data2_end;
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
        (clock_counter == 'd4) | (clock_counter == 'd5) |
        (clock_counter == 'd3)
    );
    assign vote1_en = vote_en && laser1_in;
    assign vote2_en = vote_en && laser2_in;
    assign vote_clear = (clock_counter == 'd8);
    assign clock_clear = (clock_counter == 'd8);
    assign byte_read = (bits_read == 'd10);
    // TODO: Change
    assign data_valid = byte_read;

    Counter #(8) num_bits (
        .D(8'b0),
        .en(clock_counter == 'd8),
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
        .en(clock_counter == 'd8),
        .left(1'd0),
        .clock,
        .reset,
        .Q(data1_register)
    );

    ShiftRegister #(10) data_shift2 (
        .D(vote2[1]),
        .en(clock_counter == 'd8),
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
        .Q({ data1_start, data1_in, data1_end })
    );

    Register #(10) data2 (
        .D(data2_register),
        .en(byte_read),
        .clear(1'b0),
        .clock,
        .Q({ data2_start, data2_in, data2_end })
    );

    always_comb begin
        case (currState)
            WAIT: nextState <= WAIT;
            RECEIVE: nextState <= byte_read ? WAIT : RECEIVE;
        endcase
    end

    always_comb begin
        clock_en = 1'b0;
        case (currState)
            RECEIVE: begin
                clock_en = 1'b1;
            end
        endcase
    end

    always_ff @(
        posedge laser1_in, posedge laser2_in, posedge clock, posedge reset
    ) begin
        if (reset) currState <= WAIT;
        else if (laser1_in) currState <= RECEIVE;
        else if (laser2_in) currState <= RECEIVE;
        else currState <= nextState;
    end

endmodule: LaserReceiver
