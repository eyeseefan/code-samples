// A VGA module for synchronizing with the monitor and outputing the
// location of the current pixel to be displayed.
// Author: Fan Bu

module vga
  (input logic CLOCK_50, reset,
   output logic HS, VS, blank,
   output logic [8:0] row,
   output logic [9:0] col);

  logic clr_h, clr_v, clr_r, clr_c, en_r, en_c;
  logic [10:0] hclk;
  logic [19:0] vclk;

  logic hpulse, hbp, hdisp, hfp;  
  logic vpulse, vbp, vdisp, vfp;
 
  Counter #(11) hcnt(.D(), .up(1'b1), .en(1'b1), .clear(clr_h), .load(1'b0),
                     .clock(CLOCK_50), .Q(hclk));
  Counter #(20) vcnt(.D(), .up(1'b1), .en(1'b1), .clear(clr_v), .load(1'b0),
                     .clock(CLOCK_50), .Q(vclk));

  Counter #(9) rcnt(.D(), .up(1'b1), .en(en_r), .clear(clr_r), .load(1'b0),
                    .clock(CLOCK_50), .Q(row));
  Counter #(10) ccnt(.D(), .up(1'b1), .en(en_c), .clear(clr_c), .load(1'b0),
                     .clock(CLOCK_50), .Q(col));

  OffsetCheck #(11) osc1(.val(hclk),
                         .delta(11'd191), .low(11'd0), .is_between(hpulse));
  OffsetCheck #(11) osc2(.val(hclk),
                         .delta(11'd95), .low(11'd192), .is_between(hbp));
  OffsetCheck #(11) osc3(.val(hclk),
                         .delta(11'd1279), .low(11'd288), .is_between(hdisp));
  OffsetCheck #(11) osc4(.val(hclk),
                         .delta(11'd31), .low(11'd1568), .is_between(hfp));
 
  OffsetCheck #(20) osc5(.val(vclk),
                         .delta(20'd3199), .low(20'd0),
                         .is_between(vpulse));
  OffsetCheck #(20) osc6(.val(vclk),
                         .delta(20'd46399), .low(20'd3200),
                         .is_between(vbp));
  OffsetCheck #(20) osc7(.val(vclk),
                         .delta(20'd767999), .low(20'd49600),
                         .is_between(vdisp));
  OffsetCheck #(20) osc8(.val(vclk),
                         .delta(20'd15999), .low(20'd817600),
                         .is_between(vfp));

  assign HS = ~hpulse;
  assign VS = ~vpulse;
  assign blank = ~(hdisp&vdisp);

  assign clr_h = (hclk == 11'd1599) || reset;
  assign clr_v = (vclk == 20'd833599) || reset;
  assign en_c = hclk[0];
  assign clr_c = blank || reset;
  assign en_r = hclk == 11'd1599;
  assign clr_r = ~vdisp || reset;

endmodule: vga

module vga_test();
  logic CLOCK_50, reset;
  logic HS, VS, blank;
  logic [8:0] row;
  logic [9:0] col;
  
  vga dut(.*);

  initial begin
    CLOCK_50 = 0;
    forever #5 CLOCK_50 = ~CLOCK_50;
  end

  initial begin
    #10 reset = 1;
    #10 reset = 0;
    #833600 $finish;
  end

endmodule: vga_test
