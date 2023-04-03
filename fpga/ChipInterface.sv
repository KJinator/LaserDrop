`default_nettype none

// SW0 should ON/OFF the communication.
// The divider should be set to adjust the baud rate.

module ChipInterface (
    input  logic CLOCK_50,
    input  logic [9:0] SW,
    input  logic [3:0] KEY,
    output logic [17:0] LEDR,
    output logic [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
    inout  wire  [35:0] GPIO_0, GPIO_1
);
    logic data_valid, tx_done, adbus_tri;
    logic [7:0] data1_in, data2_in;

    //------------------------FPGA Pin Configurations-------------------------//
    logic [7:0] ADBUS, ADBUS_IN;
    logic [9:0] ACBUS;
    logic [1:0] IR_TX, GREEN_TX;
    logic   GREEN_AMB_n, GREEN_RX, GREEN_EN_n, IR_AMB_n, IR_RX, IR_EN_n,
            RESET_FTDI;

    // NOTE: For future, 1'bz becomes input, and any variable becomes output.
    // In order to do bidirectional, must do tri ? var : 1'bz
    assign GPIO_0[ 0] = adbus_tri ? ADBUS[7] : 1'bz;
    assign GPIO_0[ 1] = ACBUS[9];
    assign GPIO_0[ 2] = adbus_tri ? ADBUS[6] : 1'bz;
    assign GPIO_0[ 3] = ACBUS[8];       // ? ACBUS8
    assign GPIO_0[ 4] = adbus_tri ? ADBUS[5] : 1'bz;
    assign GPIO_0[ 5] = ACBUS[7];       // ? PWRSAV
    assign GPIO_0[ 6] = adbus_tri ? ADBUS[4] : 1'bz;
    assign GPIO_0[ 7] = ACBUS[6];       // ? ACBUS6
    assign GPIO_0[ 8] = adbus_tri ? ADBUS[3] : 1'bz;
    assign GPIO_0[ 9] = ACBUS[5];       // ? ACBUS5
    assign GPIO_0[10] = adbus_tri ? ADBUS[2] : 1'bz;
    assign GPIO_0[11] = ACBUS[4];       // ? SIWU
    assign GPIO_0[12] = adbus_tri ? ADBUS[1] : 1'bz;
    assign GPIO_0[13] = ACBUS[3];       // Output WR
    assign GPIO_0[14] = adbus_tri ? ADBUS[0] : 1'bz;
    assign GPIO_0[15] = ACBUS[2];       // Output RD
    assign GPIO_0[16] = IR_TX[1];
    assign GPIO_0[17] = 1'bz;           // Input: TXE (AC1)
    assign GPIO_0[18] = IR_TX[0];
    assign GPIO_0[19] = 1'bz;           // Input: RXF (AC0)
    assign GPIO_0[20] = GREEN_TX[1];
    assign GPIO_0[21] = RESET_FTDI;
    assign GPIO_0[22] = GREEN_TX[0];
    assign GPIO_0[23] = 1'bz;
    assign GPIO_0[24] = GREEN_AMB_n;
    assign GPIO_0[25] = 1'bz;
    assign GPIO_0[26] = 1'bz;           // Input: Green RX
    assign GPIO_0[27] = 1'bz;
    assign GPIO_0[28] = GREEN_EN_n;     // Output: High-Z
    assign GPIO_0[29] = 1'bz;
    assign GPIO_0[30] = IR_AMB_n;
    assign GPIO_0[31] = 1'bz;
    assign GPIO_0[32] = 1'bz;           // Input: IR RX
    assign GPIO_0[33] = 1'bz;
    assign GPIO_0[34] = IR_EN_n;        // Output: High-Z
    assign GPIO_0[35] = 1'bz;

    // These should always be inputs
    assign GREEN_RX = GPIO_0[26];
    assign IR_RX = GPIO_0[32];

    assign ADBUS_IN = { GPIO_0[0], GPIO_0[2], GPIO_0[4], GPIO_0[6], GPIO_0[8], GPIO_0[10], GPIO_0[12], GPIO_0[14] };
    assign ACBUS[0] = GPIO_0[19];       // RXF
    assign ACBUS[1] = GPIO_0[17];       // TXE

    // Pin counts: 7 High z, 18 Bus, 4 TX, 2 RX, 5 Misc
    assign ACBUS[9:4] = 6'bz;

    // Pull-up, pull-down resistor exist. Output should be high z
    assign GREEN_EN_n = 1'bz;                       // default 1 (on)
    assign IR_EN_n = 1'bz;                          // default 1 (on)
    assign GREEN_AMB_n = SW[9] ? 1'b1 : 1'b0;       // default 0 (on)
    assign IR_AMB_n = SW[9] ? 1'b1 : 1'b0;          // default 0 (on)
    assign RESET_FTDI = 1'bz;                       // default

    assign GPIO_1 = { 36'bz };
    //------------------------------------------------------------------------//
    //------------------------------DUT DECLARATION---------------------------//
    assign LEDR[1:0] = GREEN_TX;
    assign LEDR[3:2] = IR_TX;
    assign LEDR[8] = GREEN_RX;
    assign LEDR[9] = IR_RX;
    assign LEDR[4] = tx_done;

    LaserDrop main (
        .clock(CLOCK_50),
        .reset(~KEY[0]),
        .en(SW[0]),
        .echo_mode(SW[1]),
        .rxf(ACBUS[0]),
        .txe(ACBUS[1]),
        .laser1_rx(GREEN_RX),
        .laser2_rx(IR_RX),
        .adbus_in(ADBUS_IN),
        .laser1_tx(GREEN_TX),
        .laser2_tx(IR_TX),
        .data_valid(LEDR[5]),
        .ftdi_rd(ACBUS[2]),
        .ftdi_wr(ACBUS[3]),
        .tx_done,
        .adbus_tri,
        .data1_in,
        .data2_in,
        .adbus_out(ADBUS)
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
