`default_nettype none

module TB;
  logic clock, resetN;

  logic [1:0][5:0][6:0] HEX_D;
  wire  [1:0][35:0] GPIO_0, GPIO_1;
  wire  [1:0][17:0] ledr;
  reg   [1:0][7:0] ADBUS;

  ChipInterface dut (
    .CLOCK_50(clock),
    .GPIO_0(GPIO_0[0]),
    .GPIO_1(GPIO_1[0]),
    .SW({ 1'b0, 1'b0, 6'b0, 2'b01 }),
    .KEY({ 3'b1, resetN }),
    .LEDR(ledr[0]),
    .HEX5(HEX_D[0][5]),
    .HEX4(HEX_D[0][4]),
    .HEX3(HEX_D[0][3]),
    .HEX2(HEX_D[0][2]),
    .HEX1(HEX_D[0][1]),
    .HEX0(HEX_D[0][0])
  );

  assign GPIO_0[0][26] = GPIO_0[0][20];
  assign GPIO_0[0][32] = GPIO_0[0][16];

  assign {
    GPIO_0[0][ 0], GPIO_0[0][ 2], GPIO_0[0][ 4], GPIO_0[0][ 6],
    GPIO_0[0][ 8], GPIO_0[0][10], GPIO_0[0][12], GPIO_0[0][14]
  } = ADBUS[0];

  initial begin
    clock = 1'b0;

    forever #5 clock = ~clock;
  end

  logic [1:0] rxf, txe;
  logic [1:0] rxf_tri, txe_tri;
  initial begin
    // $monitor(
    //   "@%0t: rxf: %b (%b), txe: %b (%b)", $time, rxf, rxf_tri, txe, txe_tri);
    #500000

    $display("@%0t: Error timeout!", $time);
    $finish;
  end

  logic [7:0] num_pkt_rx;
  parameter num_pkts = 2;

  assign rxf_tri = 2'b11;
  assign txe_tri = 2'b11;
  assign GPIO_0[0][19] = rxf_tri[0] ? rxf[0] : 1'bz;   // rxf
  assign GPIO_0[0][17] = txe_tri[0] ? txe[0] : 1'bz;   // txe
  assign GPIO_0[1][19] = rxf_tri[1] ? rxf[1] : 1'bz;
  assign GPIO_0[1][17] = txe_tri[1] ? txe[1] : 1'bz;

  initial begin
    txe[0] = 1'b1;
    rxf[0] = 1'b1;
    ADBUS[0] = 8'dz;

    #20;
    fork
      #10;
      for (int num_pkt = 0; num_pkt < num_pkts; num_pkt++) begin
        rxf[0] = 1'b0;
        wait(~dut.main.ftdi_rd); #1;

        for (int byte_num=1; byte_num < 128; byte_num++) begin
          #2
          rxf[0] = 1'b0;

          wait(~dut.main.ftdi_rd); #1
          ADBUS[0] = byte_num;
          wait(dut.main.ftdi_rd); #1
          ADBUS[0] = 8'dz;
          rxf[0] = 1'b1;
        end
      end
    join_none
    fork
      #10;
      forever begin
        txe[0] = 1'b0;
        wait(~dut.main.ftdi_wr); #1
        txe[0] = 1'b1;
        #1;
      end
    join_none
  end

  initial begin
    // resetN = 1'b1;
    // resetN <= 1'b0;
    resetN = 1'b1;
    #1 resetN = 1'b0;
    #1
    resetN = 1'b1;

    for (int i = 0; i < 10; i++) begin
      @(posedge dut.main.data_valid);
      @(posedge dut.main.data_valid);
      @(posedge dut.main.data_valid);
    end
    #100;

    $display("@%0t: Data1: %h, Data2: %h", $time,
             dut.hex1, dut.hex2
            );
    $display("@%0t: Finished!", $time);
    $finish;
  end

endmodule : TB
