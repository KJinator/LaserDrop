`default_nettype none

module Echo (
    input logic clock, reset, en, non_sim_mode,
    input logic rxf, txe, laser1_rx, laser2_rx,
    input logic [7:0] adbus_in,
    output logic ftdi_rd, ftdi_wr, tx_done, adbus_tri, data_valid,
    output logic [1:0] laser1_tx, laser2_tx,
    output logic [7:0] data1_in, data2_in, adbus_out
);
    logic [63:0] read;
    logic [  9:0] rd_ct, wr_ct;
    logic [  7:0] q_size, q_out, data_wr;
    logic q_empty, q_full, data_wr_read, data_wr_valid, clear_counters;

    assign clear_counters = rd_ct == 10'd64 && wr_ct == 10'd64;

    EchoQueue echo_queue (
        .D(adbus_in),
        .clock,
        .load(~ftdi_rd),
        .read(data_wr_read),
        .reset,
        .clear(clear_counters),
        .Q(q_out),
        .size(q_size),
        .empty(q_empty),
        .full(q_full)
    );

    Counter #(10) wr_counter (
        .D(10'b0),
        .en(data_wr_read),
        .clear(clear_counters),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(wr_ct)
    );

    // NOTE: nonsim_mode uses queue, else uses ftdi_if and bytemux
    assign data_wr_valid = non_sim_mode ? ~q_empty : (rd_ct > wr_ct);
    assign data_wr = non_sim_mode ? q_out : wr_ct[7:0];

    FTDI_Interface ftdi_if (
        .clock,
        .reset,
        .clear(1'b0),
        .txe,
        .data_wr_valid,
        .wr_en(en),
        .rxf,
        .rd_en(en),
        .rd_ct_clear(clear_counters),
        .data_wr,
        .adbus_in,
        .max_rd_ct(10'd64),
        .adbus_tri,
        .ftdi_wr,
        .data_wr_read,
        .ftdi_rd,
        .adbus_out,
        .rd_ct,
        .read
    );

    ByteMultiplexer recent_read (
        .I(read),
        .S_byte(wr_ct),
        .Y(data2_in)
    );

    always_comb begin
        tx_done = 1'b0;
        data_valid = 1'b0;
        laser1_tx = 2'b0;
        laser2_tx = 2'b0;
        data1_in = rd_ct[7:0];
    end


endmodule: Echo
