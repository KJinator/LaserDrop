`default_nettype none

// This library is taken from the code that I wrote last semester in 18-240.

// Take in A and B, returns if A < B, A = B, A > B
module MagComp
  #(parameter   WIDTH = 8)
  (output logic             AltB, AeqB, AgtB,
   input  logic [WIDTH-1:0] A, B);

  assign AeqB = (A == B);
  assign AltB = (A <  B);
  assign AgtB = (A >  B);

endmodule: MagComp

// Take in A and B, returns sum. Can take in and outputs carry.
module Adder
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] A, B,
   input  logic             Cin,
   output logic [WIDTH-1:0] S,
   output logic             Cout);

   assign {Cout, S} = A + B + Cin;

endmodule : Adder

// A multiplexer that takes in a variable and return a bit specfied by
// S to its output Y.
module Multiplexer
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0]         I,
   input  logic [$clog2(WIDTH)-1:0] S,
   output logic                     Y);

   assign Y = I[S];

endmodule : Multiplexer


// Takes in 2 logic values of any length WIDTH and chooses one of the logics
// with S. Outputs to Y.
module Mux2to1
  #(parameter WIDTH = 8)
  (input  logic [WIDTH-1:0] I0, I1,
   input  logic             S,
   output logic [WIDTH-1:0] Y);

  assign Y = (S) ? I1 : I0;

endmodule : Mux2to1

// Outputs D, whose bit is 1 at specified location by I.
module Decoder
  #(parameter WIDTH=8)
  (input  logic [$clog2(WIDTH)-1:0] I,
   input  logic                     en,
   output logic [WIDTH-1:0]         D);

  always_comb begin
    D = 0;
    if (en)
      D = 1'b1 << I;
  end

endmodule : Decoder

// A register with D input and Q outputs.
// Priority: en > clear, checked at clock edge.
module Register
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, clear, clock, reset,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock, posedge reset)
    if (clear || reset)
      Q <= 0;
    else if (en)
      Q <= D;

endmodule : Register

// Adds 1 to Q at each clock edge.
// Priority: clear > load > en
// When up enabled, +1 and -1 if not enabled.
// clear loads 0 and load loads D onto Q
module Counter
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, clear, load, clock, up, reset,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock, posedge reset) begin
    if (reset)
	    Q <= 0;
	  else if (clear)
		  Q <= 0;
    else if (load)
      Q <= D;
    else if (en)
      if (up)
        Q <= Q + 1'b1;
      else
        Q <= Q - 1'b1;
  end

endmodule : Counter

module ShiftRegister
  #(parameter WIDTH=8)
  (input  logic             D, en, left, clock, reset,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock, posedge reset)
    if (reset)
      Q <= 'b0;
    else if (en)
      if (left)
        Q <= {Q[WIDTH-2:0], D};
      else
        Q <= {D, Q[WIDTH-1:1]};

endmodule : ShiftRegister

// Shifts D by specified bit, by (max 3 bit),to the left.
// Priority: load > en
module BarrelShiftRegister
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, load, clock,
   input  logic [      1:0] by,
   output logic [WIDTH-1:0] Q);

  logic [WIDTH-1:0] shifted;
  always_comb
    case (by)
      default: shifted = Q;
      2'b01: shifted = {Q[WIDTH-2:0], 1'b0};
      2'b10: shifted = {Q[WIDTH-3:0], 2'b0};
      2'b11: shifted = {Q[WIDTH-4:0], 3'b0};
    endcase

always_ff @(posedge clock)
    if (load)
        Q <= D;
    else if (en)
        Q <= shifted;

endmodule : BarrelShiftRegister

module LaserDropQueue
  #(parameter   DATA_LOAD=2)
  (input  logic [15:0] D,
   input  logic        clock, load, read, reset, clear,
   output logic [ 7:0] Q,
   output logic [ 7:0] size,
   output logic        empty, full);

  logic [63:0][7:0] queue;
  logic [ 5:0] write_i, read_i;

  assign Q = queue[read_i];
  assign empty = (size == 7'd0);
  assign full = (size == 7'd64);

  always_ff @(posedge clock, posedge reset) begin
    if (reset || clear) begin
      queue <= 512'd0;
      size <= 8'b0;
      read_i <= 6'b0;
      write_i <= 6'b0;
    end
    else begin
      if (read && !empty) begin
        read_i <= read_i + 6'd1;
        size <= size - 8'd1;
      end
      if (load && !full) begin
        queue[write_i+DATA_LOAD-1:write_i] <= D;
        write_i <= write_i + DATA_LOAD;
        size <= size + DATA_LOAD;
      end
    end
  end
endmodule: LaserDropQueue

module ByteMultiplexer
  #(parameter WIDTH=512)
  (input  logic [WIDTH-1:0]               I,
   input  logic [$clog2(WIDTH >> 3)-1:0]  S_byte,
   output logic [7:0]                     Y);

  logic [$clog2(WIDTH >> 3)-1:0] S_bit;
  S_bit = {3'b0, S_byte} << 3;

  assign Y = I[S_bit+7:S_bit];

endmodule : ByteMultiplexer

// A memory with addressing, read and write options, and
// tristate data bus, triggered at clock.
module Memory
  #(parameter AW=8, DW=16)
  (input  logic [AW-1:0] address,
   inout  tri   [DW-1:0] data,
   input  logic          re, we, clock);

  localparam WORDS = 2 ** AW;

  logic [DW-1:0] M[WORDS];
  logic [DW-1:0] out;

  assign data = (re) ? out: {DW {1'bz}};

  always_ff @(posedge clock)
    if (we)
      M[address] <= data;

  always_comb
    out = M[address];

endmodule : Memory
