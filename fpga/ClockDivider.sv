`default_nettype none

// Divider should be >= 1 (else, why use a divider)
module ClockDivider (
    input  logic        CLOCK_50, reset, en,
    input  logic [7:0]  divider,
    output logic        clk_divided
);
    logic reset_count, count_en, clear_count;

    logic [7:0] counter;

    assign clear_count = reset || (counter == divider);

    Counter count (
        .D(8'b1),
        .en,
        .clear(1'b0),
        .load(clear_count),
        .clock(CLOCK_50),
        .up(1'b1),
        .reset,
        .Q(counter)
    );

    always_ff @(posedge CLOCK_50, posedge reset) begin
        // clear_count <= 1'b0;
        count_en <= en;
        if (reset) begin
            clk_divided <= 'b0;
            // clear_count <= 1'b1;
        end
        else if (~en) begin
            clk_divided <= 'b0;
        end
        else if (counter == divider) begin
            clk_divided <= ~clk_divided;
            // clear_count <= 1'b1;
        end

    end

endmodule: ClockDivider
