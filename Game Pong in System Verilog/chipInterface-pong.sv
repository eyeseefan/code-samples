// ChipInterface: The master/top module that connects the FPGA pins to my hardware design
// Author: Fan Bu

// This hardware thread is an implementation of the classical game "Pong" on FPGA. The entire
// code in this folder is not a software design, but a hardware design that get eventually
// translated into digital circuits.

module ChipInterface
  (input  logic CLOCK_50,
   input  logic [3:0] KEY,
   input  logic [17:0] SW,
   output logic [6:0] HEX0, HEX1, HEX2, HEX3,
                      HEX4, HEX5, HEX6, HEX7,
   output logic [7:0] VGA_R, VGA_G, VGA_B,
   output logic VGA_BLANK_N, VGA_CLK, VGA_SYNC_N,
   output logic VGA_VS, VGA_HS);

  logic [8:0] row;
  logic [9:0] col;
  
  logic blank;

  vga v1(.CLOCK_50(CLOCK_50), .reset(~KEY[0]), .HS(VGA_HS), .VS(VGA_VS),
         .blank(blank), .row(row), .col(col));

  assign VGA_SYNC_N = 1'b0;
  assign VGA_CLK = ~CLOCK_50;
  assign VGA_BLANK_N = ~blank;
  
  logic [3:0] left_score, right_score;

  pong dut(.reset(~KEY[0]), .vga_row(row), .vga_col(col),
           .left_up(SW[16]), .left_down(SW[17]),
           .right_up(SW[0]), .right_down(SW[1]),
           .serve(~KEY[3]), .*);

  BCDtoSevenSegment ss1(left_score, HEX7);
  BCDtoSevenSegment ss2(right_score, HEX0);
  
  assign HEX6 = 7'b111_1111;
  assign HEX5 = 7'b111_1111;
  assign HEX4 = 7'b111_1111;
  assign HEX3 = 7'b111_1111;
  assign HEX2 = 7'b111_1111;
  assign HEX1 = 7'b111_1111;

endmodule: ChipInterface

module BCDtoSevenSegment
  (input  logic [3:0] bcd,
   output logic [6:0] segment);

  always_comb begin
    unique case (bcd)
      4'd0:segment = 7'b100_0000;
      4'd1:segment = 7'b111_1001;
      4'd2:segment = 7'b010_0100;
      4'd3:segment = 7'b011_0000;
      4'd4:segment = 7'b001_1001;
      4'd5:segment = 7'b001_0010;
      4'd6:segment = 7'b000_0010;
      4'd7:segment = 7'b111_1000;
      4'd8:segment = 7'b000_0000;
      4'd9:segment = 7'b001_0000;
    endcase
   end

endmodule: BCDtoSevenSegment
