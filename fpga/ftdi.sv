`default_nettype none

// FTDI Interface for asynchronous FIFO mode
module FTDI_Interface (
    input  logic clock, reset, clear,
    input  logic txe, rxf, wrreq, rdreq, wr_en, rd_en,
    input  logic [7:0] data_wr, adbus_in,
    output logic adbus_tri, ftdi_wr, ftdi_rd, rdq_full, rdq_empty, wrq_full,
                 wrq_empty,
    output logic [7:0] data_rd, adbus_out,
    output logic [9:0] qsize
);
    enum logic [3:0] { WAIT, SET_WRITE, WRITE1, WRITE2, READ1, READ2, READ3 }
        currState, nextState;

    logic wrq_rdreq, store_rd;

    //// Datapath
    fifo_1k read_queue (
        .aclr(reset),
        .clock,
        .data(adbus_in),
        .rdreq,
        .sclr(clear),
        .wrreq(store_rd),
        .empty(rdq_empty),
        .full(rdq_full),
        .q(data_rd),
        .usedw(qsize)
    );

    fifo_1k write_queue (
        .aclr(reset),
        .clock,
        .data(data_wr),
        .rdreq(wrq_rdreq),
        .sclr(clear),
        .wrreq,
        .empty(wrq_empty),
        .full(wrq_full),
        .q(adbus_out),
        .usedw()
    );

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
                store_rd = 1'b1;
            end
            // RD active pulse width: min 30ns
            READ2: begin
                ftdi_rd = 1'b0;
            end
        endcase
    end

    //// Next State Logic
    always_comb begin
        wrq_rdreq = 1'b0;
        case (currState)
            WAIT: begin
                if (!rxf && rd_en && !rdq_full) nextState = READ1;
                else if (wr_en && !txe && !wrq_empty) begin
                    nextState = SET_WRITE;
                    wrq_rdreq = 1'b1;
                end
                else nextState = WAIT;
            end
            SET_WRITE: nextState = WRITE1;
            WRITE1: nextState = WRITE2;
            WRITE2: nextState = WAIT;
            READ1: nextState = READ2;
            READ2: nextState = READ3;
            READ3: begin
                if (wr_en && !txe && !wrq_empty) begin
                    wrq_rdreq = 1'b1;
                    nextState = SET_WRITE;
                end
                else nextState = WAIT;
            end
        endcase
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) currState <= WAIT;
        else if (clear) currState <= WAIT;
        else currState <= nextState;
    end
endmodule: FTDI_Interface
