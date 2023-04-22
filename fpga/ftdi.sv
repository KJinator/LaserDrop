`default_nettype none

// FTDI Interface for asynchronous FIFO mode
module FTDI_Interface (
    input  logic clock, reset, rd_clear, wr_clear, clear, load_1k, debug_mode,
    input  logic txe, rxf, wrreq, rdreq, wr_en, rd_en, clock_start,
    input  logic [7:0] data_wr, adbus_in,
    output logic adbus_tri, ftdi_wr, ftdi_rd, rdq_full, rdq_empty, wrq_full,
                 wrq_empty,
    output logic [7:0] data_rd, adbus_out,
    output logic [9:0] wr_qsize,
    output logic [16:0] rd_qsize
);
    enum logic [3:0] {  WAIT, SET_WRITE, WRITE1, WRITE2, READ1, READ2, READ3,
                        READ4, READ5, FIN1, FIN2 }
        currState, nextState;

    enum logic [3:0] { WAIT_1K, LOAD_1K, WRITE_1K, PAD_1K }
        currState_1k, nextState_1k;

    logic [31:0] timer;
    logic [11:0] loaded_ct, qsize_saved;
    logic [ 7:0] data_1k, big_wrdata, timer_mux, adbus_in1, adbus_in2;
    logic   wrq_rdreq, store_rd, txe1, txe2, rxf1, rxf2, big_wrq_full,
            big_wrq_empty, rdreq_1k, big_wrreq, save_size, start_timer,
            load_ct_en, load_ct_clear, clock_start1, clock_start2;

    //// Datapath
    fifo_128k read_queue (
        .aclr(reset),
        .clock,
        .data(adbus_in2),
        .rdreq,
        .sclr(rd_clear || clear),
        .wrreq(store_rd),
        .empty(rdq_empty),
        .full(rdq_full),
        .q(data_rd),
        .usedw(rd_qsize)
    );

    // fifo_128k write_queue (
    //     .aclr(reset),
    //     .clock,
    //     .data(data_wr),
    //     .rdreq(wrq_rdreq),
    //     .sclr(clear || wr_clear),
    //     .wrreq(wrreq),
    //     .empty(wrq_empty),
    //     .full(wrq_full),
    //     .q(adbus_out),
    //     .usedw(wr_qsize)
    // );

    fifo_128k write_queue (
        .aclr(reset),
        .clock,
        .data(big_wrdata),
        .rdreq(wrq_rdreq),
        .sclr(clear),
        .wrreq(big_wrreq),
        .empty(big_wrq_empty),
        .full(big_wrq_full),
        .q(adbus_out),
        .usedw()
    );

    fifo_1k write_queue_pkt (
        .aclr(reset),
        .clock,
        .data(data_wr),
        .rdreq(rdreq_1k),
        .sclr(wr_clear || clear),
        .wrreq,
        .empty(wrq_empty),
        .full(wrq_full),
        .q(data_1k),
        .usedw(wr_qsize)
    );

    Register #(12) fifo_1k_size_reg (
        .D({ 1'b0, wrq_full, wr_qsize }),
        .en(save_size),
        .clear(1'b0),
        .clock,
        .reset,
        .Q(qsize_saved)
    );

    Counter #(12) loaded_counter (
        .D(12'b0),
        .en(load_ct_en),
        .clear(load_ct_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(loaded_ct)
    );

    Counter #(32) timer_counter (
        .D(32'b0),
        .en(start_timer),
        .clear(clock_start2),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(timer)
    );

    logic [11:0] loaded_idx;
    assign loaded_idx = loaded_ct - 12'd1021;
    ByteMultiplexer #(32) timer_multiplexer (
        .I(timer),
        .S_byte(loaded_idx[4:0]),
        .Y(timer_mux)
    );

    // Description:
    // WAIT: Give up Tri, set all lines inactive. State after READ/WRITE
    // == WRITE ==
    //      SET_WRITE: Assert ADBUS tri and set data (min 5ns)
    //      WRITE1: Pull write down     (min 30ns, 6-19ns keep DATA valid)
    //      WRITE2: Keep write down
    // == READ ==
    //      READ1: Pull read down       (1-14ns for data to arrive)
    //      READ2: Keep read down, store it in  (miin 30ns read low)
    //      READ3: Pull read back up    (RD remain low for 1-14ns)

    //// FSM Outputs
    always_comb begin
        adbus_tri = 1'b0;
        ftdi_wr = 1'b1;
        ftdi_rd = 1'b1;
        store_rd = 1'b0;

        case (currState)
            // NOTE: FTDI Chip: data setup time 5ns before write
            SET_WRITE: begin
                adbus_tri = 1'b1;
            end
            WRITE1: begin
                adbus_tri = 1'b1;
                ftdi_wr = 1'b0;
            end
            WRITE2: begin
                adbus_tri = 1'b1;
                ftdi_wr = 1'b0;
            end
            READ1: begin
                ftdi_rd = 1'b0;
            end
            // RD active pulse width: min 30ns
            READ2: begin
                ftdi_rd = 1'b0;
            end
            READ3: begin
                ftdi_rd = 1'b0;
            end
            READ4: begin
                ftdi_rd = 1'b0;
                store_rd = 1'b1;
            end
            READ5: begin
                ftdi_rd = 1'b0;
            end
        endcase
    end

    //// Next State Logic
    always_comb begin
        wrq_rdreq = 1'b0;
        case (currState)
            WAIT: begin
                if (!rxf2 && rd_en && !rdq_full) nextState = READ1;
                else if (wr_en && !txe2 && !big_wrq_empty) begin
                    nextState = SET_WRITE;
                    wrq_rdreq = 1'b1;
                end
                else nextState = WAIT;
            end
            SET_WRITE: nextState = WRITE1;
            WRITE1: nextState = WRITE2;
            WRITE2: nextState = FIN1;
            READ1: nextState = READ2;
            READ2: nextState = READ3;
            READ3: nextState = READ4;
            READ4: nextState = READ5;
            READ5: nextState = FIN1;
            FIN1: nextState = FIN2;
            FIN2: nextState = WAIT;
        endcase
    end

    // Next State Logic - 1k
    always_comb begin
        rdreq_1k = 1'b0;
        big_wrdata = 8'b0;
        big_wrreq = 1'b0;
        load_ct_en = 1'b0;
        load_ct_clear = 1'b0;
        save_size = 1'b0;

        case (currState_1k)
            WAIT_1K: begin
                nextState_1k = load_1k ? LOAD_1K : WAIT_1K;
                save_size = load_1k;
            end
            LOAD_1K: begin
                nextState_1k = LOAD_1K;

                if (loaded_ct == 12'd1024) begin
                    nextState_1k = WAIT_1K;
                    load_ct_clear = 1'b1;
                end
                else if (loaded_ct == qsize_saved) begin
                    nextState_1k = PAD_1K;
                    load_ct_en = 1'b1;
                end
                else if (!wrq_empty && !big_wrq_full) begin
                    nextState_1k = WRITE_1K;
                    rdreq_1k = 1'b1;
                    load_ct_en = 1'b1;
                end
            end
            WRITE_1K: begin
                nextState_1k = LOAD_1K;

                big_wrreq = 1'b1;
                if (debug_mode && loaded_ct >= 1021 && loaded_ct <= 12'd1024) begin
                    big_wrdata = timer_mux;
                end
                else if (debug_mode && data_1k[2:0] == 3'b110) begin
                    big_wrdata = start_timer ? loaded_ct[7:0] : 8'hff;
                end
                else big_wrdata = data_1k;
            end
            PAD_1K: begin
                if (loaded_ct == 12'd1024) begin
                    nextState_1k = WAIT_1K;
                    load_ct_clear = 1'b1;
                end
                else nextState_1k = PAD_1K;

                if (!big_wrq_full) begin
                    big_wrreq = 1'b1;
                    big_wrdata = (loaded_ct[2:0] == 3'b110 && debug_mode) ? loaded_ct[7:0] : 8'b0000_0001;
                    load_ct_en = 1'b1;
                end
            end
        endcase
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= WAIT;
        else if (clear) currState <= WAIT;
        else currState <= nextState;
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState_1k <= WAIT_1K;
        else if (clear) currState_1k <= WAIT_1K;
        else currState_1k <= nextState_1k;
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) start_timer <= 1'b0;
        else if (clock_start2) start_timer <= 1'b1;
    end

    // Metastability prevention
    always_ff @(posedge clock) begin
        txe1 <= txe;
        rxf1 <= rxf;
        adbus_in1 <= adbus_in;
        clock_start1 <= clock_start;
    end
    always_ff @(posedge clock) begin
        txe2 <= txe1;
        rxf2 <= rxf1;
        adbus_in2 <= adbus_in1;
        clock_start2 <= clock_start1;
    end
endmodule: FTDI_Interface
