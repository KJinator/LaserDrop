`default_nettype none

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
    logic [7:0] clock_counter, bits_read;

    always_ff @(posedge clock) begin
        laser_in1 <= laser_in;
    end

    always_ff @(posedge clock) begin
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

    always_comb begin
        clk_ctr_clear = 1'b0;
        clk_ctr_en = 1'b0;
        bits_read_en = 1'b0;
        bits_read_clear = 1'b0;
        data_valid = 1'b0;

        case (currState)
            WAIT: begin
                clk_ctr_clear = 1'b1;
                bits_read_clear = 1'b1;

                if (laser_in2 == 1'b1) nextState = START;
                else nextState = WAIT;
            end
            START: begin
                if (clock_counter == ((CLKS_PER_BIT-1) >> 1'b1)) begin
                    if (laser_in2 == 1'b1) begin
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
                if (clock_counter < CLKS_PER_BIT - 1) begin
                    clk_ctr_en = 1'b1;
                    nextState = STOP;
                end
                else begin
                    clk_ctr_clear = 1'b1;
                    // nextState = FINISH;
                    if (laser_in2 == 1'b0) begin
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
            data_in[bits_read] <= laser_in2;
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
