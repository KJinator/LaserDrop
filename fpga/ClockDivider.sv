`default_nettype none

// Divider should be >= 1 (else, why use a divider)
module ClockDivider (
    input  logic        CLOCK_50, reset, en,
    input  logic [7:0]  divider,
    output logic        clk_divided
);
    logic [7:0] divider_new;
    logic reset_count, count_en, clear_count;

    // By defualt, cuts clock in half because only changing values at posedge
    // NOTE: divider=0 will behave the same way as divider=1
    assign divider_new = divider >> 1;
	 assign clear_count = reset;

    logic [7:0] counter;

    Counter count (
        .D(8'b0),
        .en(count_en),
        .clear(clear_count),
        .load(1'b0),
        .clock(CLOCK_50),
        .up(1'b1),
        .reset,
        .Q(counter)
    );

    always_ff @(posedge CLOCK_50, negedge reset) begin
        // clear_count <= 1'b0;
        count_en <= en;
        if (!reset) begin
            clk_divided <= 'b0;
            // clear_count <= 1'b1;
        end
        else if (~en) begin
            clk_divided = 'b0;
        end
        else if (counter == divider_new) begin
            clk_divided = ~clk_divided;
            // clear_count <= 1'b1;
        end

    end

endmodule: ClockDivider
