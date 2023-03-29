`default_nettype none

// FTDI Interface for asynchronous FIFO mode
module FTDI_Interface (
    input  logic clock, reset, clear,
    input  logic txe, data_wr_valid, tx_en, rxf, rd_en, rd_ct_clear,
    input  logic [  7:0] data_wr, adbus_in,
    input  logic [  9:0] max_rd_ct,
    output logic adbus_tri, ftdi_wr, read_data, ftdi_rd,
    output logic [  7:0] adbus_out,
    output logic [  9:0] rd_ct,
    output logic [511:0] read
);
    logic rd_ct_en, store_rd;
    logic [511:0] read_D;

    enum logic [2:0] { WAIT, SET_WRITE, WRITE1, WRITE2, LOAD_READ }
        currState, nextState;

    //// Datapath
    Counter #(10) Read_Ctr (
        .D(10'b0),
        .en(rd_ct_en),
        .clear(clear || rd_ct_clear),
        .load(1'b0),
        .clock,
        .up(1'b1),
        .reset,
        .Q(rd_ct)
    );

    Register #(512) Read_Reg (
        .D(read_D),
        .en(store_rd),
        .clear(clear || rd_ct_clear),
        .reset,
        .clock,
        .Q(read)
    );

    //// FSM Outputs
    always_comb begin
        adbus_tri = 1'b0;
        adbus_out = 8'b0;
        read_data = 1'b0;
        ftdi_wr = 1'b1;
        ftdi_rd = 1'b1;
        read_D = 512'b0;

        case (currState)
            // NOTE: FTDI Chip: data setup time 5ns before write
            SET_WRITE: adbus_out = data_wr;
            WRITE1: begin
                adbus_tri = 1'b1;
                ftdi_wr = 1'b0;
                adbus_out = data_wr;
            end
            WRITE2: begin
                adbus_tri = 1'b1;
                ftdi_wr = 1'b0;
                adbus_out = data_wr;
                read_data = 1'b1;
            end
            LOAD_READ: begin
                ftdi_rd = 1'b0;
                store_rd = 1'b1;
                rd_ct_en = 1'b1;
                read_D = (
                    (read & ~(512'hff << ({3'd0, rd_ct} << 3))) +
                    ({504'd0, adbus_in} << ({3'd0, rd_ct} << 3))
                );
            end
        endcase
    end

    //// Next State Logic
    always_comb
        case (currState)
            WAIT: begin
                if (!rxf && rd_en && rd_ct < max_rd_ct) nextState = LOAD_READ;
                else if (wr_en && !txe && data_wr_valid) nextState = SET_WRITE;
            end
            SET_WRITE: nextState = WRITE1;
            WRITE1: nextState = WRITE2;
            WRITE2: nextState = WAIT_WRITE;
            LOAD_READ: nextState = WAIT;
        endcase

    always_ff @(posedge clock, posedge reset) begin
        if (reset || clear) currState <= WAIT_WRITE;
        else currState <= nextState;
    end
endmodule: FTDI_Interface
