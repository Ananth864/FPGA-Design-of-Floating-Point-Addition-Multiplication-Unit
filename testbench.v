`timescale 1ns / 1ps
module testbench;
reg [31:0]x,y;
reg clk;
wire [31:0]result;
wire underflow,overflow;
FP_MUL_UNIT dut (x,y,clk,result,underflow,overflow);
initial begin
clk=0;
forever #50 clk=~clk;
end
initial 
begin
  #40  x=32'hcca7833a;y=32'hf9a128fd;#100;x=32'h827abb31;y=32'hf728a882;#100;x=32'h827abb31;y=32'h1128a882;
end
endmodule
