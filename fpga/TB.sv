module TB;
  logic clock, resetN;

  logic [6:0] HEX_D[6];
  logic [3:0] gpio;
  logic [17:0] ledr;

  ChipInterface dut (
    .CLOCK_50(clock),
    .GPIO_1_D14(gpio[0]),
    .GPIO_1_D15(gpio[1]),
    .GPIO_1_D16(gpio[2]),
    .GPIO_1_D17(gpio[3]),
    .SW({ 9'b0, 1'b1 }),
    .KEY({ 3'b1, resetN }),
    .LEDR(ledr),
    .HEX5(HEX_D[5]),
    .HEX4(HEX_D[4]),
    .HEX1(HEX_D[1]),
    .HEX0(HEX_D[0]),
    .GPIO_0_D14(gpio[0]),
    .GPIO_0_D15(gpio[1]),
    .GPIO_0_D16(gpio[2]),
    .GPIO_0_D17(gpio[3])
);


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
