//Some basic datapath modules for building hardware threads
//Author: Fan Bu

`default_nettype none

module MagComp
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] A,
   input logic [WIDTH-1:0] B,
   output logic AltB, AeqB, AgtB);

   assign AltB = A < B;
   assign AeqB = A == B;
   assign AgtB = A > B;

endmodule: MagComp

module Adder
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] A,
   input logic [WIDTH-1:0] B,
   input logic Cin,
   output logic [WIDTH-1:0] S,
   output logic Cout);

   assign {Cout,S} = A + B + Cin;

endmodule: Adder

module Multiplexer
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] I,
   input logic [$clog2(WIDTH)-1:0] S,
   output logic Y);

   assign Y = I[S];

endmodule: Multiplexer

module Mux2to1
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] I0,
   input logic [WIDTH-1:0] I1,
   input logic S,
   output logic [WIDTH-1:0] Y);

   assign Y = S ? I1 : I0;

endmodule: Mux2to1

module Decoder
  #(parameter WIDTH = 8)
  (input logic [$clog2(WIDTH)-1:0] I,
   input logic en,
   output logic [WIDTH-1:0] D);

   always_comb begin
       D = 0;
       if (en) D[I] = 1'b1;
   end

endmodule: Decoder

module Register
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] D,
   input logic en, clear, clock,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock)
    if (en)
      Q <= D;
    else if (clear)
      Q <= 0;

endmodule: Register

module Counter
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] D,
   input logic up, en, clear, load, clock,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock)
    if (clear) Q <= 0;
    else if (load) Q <= D;
    else if (en & up) Q <= Q + 1;
    else if (en & ~up) Q <= Q - 1;

endmodule: Counter

module ShiftRegister
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] D,
   input logic en, left, load, clock,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock)
    if (load) Q <= D;
    else if (en & left) Q <= Q << 1;
    else if (en & ~left) Q <= Q >> 1;
  
endmodule: ShiftRegister

module BarrelShiftRegister
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] D,
   input logic en, load, clock,
   input logic [1:0] by,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock)
    if (load) Q <= D;
    else if (en) Q <= Q << by;

endmodule: BarrelShiftRegister

module Memory
  #(parameter AW = 8, DW = 8)
  (input logic [AW-1:0] Address,
   input logic re, we, clock,
   inout wire [DW-1:0] Data);

  logic [DW-1:0] M[1 << AW];
  logic [DW-1:0] out;

  assign Data = (re) ? out: 'bz;

  always_ff @(posedge clock)
    if (we) M[Address] <= Data;

  assign out = M[Address];

endmodule: Memory

module RangeCheck
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] val, high, low,
   output logic is_between);

  always_comb
    if (val >= low && val <= high) is_between = 1'b1;
    else is_between = 1'b0;

endmodule: RangeCheck

module OffsetCheck
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] val, delta, low,
   output logic is_between);

  always_comb
    if (val >= low && (val - low) <= delta) is_between = 1'b1;
    else is_between = 1'b0;

endmodule: OffsetCheck