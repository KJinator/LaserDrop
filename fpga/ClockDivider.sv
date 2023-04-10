`default_nettype none

// Divider should be >= 1 (else, why use a divider)
module ClockDivider (
    input  logic        clk_base, en, reset,
    input  logic [7:0]  divider,
    output logic        clk_divided
);
    logic reset_count, count_en, clear_count;

    logic [7:0] counter, divider_half;

    assign divider_half = divider >> 1'b1;

    assign clear_count = reset || (counter == divider_half);

    Counter count (
        .D(8'b1),
        .en,
        .clear(1'b0),
        .load(clear_count),
        .clock(clk_base),
        .up(1'b1),
        .reset,
        .Q(counter)
    );

    always_ff @(posedge clk_base, posedge reset) begin
        if (reset) begin
            clk_divided <= 'b0;
        end
        else if (~en) begin
            clk_divided <= 'b0;
        end
        else if (counter == divider_half) begin
            clk_divided <= ~clk_divided;
        end

    end

endmodule: ClockDivider
