`timescale 1ns / 1ps

module FP_MUL_UNIT(x,y,clk,result,underflow,overflow);
input [31:0]x,y;
output [31:0]result;
input clk;
output underflow,overflow;
wire over,under;
wire [31:0]res;
wire [47:0]product;
wire effect;
wire [22:0]op;
wire [7:0]opexp;
ArrayMultiplier ar1 (product, {1'b1,x[22:0]}, {1'b1,y[22:0]});
normalizer n1 (product[47:23],effect,op);
ExponentAdder e1 (x[30:23],y[30:23],effect,opexp,over,under);
Overflow_Underflow_unit ou1(op,opexp,(x[31]^y[31]),over,under,res);
Outputter dut (res,over,under,clk,result,overflow,underflow);
endmodule

module Cell(Cout, Sout,xn, am, Sin, Cin);
output Cout, Sout;
input xn, am, Sin, Cin;
  wire t;
  and (t, xn, am);
  xor (Sout, t, Sin, Cin);
  xor (t1, Sin, Cin);
  and (t2, t, t1);
  and (t3, Cin, Sin);
  or (Cout, t2, t3);
endmodule

module FACell(Cout, Sout, xn, am, Cin);
output Cout, Sout;
input xn, am, Cin;
wire t1, t2, t3;
xor (t1, am, xn);
and (t2, t1, Cin);
and (t3, am, xn);
or (Cout, t2, t3);
xor (Sout, t1, Cin);
endmodule

module ArrayMultiplier(product, a, x);
  
  parameter m = 24;
  parameter n = 24;
  output [m+n-1:0] product;
  input [m-1:0] a;
  input [n-1:0] x;
  
  wire c_partial[m*n:0] ;
  wire s_partial[m*n:0] ;
  
  // first line of the multiplier
  genvar i;
  generate
    for(i=0; i<m; i=i+1)
    begin
      Cell c_first(.Cout(c_partial[i]), .Sout(s_partial[i]),
                   .xn(x[0]), .am(a[i]), .Sin(1'b0), .Cin(1'b0));
    end
  endgenerate
  
  
  // middle lines of the multiplier - except last column
  genvar j, k;
  generate
    for(k=0; k<n-1; k=k+1)
    begin
      for(j=0; j<m-1; j=j+1)
      begin
        Cell c_middle(c_partial[m*(k+1)+j], s_partial[m*(k+1)+j],
                      x[k+1], a[j], s_partial[m*(k+1)+j-m+1], c_partial[m*(k+1)+j-m]);
      end
    end
  endgenerate
  
  // middle lines of the multiplier - only last column
  genvar z;
  generate
    for(z=0; z<n-1; z=z+1)
    begin
      Cell c_middle_last_col(c_partial[m*(z+1)+(m-1)], s_partial[m*(z+1)+(m-1)],
                             x[z+1], a[+(m-1)], 1'b0, c_partial[m*(z+1)+(m-1)-m]);
    end
  endgenerate
  
  // last line of the multiplier
  wire c_last_partial[m-1:0] ;
  wire s_last_partial[m-2:0] ;
  buf (c_last_partial[0], 1'b0);
  
  genvar l;
  generate
    for(l=0; l<m-1; l=l+1)
    begin
      FACell c_last(c_last_partial[l+1], s_last_partial[l],
                    c_partial[(n-1)*m+l], s_partial[(n-1)*m+l+1], c_last_partial[l]);
    end
  endgenerate
  
  
  // product bits from first and middle cells
  generate
    for(i=0; i<n; i=i+1)
    begin
      buf (product[i], s_partial[m*i]);
    end
  endgenerate
  
  // product bits from the last line of cells
  generate
    for(i=n; i<n+m-1; i=i+1)
    begin
      buf (product[i], s_last_partial[i-n]);
    end
  endgenerate
    
  // msb of product
  buf (product[m+n-1], c_last_partial[m-2]);

endmodule

module normalizer(in,effect,op);
input [24:0]in;
output reg effect;
reg [1:0]t2=2'b00;
output reg[22:0]op;
always @(in)
begin
    if((in[24]&in[23])|(in[24]&~in[23]))
    begin
        op<=in[23:1];
        effect<=1'b1;
    end
    else 
    begin
        op<=in[22:0];
        effect<=1'b0;
    end        
end
endmodule

module ExponentAdder(x,y,effect,op,overflow,underflow);
input [7:0]x,y;
input effect;
output reg [7:0]op;
output reg underflow,overflow;
wire [10:0]t1,t2,t3,t4;
wire cout;
assign t1=x;
assign t2=y;
adder ad1 (t1, t2, 1'b0, t3, cout); 
adder ad12 (t3,11'b11110000001,1'b0,t4,cout);
initial begin
overflow<=1'b0;
underflow<=1'b0;
end
always @(effect,t4)
begin
    overflow<=0;
    underflow<=0;
    op<=t4[7:0]+effect;
    if (t4[8]&&!t4[10])
    begin
        overflow<=1'b1;
        op<=8'b11111111;
    end
    else if (t4[10])
    begin
        underflow<=1'b1;
        op<=8'b00000000;
    end
end
endmodule

module Overflow_Underflow_unit(a,b,sign,overflow,underflow,result);
input [22:0]a;
input [7:0]b;
input overflow,underflow,sign;
output reg [31:0]result;

always @(a,b,sign,underflow,overflow)
begin
    if(overflow)
        result=32'hffffffff;
    else if (underflow)
        result=32'h00000000;
    else
    begin
        result[31]=sign;
        result[22:0]=a;
        result[30:23]=b;
    end
end
endmodule

module Outputter(x,over,under,clk,y,overflow,underflow);
input [31:0]x;
input clk,over,under;
output reg overflow,underflow;
output reg[31:0]y;
always @(posedge clk)
begin
    y<=x;
    overflow<=over;
    underflow<=under;
end
endmodule

