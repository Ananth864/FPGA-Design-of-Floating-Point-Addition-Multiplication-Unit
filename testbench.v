module testfloatingpoint;
reg [63:0]x,y;
reg clk,rst,mode;
reg [1:0] operation;
wire [31:0]result32;
wire [63:0]result64;
wire overflow;
floatingpoint dut(x,y,clk,operation,mode,result32,result64,rst,overflow);
parameter idle=0,add=1,mul=2,single=0,double=1;
initial begin 
clk=0;
forever #5 clk=~clk;
end
initial begin
rst=1;#12 rst=0;

#10 mode=single;
operation=add; x=32'h73728bdb; y=32'hfa8288c9;#10; x=32'h1123994a; y=32'hfa8288c9;#10;
operation=mul; x=32'h8081aa9b; y=32'h832bdfa2;#10; x=32'h2888a283; y=32'hcff73829;#10;

#10 mode=double;
operation=add; x=64'h00a8386612345678; y=64'h8187738312332101;#10; x=64'h7a8489283923ab22; y=64'h5aaf493939bd2392;#10;
operation=mul; x=64'habdb282883929283; y=64'h2382addff8392948;#10; x=64'hffcfff8289a9d92f; y=64'hcaefffadd9389294;#10;
$stop;
end
endmodule
