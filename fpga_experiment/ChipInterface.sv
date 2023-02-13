`default_nettype none

// KEY0 (BUTTON0) should reset the system

// A module that takes in 3 matrix: A (128x128), B (128x1), C (128x1) and
// returns the sum of matrix Y, where Y = (A * B) + C.

// When SW0 is off, it shows the sum of Y and when SW0 is on, it shows the
// number of clock cycles it took to calculate this value.
module ChipInterface (
    input  logic       CLOCK_50,
    input  logic [9:0] SW,
    input  logic [3:0] KEY,
    output logic [6:0] HEX5
);
    logic [3:0] counter;

    BCDtoSevenSegment bcd (
        .bcd(counter),
        .segment(HEX5)
    );
   
   SimpleFSM DUT (
        .clock(KEY[0]),
        .reset(KEY[3]),
        .count(counter)
   );

endmodule: ChipInterface



module SimpleFSM (
    input logic clock, reset,
    input logic counter_n,
    output logic [3:0] count
);
    enum logic [1:0] {
        WAIT, COUNT, WAIT_RELEASE, DONE
    } currState, nextState;
    logic counterPressed, counterPressed2, counterReleased, counterReleased2;

    // Next state logic
    always_comb begin
        nextState = currState;
        if (currState == WAIT) begin
            if (counterPressed2) begin
                nextState = COUNT;
            end
        end
        else if (currState == COUNT) begin
            nextState = WAIT_RELEASE;
        end
        else if (currState == WAIT_RELEASE) begin
            if (counterReleased2) begin
                nextState = WAIT;
            end
        end            
    end

    // Avoid metastability for keys
    always_ff @(posedge clock) begin
        counterPressed <= ~counter_n;
        counterReleased <= counter_n;
    end
    always_ff @(posedge clock) begin
        counterPressed2 <= counterPressed;
        counterReleased2 <= counterReleased;
    end

    // Next State transitions
    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            currState <= WAIT;
            count <= 4'd0;
        end
        else if (currState == COUNT) begin
            count <= count + 1;
        end
        else
            currState <= nextState;
    end

endmodule: SimpleFSM

module BCDtoSevenSegment
(input logic [3:0] bcd, output logic [6:0] segment);

always_comb 
    case (bcd)
        4'b0000: segment = 7'b100_0000;
        4'b0001: segment = 7'b111_1001;
        4'b0010: segment = 7'b010_0100;
        4'b0011: segment = 7'b011_0000;
        4'b0100: segment = 7'b001_1001;
        4'b0101: segment = 7'b001_0010;
        4'b0110: segment = 7'b000_0010;
        4'b0111: segment = 7'b111_1000;
        4'b1000: segment = 7'b000_0000;
        4'b1001: segment = 7'b001_0000;
        default: segment = 7'b111_1111;
    endcase

endmodule: BCDtoSevenSegment