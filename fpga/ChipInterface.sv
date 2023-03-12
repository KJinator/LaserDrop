`default_nettype none

// SW0 should ON/OFF the communication.
// The divider should be set to adjust the baud rate.

module ChipInterface (
    input  logic CLOCK_50,
    input  logic GPIO_1_D0, GPIO_1_D1, GPIO_1_D2, GPIO_1_D3,
    input  logic GPIO_1_D14, GPIO_1_D15, GPIO_1_D16, GPIO_1_D17,
    input  logic [9:0] SW,
    input  logic [3:0] KEY,
    output logic [17:0] LEDR,
    output logic [6:0] HEX5, HEX4, HEX1, HEX0,
    output logic GPIO_0_D14, GPIO_0_D15, GPIO_0_D16, GPIO_0_D17
);
    logic CLOCK_25, CLOCK_12_5, CLOCK_6_25;
    logic reset, data_valid;

    logic [7:0] data1_in, data2_in;

    assign reset = ~KEY[0];

    assign LEDR[0] = GPIO_1_D15;
    assign LEDR[1] = GPIO_0_D15;
    // assign LEDR[8] = GPIO_1_D16;
    // assign LEDR[9] = GPIO_1_D17;
    assign LEDR[8] = GPIO_1_D17;
    assign LEDR[9] = GPIO_0_D17;

    assign LEDR[6] = data_valid;
    /*
    ShiftRegisterQueue sample_data (
        .D(1'b1), // Change later
        .clock(CLOCK_12_5),
        .load(1'b1),
        .reset,
        .read(CLOCK_6_25),
        .full()
    );
    */

    LaserTransmitter transmit (
        .data_in1(8'h08),
        .data_in2(8'hff),
        .en(SW[0]),
        .clock(CLOCK_6_25),
        .reset,
        .data_ready1(1'b1),
        .data_ready2(1'b1),
        .laser1_out({ GPIO_0_D15, GPIO_0_D14 }),
        .laser2_out({ GPIO_0_D17, GPIO_0_D16 }),
        .done(LEDR[5])
    );

    LaserReceiver receive (
        .laser1_in(GPIO_1_D0),
        .laser2_in(GPIO_1_D17),
        // .laser1_in(GPIO_1_D15),
        // .laser2_in(GPIO_1_D17),
        .clock(CLOCK_50),
        .reset,
        .data_valid,
        .data1_in,
        .data2_in
    );

    ClockDivider clock_25 (
        .CLOCK_50,
        .reset,
        .en(SW[0]),
        .divider(8'b1),
        .clk_divided(CLOCK_25)
    );

    ClockDivider clock_12_5 (
        .CLOCK_50,
        .reset,
        .en(SW[0]),
        .divider(8'd4),
        .clk_divided(CLOCK_12_5)
    );

    ClockDivider clock_6_25 (
        .CLOCK_50,
        .reset,
        .en(SW[0]),
        .divider(8'd8),
        .clk_divided(CLOCK_6_25)
    );

    BCDtoSevenSegment laser1_1 (
        .bcd(data1_in[7:4]),
        .segment(HEX5)
    );

    BCDtoSevenSegment laser1_0 (
        .bcd(data1_in[3:0]),
        .segment(HEX4)
    );

    BCDtoSevenSegment laser2_1 (
        .bcd(data2_in[7:4]),
        .segment(HEX1)
    );

    BCDtoSevenSegment laser2_0 (
        .bcd(data2_in[3:0]),
        .segment(HEX0)
    );

endmodule: ChipInterface

// // Attempting 50MHz
// module ChipInterface (
//     input  logic       CLOCK_50,
//     input  logic [9:0] SW,
//     input  logic [3:0] KEY,
// 	 output logic [17:0] LEDR,
//     output logic [6:0] HEX0,
// 	 output logic GPIO_0_D0, GPIO_0_D1, GPIO_1_D0, GPIO_1_D1
// );
// 	enum logic [1:0] {
//         COUNT1, COUNT2, COUNT3
//     } currState, nextState;
// 	logic [2:0] divider;
// 	logic [7:0] counter;

// 	assign LEDR[0] = SW[0];

// 	always_comb begin
// 		if (SW[0]) begin
// 			GPIO_0_D0 = 'bz;
// 			GPIO_0_D1 = 'bz;
// 		end
// 		else if (SW[1]) begin
// 			GPIO_0_D0 = 'b1;
// 			GPIO_0_D1 = 'b1;
// 		end
// 		else begin
// 			GPIO_0_D0 = 'b0;
// 			GPIO_0_D1 = 'b0;
// 		end
// 	end

// endmodule: ChipInterface


/*
// Attempting 4 MHz
module ChipInterface (
    input  logic       CLOCK_50,
    input  logic [9:0] SW,
    input  logic [3:0] KEY,
     output logic [17:0] LEDR,
    output logic [6:0] HEX0,
     output logic GPIO_0_D0, GPIO_0_D1, GPIO_1_D0, GPIO_1_D1
);
    enum logic [1:0] {
        COUNT1, COUNT2, COUNT3
    } currState, nextState;
    logic [2:0] divider;
    logic [7:0] counter;

    assign LEDR[0] = SW[0];
    assign divider = 1;
    // Divider: max value 7
    // 0: 25M
    // 1: 12.5M
    // 2: 6.25M
    // 3: 3.125M
    // 4: 1.5625M
    // 5: 781.25kHz

    BCDtoSevenSegment bcd0 (
       .bcd({1'b0, divider[2:0]}),
       .segment(HEX0)
   );

    // GPIO outputs
    assign GPIO_0_D0 = counter[divider];
    assign GPIO_0_D1 = ~counter[divider];
    assign GPIO_1_D0 = counter[divider];
    assign GPIO_1_D1 = ~counter[divider];

    always_comb begin
        case (currState)
            COUNT1: nextState = COUNT2;
            COUNT2: nextState = COUNT3;
            COUNT3: nextState = COUNT1;
            default: nextState = COUNT1;
        endcase
    end

   always_ff @(posedge CLOCK_50) begin
        if (SW[0]) begin
            currState <= nextState;
            if (currState == COUNT1) begin
                counter <= counter + 1;
            end
        end
        else begin
            currState <= COUNT1;
            counter <= 0;
        end
    end

endmodule: ChipInterface
*/

/*
// Works with dividers
module ChipInterface (
    input  logic       CLOCK_50,
    input  logic [9:0] SW,
    input  logic [3:0] KEY,
     output logic [17:0] LEDR,
    output logic [6:0] HEX0,
     output logic GPIO_0_D0, GPIO_0_D1, GPIO_1_D0, GPIO_1_D1
);
   logic [2:0] divider;
    logic [7:0] counter;

    assign LEDR[0] = SW[0];
    assign divider = 0;
    // Divider: max value 7
    // 0: 25M
    // 1: 12.5M
    // 2: 6.25M
    // 3: 3.125M
    // 4: 1.5625M
    // 5: 781.25kHz

    BCDtoSevenSegment bcd0 (
       .bcd({1'b0, divider[2:0]}),
       .segment(HEX0)
   );

    // GPIO outputs
    assign GPIO_0_D0 = counter[divider];
    assign GPIO_0_D1 = ~counter[divider];
    assign GPIO_1_D0 = counter[divider];
    assign GPIO_1_D1 = ~counter[divider];

   always_ff @(posedge CLOCK_50) begin
        if (SW[0]) begin
            counter <= counter + 1;
        end
        else begin
            counter <= 0;
        end
    end

endmodule: ChipInterface
*/


/*
module ChipInterface (
    input  logic       CLOCK_50,
    input  logic [9:0] SW,
    input  logic [3:0] KEY,
    output logic [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0
);
    logic [63:0] counter;

    BCDtoSevenSegment bcd5 (
        .bcd(counter[63:60]),
        .segment(HEX5)
    );
     BCDtoSevenSegment bcd4 (
        .bcd(counter[59:56]),
        .segment(HEX4)
    );
     BCDtoSevenSegment bcd3 (
        .bcd(counter[55:52]),
        .segment(HEX3)
    );
     BCDtoSevenSegment bcd2 (
        .bcd(counter[39:36]),
        .segment(HEX2)
    );
     BCDtoSevenSegment bcd1 (
        .bcd(counter[35:32]),
        .segment(HEX1)
    );
     BCDtoSevenSegment bcd0 (
        .bcd(counter[31:28]),
        .segment(HEX0)
    );

   always_ff @(posedge CLOCK_50) begin
        counter <= counter + 1;
    end

endmodule: ChipInterface
*/

/*
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
          .clock(CLOCK_50),
        .counter_n(KEY[0]),
        .reset_n(KEY[3]),
        .count(counter)
   );

endmodule: ChipInterface
*/


/*
module SimpleFSM (
    input logic clock, reset_n,
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
    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            currState <= WAIT;
            count <= 4'd0;
        end
        else if (currState == COUNT) begin
            count <= count + 1;
                currState <= nextState;
        end
        else
            currState <= nextState;
    end

endmodule: SimpleFSM
*/

module BCDtoSevenSegment
(input logic [3:0] bcd, output logic [6:0] segment);

always_comb
    case (bcd)
        4'b0000: segment = 7'b100_0000;
        4'b0001: segment = 7'b111_1001;
        4'b0010: segment = 7'b010_0100;
        4'b0011: segment = 7'b011_0000;
        4'b0100: segment = 7'b001_1001;
        4'b0101: segment = 7'b001_0010; // 5
        4'b0110: segment = 7'b000_0010;
        4'b0111: segment = 7'b111_1000;
        4'b1000: segment = 7'b000_0000;
        4'b1001: segment = 7'b001_0000;
        4'b1010: segment = 7'b000_1000; // A
        4'b1011: segment = 7'b000_0011; // b
        4'b1100: segment = 7'b100_0110; // C
        4'b1101: segment = 7'b010_0001; // d
        4'b1110: segment = 7'b000_0110; // E
        4'b1111: segment = 7'b000_1110; // F
        default: segment = 7'b111_1111;
    endcase

endmodule: BCDtoSevenSegment
