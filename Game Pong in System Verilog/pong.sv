// This file contains the code that is responsible for the actual contents of the game.
// Author: Fan Bu

// This hardware thread is an implementation of the classical game "Pong" on FPGA. The entire
// code in this folder is not a software design, but a hardware design that get eventually
// translated into digital circuits.


module paddle
  (input logic CLOCK_50, reset, update, serve, win,
   input logic up, down,
   output logic [8:0] row);

  logic [8:0] next_row;
  logic stop;

  Register #(9) r1(.D(next_row), .en(update),
                   .clear(1'b0), .clock(CLOCK_50), .Q(row));

  always_ff @(posedge CLOCK_50)
    if (reset || win)
    begin
      next_row <= 9'd240;
      stop <= 1'b1;
    end
    else if (stop)
    begin
      if (serve) stop <= 1'b0;
    end
    else if (update & up & ~down) 
         next_row <= ((row + 9'd5) >= 9'd456) ? row : (row + 9'd5);
    else if (update & down & ~up)
         next_row <= ((row - 9'd5) <= 9'd24) ? row : (row - 9'd5);

endmodule: paddle

module ball
  (input logic CLOCK_50, reset, update, serve,
   input logic [8:0] lp_row, rp_row,
   output logic [8:0] row,
   output logic [9:0] col,
   output logic l_win, r_win);

  logic [8:0] next_row;
  logic [9:0] next_col;
  logic touch_lp, touch_rp;
  logic row_up, col_up;
  logic stop;
  logic left_win, right_win;
  
  assign l_win = left_win;
  assign r_win = right_win;

  Register #(9) r1(.D(next_row), .en(update),
                   .clear(1'b0), .clock(CLOCK_50), .Q(row));
  Register #(10) r2(.D(next_col), .en(update),
                    .clear(1'b0), .clock(CLOCK_50), .Q(col));
  RangeCheck #(9) rc1(.val(row), .high(lp_row + 9'd24),
                      .low(lp_row - 9'd24), .is_between(touch_lp));
  RangeCheck #(9) rc2(.val(row), .high(rp_row + 9'd24),
                      .low(rp_row - 9'd24), .is_between(touch_rp));

  always_ff @(posedge CLOCK_50)
    if (reset)
    begin
      next_row <= 9'd240;
      next_col <= 10'd320;
      row_up <= 1'b1;
      col_up <= 1'b1;
      left_win <= 1'b0;
      right_win <= 1'b0;
      stop <= 1'b1;
    end
    else if (left_win)
    begin
      next_row <= 9'd240;
      next_col <= 10'd320;
      row_up <= 1'b1;
      col_up <= 1'b1;
      left_win <= 1'b0;
      right_win <= 1'b0;
      stop <= 1'b1;
    end
    else if (right_win)
    begin
      next_row <= 9'd240;
      next_col <= 10'd320;
      row_up <= 1'b1;
      col_up <= 1'b0;
      left_win <= 1'b0;
      right_win <= 1'b0;
      stop <= 1'b1;
    end
    else if (update && col <= 10'd2)
    begin
      left_win <= 1'b0;
      right_win <= 1'b1;
    end
    else if (update && col >= 10'd638)
    begin
      left_win <= 1'b1;
      right_win <= 1'b0;
    end
    else if (update && col == 10'd66 && touch_lp)
    begin
      next_row <= row_up ? (row + 9'd1) : (row - 9'd1);
      next_col <= col + 10'd2;
      col_up = 1'b1;
    end
    else if (update && col == 10'd574 && touch_rp)
    begin
      next_row <= row_up ? (row + 9'd1) : (row - 9'd1);
      next_col <= col - 10'd2;
      col_up = 1'b0;
    end
    else if (update && row <= 9'd2)
    begin
      next_row <= row + 9'd1;
      next_col <= col_up ? (col + 10'd2) : (col - 10'd2);
      row_up = 1'b1;
    end
    else if (update && row >= 9'd478)
    begin
      next_row <= row - 9'd1;
      next_col <= col_up ? (col + 10'd2) : (col - 10'd2);
      row_up = 1'b0;
    end
    else if (update && stop)
    begin
      if (serve) stop <= 1'b0;
    end
    else if (update)
    begin
      next_row <= row_up ? (row + 1) : (row - 1);
      next_col <= col_up ? (col + 2) : (col - 2);
    end

endmodule: ball

module pong
  (input logic CLOCK_50, reset,
   input logic [8:0] vga_row,
   input logic [9:0] vga_col,
   input logic left_up, left_down,
   input logic right_up, right_down,
   input logic serve,
   output logic [7:0] VGA_R, VGA_G, VGA_B,
   output logic [3:0] left_score, right_score);

  logic [8:0] lp_row, rp_row;
  logic [8:0] b_row;
  logic [9:0] b_col;
  logic update;
  logic l_win, r_win, win;
  logic [3:0] n_left_score, n_right_score;
  logic last_win;
  logic left_red, right_red;
  
  assign win = l_win | r_win;

  paddle lp(.up(left_up), .down(left_down), .row(lp_row), .*);
  paddle rp(.up(right_up), .down(right_down), .row(rp_row), .*);
  
  ball b(.row(b_row),.col(b_col), .*);
  
  Register #(4) r1(.D(n_left_score), .en(1'b1),
                   .clear(1'b0), .clock(CLOCK_50), .Q(left_score));
  Register #(4) r2(.D(n_right_score), .en(1'b1),
                   .clear(1'b0), .clock(CLOCK_50), .Q(right_score));
  
  always_ff@(posedge CLOCK_50)
    if (reset || serve)
    begin
      left_red <= 1'b0;
      right_red <=1'b0;
    end
    else if (l_win)
    begin
      left_red <= 1'b0;
      right_red <= 1'b1;
    end
    else if (r_win)
    begin
      left_red <= 1'b1;
      right_red <= 1'b0;
    end
  
  always_ff@(posedge CLOCK_50)
    if (reset)
    begin
      n_left_score <= 4'd0;
      n_right_score <= 4'd0;
      last_win <= 1'b1;
    end
    else if (l_win & ~last_win)
    begin
      if (left_score == 4'd9)
      begin
        n_left_score <= 4'd0;
        n_right_score <= 4'd0;
        last_win <= 1'b1;
      end
      else
      begin
        n_left_score <= left_score + 4'd1;
        last_win <= 1'b1;
      end
    end
    else if (r_win & ~last_win)
    begin
      if (right_score == 4'd9)
      begin
        n_left_score <= 4'd0;
        n_right_score <= 4'd0;
        last_win <= 1'b1;
      end
      else
      begin
        n_right_score <= right_score + 4'd1;
        last_win <= 1'b1;
      end
     end
     else if (serve)last_win <= 1'b0;
  
  assign update = (vga_row == 9'd479) && (vga_col == 10'd639);
  
  always_comb begin
    VGA_R = 8'h00;
    VGA_G = 8'h00;
    VGA_B = 8'h00;
    if (left_red && vga_col <= 10'd319) VGA_R = 8'hff;
    if (right_red && vga_col >= 10'd320) VGA_R = 8'hff;
    if (vga_row >= (lp_row - 9'd24) && vga_row <= (lp_row + 9'd24)
     && vga_col >= 10'd60 && vga_col <= 10'd63)
    begin
      VGA_R = 8'hff;
      VGA_G = 8'hff;
      VGA_B = 8'hff;
    end;
    if (vga_row >= (rp_row - 9'd24) && vga_row <= (rp_row + 9'd24)
     && vga_col >= 10'd576 && vga_col <= 10'd579)
    begin
      VGA_R = 8'hff;
      VGA_G = 8'hff;
      VGA_B = 8'hff;
    end;
    if (vga_row >= (b_row - 9'd2) && vga_row <= (b_row + 9'd2)
     && vga_col >= (b_col - 10'd2) && vga_col <= (b_col + 10'd2))
    begin
      VGA_R = 8'hff;
      VGA_G = 8'hff;
      VGA_B = 8'hff;
    end;
    
  end

endmodule: pong








