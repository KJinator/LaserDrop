`default_nettype none

// SW0 should ON/OFF the communication.
// The divider should be set to adjust the baud rate.

module ChipInterface (
    input  logic CLOCK_50,
    input  logic [9:0] SW,
    input  logic [3:0] KEY,
    output logic [17:0] LEDR,
    output logic [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
    inout  logic [35:0] GPIO_0, GPIO_1
);
    logic CLOCK_25, CLOCK_12_5, CLOCK_6_25;
    logic reset, data_valid;

    logic [7:0] data1_in, data2_in;

    //------------------FPGA Pin Configurations---------------------//
    logic [7:0] ADBUS;
    logic [9:0] ACBUS;
    logic [1:0] IR_TX, GREEN_TX;
    logic GREEN_AMB_n, GREEN_RX, GREEN_EN_n, IR_AMB_n, IR_RX, IR_EN_n;
    logic RESET_FTDI;

    // NOTE: For future, 1'bz becomes input, and any variable becomes output.
    // In order to do bidirectional, must do tri ? var : 1'bz
    assign GPIO_0[ 0] = ADBUS[7];
    assign GPIO_0[ 1] = ACBUS[9];
    assign GPIO_0[ 2] = ADBUS[6];
    assign GPIO_0[ 3] = ACBUS[8];
    assign GPIO_0[ 4] = ADBUS[5];
    assign GPIO_0[ 5] = ACBUS[7];
    assign GPIO_0[ 6] = ADBUS[4];
    assign GPIO_0[ 7] = ACBUS[6];
    assign GPIO_0[ 8] = ADBUS[3];
    assign GPIO_0[ 9] = ACBUS[5];
    assign GPIO_0[10] = ADBUS[2];
    assign GPIO_0[11] = ACBUS[4];
    assign GPIO_0[12] = ADBUS[1];
    assign GPIO_0[13] = ACBUS[3];
    assign GPIO_0[14] = ADBUS[0];
    assign GPIO_0[15] = ACBUS[2];
    assign GPIO_0[16] = IR_TX[1];
    assign GPIO_0[17] = ACBUS[1];
    assign GPIO_0[18] = IR_TX[0];
    assign GPIO_0[19] = ACBUS[0];
    assign GPIO_0[20] = GREEN_TX[1];
    assign GPIO_0[21] = RESET_FTDI;
    assign GPIO_0[22] = GREEN_TX[0];
    assign GPIO_0[23] = 1'bz;
    assign GPIO_0[24] = GREEN_AMB_n;
    assign GPIO_0[25] = 1'bz;
    assign GPIO_0[26] = 1'bz;
    assign GPIO_0[27] = 1'bz;
    assign GPIO_0[28] = GREEN_EN_n;
    assign GPIO_0[29] = 1'bz;
    assign GPIO_0[30] = IR_AMB_n;
    assign GPIO_0[31] = 1'bz;
    assign GPIO_0[32] = 1'bz;
    assign GPIO_0[33] = 1'bz;
    assign GPIO_0[34] = IR_EN_n;
    assign GPIO_0[35] = 1'bz;

    // These should always be inputs
    assign GREEN_RX = GPIO_0[26];
    assign IR_RX = GPIO_0[32];

    // Pin counts: 7 High z, 18 Bus, 4 TX, 2 RX, 5 Misc
    assign ADBUS = 8'bz;
    assign ACBUS = 10'bz;

    // Pull-up, pull-down resistor exist. Output should be high z
    assign GREEN_EN_n = 1'bz;       // default 0 (on)
    assign IR_EN_n = 1'bz;
    assign GREEN_AMB_n = 1'bz;      // default 0 (on)
    assign IR_AMB_n = 1'bz;
    assign RESET_FTDI = 1'bz;       // default


    assign GPIO_1 = { 36'bz };
    //--------------------------------------------------------------//

    assign reset = ~KEY[0];

    assign LEDR[1:0] = GREEN_TX;
    assign LEDR[3:2] = IR_TX;
    // assign LEDR[8] = GPIO_1[16];
    // assign LEDR[9] = GPIO_1[17];
    assign LEDR[8] = GREEN_RX;
    assign LEDR[9] = IR_RX;

    assign LEDR[5] = data_valid;

    logic [7:0] data1_transmit, data2_transmit;
    assign data1_transmit = SW[9] ? 8'h12 : 8'hc8;
    assign data2_transmit = SW[8] ? 8'h34 : 8'h77;

    LaserDrop main ();
	 
    // Need to use clock at double the speed because using posedge (1/2)
    LaserTransmitter transmit (
        .data1_transmit(data1_transmit),
        .data2_transmit(data2_transmit),
        .en(SW[0]),
        .clock(CLOCK_12_5),
        .reset,
        .data1_ready(1'b1),
        .data2_ready(1'b1),
        .laser1_out(GREEN_TX),
        .laser2_out(IR_TX),
        .done(LEDR[4])
    );

    LaserReceiver receive (
        .laser1_in(GREEN_RX),
        .laser2_in(IR_RX),
        .clock(CLOCK_50),
        .reset,
        .data_valid,
        .data1_in,
        .data2_in
    );

    ClockDivider clock_25 (
        .clk_base(CLOCK_50),
        .reset,
        .en(1'b1),
        .divider(8'b1),
        .clk_divided(CLOCK_25)
    );

    ClockDivider clock_12_5 (
        .clk_base(CLOCK_50),
        .reset,
        .en(1'b1),
        .divider(8'd4),
        .clk_divided(CLOCK_12_5)
    );

    ClockDivider clock_6_25 (
        .clk_base(CLOCK_50),
        .reset,
        .en(1'b1),
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

    assign HEX3 = 7'b111_1111;
    assign HEX2 = 7'b111_1111;

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
