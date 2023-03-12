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
   input  logic             en, clear, clock,
   output logic [WIDTH-1:0] Q);
   
  always_ff @(posedge clock)
    if (clear)
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

// Shift Register Queue
// Takes in bits the size of WIDTH in serial, and outputs them as a 
// WIDTH bit data on read
// NOTE: Can only read when it's full. Can only write when it's not full.
module ShiftRegisterQueue
    #(parameter WIDTH=8)
    (input logic D, clock, load, reset,
    input logic read,
    output logic full, data_valid,
    output logic [WIDTH-1:0] data);

    logic [$clog2(WIDTH)-1:0] size;

    assign data_valid = full;
    assign full = (size == WIDTH);

    always_ff @(posedge clock, negedge reset) begin
        if (reset) begin
            data <= 'b0;
            size <= 'b0;
        end else if (load && ~full) begin
            data <= {(data << 1), D};
            size <= size + 1;
        end else if (read && full) begin
            data <= 'b0;
            size <= 'b0;
        end
    end
endmodule : ShiftRegisterQueue

// Shifts D 1 bit to left (left = 1) or right (left = 0)
// at clock edge, and outputs to Q.
// Priority: load > en
module ShiftRegister
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, left, load, clock,
   output logic [WIDTH-1:0] Q);
   
  always_ff @(posedge clock)
    if (load)
      Q <= D;
    else if (en)
      if (left)
        Q <= {Q[WIDTH-2:0], 1'b0};
      else
        Q <= {1'b0, Q[WIDTH-1:1]};
        
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