module TB;
  logic clock, resetN;

  logic [6:0] HEX_D[6];
  wire [35:0] GPIO_0, GPIO_1;
  wire [17:0] ledr;

  ChipInterface dut (
    .CLOCK_50(clock),
    .GPIO_0,
    .GPIO_1,
    .SW({ 9'b0, 1'b1 }),
    .KEY({ 3'b1, resetN }),
    .LEDR(ledr),
    .HEX5(HEX_D[5]),
    .HEX4(HEX_D[4]),
    .HEX3(HEX_D[3]),
    .HEX2(HEX_D[2]),
    .HEX1(HEX_D[1]),
    .HEX0(HEX_D[0])
);

  assign GPIO_0[26] = GPIO_0[20];
  assign GPIO_0[32] = GPIO_0[16];

  initial begin
    clock = 1'b0;

    forever #5 clock = ~clock;
  end

  initial begin
    #100000

    $display("@%0t: Error timeout!", $time);
    $finish;
  end

  initial begin
    resetN = 1'b1;
    resetN <= 1'b0;
    #1
    resetN <= 1'b1;

    @(posedge dut.data_valid);
    #100

    $display("@%0t: Data1: %h, Data2: %h", $time, dut.data1_in, dut.data2_in);
    $display("@%0t: Finished!", $time);
    $finish;
  end

endmodule : TB
