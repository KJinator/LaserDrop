`default_nettype none

module LaserTransmitter(
    input logic [7:0] data_in1, data_in2,
    input logic en, clock, reset, data_ready1, data_ready2,
    output logic [1:0] laser1_out, laser2_out,
    output logic done
);
    logic [7:0] data1, data2;
    logic [3:0] count;
    logic data_ready, load, count_en, count_clear;

    enum logic [1:0] {RESET, WAIT, SEND}
        currState, nextState;

    Register laser1_data (
        .D(data_in1),
        .en(load),
        .clear(),
        .clock(clock),
        .Q(data1)
    );

    Register laser2_data (
        .D(data_in2),
        .en(load),
        .clear(),
        .clock(clock),
        .Q(data2)
    );

    Multiplexer #(10) laser1_mux (
        .I({ 1'b1, data_in1, 1'b0 }),
        .S(count),
        .Y(laser1_out[1])
    );

    Multiplexer #(10) laser2_mux (
        .I({ 1'b1, data_in2, 1'b0 }),
        .S(count),
        .Y(laser2_out[1])
    );

    // Passive. Always on when transmitting to reduce laser switching time
    assign laser1_out[0] = en;
    assign laser2_out[0] = en;

    Counter #(4) (
        .D('b0),
        .en(count_en),
        .clear(count_clear),
        .load(),
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
     output logic [7:0] data1_in, data2_in);

    logic clock_en, clock_clear;
    logic [7:0] clock_divided;

    assign data1_in = 8'h12;
    assign data2_in = 8'h34;

    // NOTE: May become bottleneck if speed becomes extremely slow
    // eg. DIVIDER >= 8
    Counter #(8) counter_divided (
        .D('b1),
        .en(clock_en),
        .clear(1'b0),
        .load(clock_clear),
        .clock,
        .up(1'b1),
        .reset,
        .Q(clock_divided)
    );

    always_ff @(posedge laser1_in, laser2_in, clock_divided[DIVIDER]) begin
        if (laser1_in && laser2_in && currState == WAIT) begin
            currState <= RECEIVE;
        end
    end
endmodule: LaserReceiver