`default_nettype none

module TB;
  logic clock, resetN;

  logic [1:0][5:0][6:0] HEX_D;
  wire  [1:0][35:0] GPIO_0, GPIO_1;
  wire  [1:0][17:0] ledr;
  reg   [1:0][7:0] ADBUS;

  ChipInterface dut_tx (
    .CLOCK_50(clock),
    .GPIO_0(GPIO_0[0]),
    .GPIO_1(GPIO_1[0]),
    .SW({ 9'b0, 1'b1 }),
    .KEY({ 3'b1, resetN }),
    .LEDR(ledr[0]),
    .HEX5(HEX_D[0][5]),
    .HEX4(HEX_D[0][4]),
    .HEX3(HEX_D[0][3]),
    .HEX2(HEX_D[0][2]),
    .HEX1(HEX_D[0][1]),
    .HEX0(HEX_D[0][0])
);

  ChipInterface dut_rx (
    .CLOCK_50(clock),
    .GPIO_0(GPIO_0[1]),
    .GPIO_1(GPIO_1[1]),
    .SW({ 9'b0, 1'b1 }),
    .KEY({ 3'b1, resetN }),
    .LEDR(ledr[1]),
    .HEX5(HEX_D[1][5]),
    .HEX4(HEX_D[1][4]),
    .HEX3(HEX_D[1][3]),
    .HEX2(HEX_D[1][2]),
    .HEX1(HEX_D[1][1]),
    .HEX0(HEX_D[1][0])
  );

  assign GPIO_0[0][26] = GPIO_0[1][20];
  assign GPIO_0[0][32] = GPIO_0[1][16];

  assign GPIO_0[1][26] = GPIO_0[0][20];
  assign GPIO_0[1][32] = GPIO_0[0][16];

  assign {
    GPIO_0[0][ 0], GPIO_0[0][ 2], GPIO_0[0][ 4], GPIO_0[0][ 6],
    GPIO_0[0][ 8], GPIO_0[0][10], GPIO_0[0][12], GPIO_0[0][14]
  } = ADBUS[0];

  assign {
    GPIO_0[1][ 0], GPIO_0[1][ 2], GPIO_0[1][ 4], GPIO_0[1][ 6],
    GPIO_0[1][ 8], GPIO_0[1][10], GPIO_0[1][12], GPIO_0[1][14]
  } = ADBUS[1];

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
        wait(~dut_tx.main.ftdi_rd); #1;

        if (num_pkt < num_pkts - 1) begin
          ADBUS[0] = `START_SEQ;
          wait(dut_tx.main.ftdi_rd); #1
          ADBUS[0] = 8'dz;
          rxf[0] = 1'b1;

          for (int byte_num=1; byte_num < `START_PKT_LEN; byte_num++) begin
            #2
            rxf[0] = 1'b0;

            wait(~dut_tx.main.ftdi_rd); #1
            ADBUS[0] = byte_num;
            wait(dut_tx.main.ftdi_rd); #1
            ADBUS[0] = 8'dz;
            rxf[0] = 1'b1;
          end
        end
        else begin
          ADBUS[0] = `STOP_SEQ;
          wait(dut_tx.main.ftdi_rd); #1
          ADBUS[0] = 8'dz;
          rxf[0] = 1'b1;

          #2;
          rxf[0] = 1'b0;
          wait(~dut_tx.main.ftdi_rd); #1
          ADBUS[0] = 8'd1;
          wait(dut_tx.main.ftdi_rd); #1
          ADBUS[0] = 8'dz;
          rxf[0] = 1'b1;
        end
      end
    join_none
    fork
      #10;
      forever begin
        txe[0] = 1'b0;
        wait(~dut_tx.main.ftdi_wr); #1
        txe[0] = 1'b1;
        #1;
      end
    join_none
  end

  initial begin
    txe[1] = 1'b1;
    rxf[1] = 1'b1;
    ADBUS[1] = 8'dz;
    #10;
    for (num_pkt_rx = 0; num_pkt_rx < num_pkts; num_pkt_rx++) begin
      int pkt_len;
      /*
      if (num_pkt_rx == num_pkts - 1) begin
        pkt_len = `STOP_PKT_LEN;
      end else
        pkt_len = `START_PKT_LEN;
      */
      pkt_len = (num_pkt_rx == num_pkts - 1) ? (`STOP_PKT_LEN) : (`START_PKT_LEN);
      $display("Pkt_len: %d", pkt_len);
      for (int i = 0; i < pkt_len; i++) begin
        txe[1] = 1'b0;
        @(posedge ~dut_rx.main.ftdi_wr);
        @(posedge clock);
        txe[1] = 1'b1;
      end

      $display("@%0t: Pulling rxf[1] down at line 155", $time);
      rxf[1]  = 1'b0;
      wait(~dut_rx.main.ftdi_rd);

      if (num_pkt_rx < num_pkts - 1) begin
        ADBUS[1] = `ACK_SEQ;
        @(posedge dut_rx.main.ftdi_rd); #1;
        ADBUS[1] = 8'dz;
        rxf[1] = 1'b1;

        #2;
        rxf[1] = 1'b0;

        wait(~dut_rx.main.ftdi_rd); #1;
        ADBUS[1] = 8'h77;
        wait(dut_rx.main.ftdi_rd); #1;
        ADBUS[1] = 8'dz;
        rxf[1] = 1'b1;
      end
      else begin
        ADBUS[1] = `DONE_SEQ;
        wait(dut_rx.main.ftdi_rd); #1;
        ADBUS[1] = 8'dz;
        rxf[1] = 1'b1;

        #2;
        rxf[1] = 1'b0;
        wait(~dut_rx.main.ftdi_rd); #1;
        ADBUS[1] = 8'd1;
        wait(dut_rx.main.ftdi_rd); #1;
        ADBUS[1] = 8'dz;
        rxf[1] = 1'b1;
      end
    end
  end


  initial begin
    resetN = 1'b1;
    resetN <= 1'b0;
    #1
    resetN = 1'b1;

    for (int i = 0; i < 10; i++) begin
      @(posedge dut_tx.main.data_valid);
      @(posedge dut_tx.main.data_valid);
      @(posedge dut_tx.main.data_valid);
    end
    #100;

    $display("@%0t: Data1: %h, Data2: %h", $time,
             dut_tx.data1_in,
             dut_tx.data2_in
            );
    $display("@%0t: Finished!", $time);
    $finish;
  end

endmodule : TB
