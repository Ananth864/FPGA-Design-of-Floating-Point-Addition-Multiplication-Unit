`timescale 1ns / 1ps

module floatingpoint(x,y,clk,operation,mode,result32,result64,rst,overflow,underflow);
input [63:0]x,y;
reg [127:0] temp;
integer temp3,i;
reg [63:0]count;
input clk,rst,mode;
output reg [31:0]result32;
output reg[63:0]result64;
output reg overflow,underflow;
input [1:0] operation; 
reg [1:0] nextoperation;
reg signx,signy;
reg [63:0]exponentx,exponenty,exptemp,mantissax,mantissay;
parameter idle=0,add=1,mul=2,single=0,double=1;

always @(posedge clk)
begin 
    if (rst)
    begin
        nextoperation<=idle;                             //default state
        result32<=0;
        result64<=0;
    end
    else
        nextoperation<=operation;                       //switching to new state
end
always @(nextoperation,x,y)
begin
    if (mode==single)                                    //32 bit operation
    begin
        signx=x[31];                                     //seperating input
        signy=y[31];
        mantissax=x[22:0];
        mantissay=y[22:0];
        exponentx=x[30:23];
        exponenty=y[30:23];
        
        case (operation)                               
        
        add:begin
                if (exponentx>exponenty)
                begin                                  //check the difference in exponent
                    temp3=exponentx-exponenty;
                    exptemp=exponentx;                 //save final exponent in temporary
                end
                else
                begin
                    temp3=exponenty-exponentx;
                    exptemp=exponenty;
                end
                if(signx==signy)                       //determine sign bit
                    result32[31]=signx;
                else
                begin
                    if (exponentx>exponenty)
                        result32[31]=signx;
                    else if (exponentx<exponenty)
                        result32[31]=signy;
                    else if (exponenty==exponentx)
                    begin
                        if(mantissax>mantissay)
                            result32[31]=signx;
                        else if (mantissax<mantissay)
                            result32[31]=signy;
                        else 
                            result32[31]=0;
                    end
                end
                if (temp3>23)                          //if size difference is too large, then assign one of the outputs
                begin
                    if(exponentx>exponenty)
                        result32=x;
                    else
                        result32=y;
                end
                else
                begin     
                    mantissax[23]=1;                    //append one for calculation
                    mantissay[23]=1;               
                    if (exponentx>exponenty)              //shift mantissa so exponent is same
                        mantissay=mantissay>>temp3;
                    else
                        mantissax=mantissax>>temp3;
                        
                    if (signx!=signy)
                    begin
                        overflow=0;
                        if (signx==1)                           //convert to 2nd compliment if sign bit is 1
                        begin
                            mantissax=mantissax^32'hffffffff;
                            mantissax=mantissax+1;
                        end
                        if (signy==1)
                        begin
                            mantissay=mantissay^32'hffffffff;
                            mantissay=mantissay+1;
                        end
                        temp=mantissax+mantissay;              //add mantissas
                        if (result32[31]==1)
                        begin
                            temp=temp^32'hffffffff;
                            temp=temp+1;
                        end
                        for(i=0;i<25;i=i+1)                      //normalize result
                        begin
                            if(!temp[23])
                            begin
                                temp=temp<<1;
                                exptemp=exptemp-1;
                            end
                        end
                        result32[22:0]=temp[22:0];              //assign to result
                        result32[30:23]=exptemp;
                    end
                    else if(signx==signy)
                    begin
                        temp=mantissax+mantissay;              //add mantissas
                        for(i=0;i<100;i=i+1)                 //normalize result
                        begin
                            if (temp[127:24]>0)
                            begin
                                temp=temp>>1;
                                exptemp=exptemp+1;
                            end
                        end 
                        temp=mantissax+mantissay;   
                        if (exptemp>254)                      //check for overflow
                        begin
                            result32=0;
                            overflow=1;
                        end
                        else
                        begin
                            overflow=0;
                            result32[22:0]=temp[22:0];        //assign result to output
                            result32[30:23]=exptemp;
                        end
                    end
                end        
            end
        
        mul:begin
                count=0;
                mantissax[23]=1;                       //appending 1 to msb to compute product
                mantissay[23]=1;
                if (signx==signy)                      //determine sign bit
                    result32[31]=0;
                else
                    result32[31]=1;
                if ((exponentx+exponenty)>381 || (exponentx+exponenty)<128)         //checking for overflow
                begin
                    if ((exponentx+exponenty)>381)
                    begin
                        overflow=1;
                        underflow=0;
                        result32=32'h7f7fffff;
                    end
                    else if ((exponentx+exponenty)<128)
                    begin
                        underflow=1;
                        overflow=0;
                        result32=32'h00800001;
                    end
                end    
                else
                begin
                    overflow=0;
                    underflow=0;
                    temp=mantissax*mantissay;
                    temp3=temp[127];
                    for(i=0;i<130;i=i+1)                    //shifting temp to extract result
                    begin
                        if(!temp3)  
                        begin
                            temp=temp<<1;
                            temp3=temp[127];
                        end
                    end
                    result32[22:0]=temp[126:104];
                    temp=mantissax*mantissay;           //figuring out how much mantissa affected exponent
                    for(i=0;i<100;i=i+1)
                    begin
                        if (temp>=2)
                        begin
                            temp=temp>>1;
                            count=count+1;
                        end
                    end
                    count=count-46;                     //adjusting for decimal point
                    if ((count+exponentx+exponenty)>381 || (count+exponentx+exponenty)<128) //check for overflow again
                    begin
                        if((count+exponentx+exponenty)>381)
                        begin
                            overflow=1;
                            underflow=0;
                            result32=32'h7f7fffff;
                        end
                        else if((count+exponentx+exponenty)<128)
                        begin
                            underflow=1;
                            overflow=0;
                            result32=32'h00800001;
                        end
                    end
                    else
                    begin
                        overflow=0;
                        underflow=1;
                        result32[30:23]=(exponentx+exponenty+count-127); //add exponents
                    end
                end
            end
        idle:result32=0;
        endcase
    end
    else if (mode==double)                            //64 bit operation
    begin
        signx=x[63];                                     //seperating input
        signy=y[63];
        mantissax=x[51:0];
        mantissay=y[51:0];
        exponentx=x[62:52];
        exponenty=y[62:52];
        case (operation)
        add:begin
                if (exponentx>exponenty)
                begin                                  //check the difference in exponent
                    temp3=exponentx-exponenty;
                    exptemp=exponentx;                 //save final exponent in temporary
                end
                else
                begin
                    temp3=exponenty-exponentx;
                    exptemp=exponenty;
                end
                if(signx==signy)                       //determine sign bit
                    result64[63]=signx;
                else
                begin
                    if (exponentx>exponenty)
                        result64[63]=signx;
                    else if (exponentx<exponenty)
                        result64[63]=signy;
                    else if (exponenty==exponentx)
                    begin
                        if(mantissax>mantissay)
                            result64[63]=signx;
                        else if (mantissax<mantissay)
                            result64[63]=signy;
                        else 
                            result64[63]=0;
                     end
                 end
                 if (temp3>52)                          //if size difference is too large, then assign one of the outputs
                 begin
                    if(exponentx>exponenty)
                        result64=x;
                    else
                        result64=y;
                 end
                 else
                 begin     
                    mantissax[52]=1;                    //append one for calculation
                    mantissay[52]=1;               
                    if (exponentx>exponenty)              //shift mantissa so exponent is same
                        mantissay=mantissay>>temp3;
                    else
                        mantissax=mantissax>>temp3;
                    if (signx!=signy)
                    begin
                        overflow=0;
                        if (signx==1)                           //convert to 2nd compliment if sign bit is 1
                        begin
                            mantissax=mantissax^64'hffffffffffffffff;
                            mantissax=mantissax+1;
                        end
                        if (signy==1)
                        begin
                            mantissay=mantissay^64'hffffffffffffffff;
                            mantissay=mantissay+1;
                        end
                        temp=mantissax+mantissay;              //add mantissas
                        if (result64[63]==1)
                        begin
                            temp=temp^64'hffffffffffffffff;
                            temp=temp+1;
                        end
                        for(i=0;i<60;i=i+1)                      //normalize result
                        begin
                            if(!temp[52])  
                            begin
                                temp=temp<<1;
                                exptemp=exptemp-1;
                            end
                        end
                        result64[51:0]=temp[51:0];              //assign to result
                        result64[62:52]=exptemp;
                    end 
                    else if(signx==signy)
                    begin
                        temp=mantissax+mantissay;              //add mantissas
                        for(i=0;i<100;i=i+1)                   //normalize result
                        begin
                            if(temp[127:53]>0) 
                            begin
                                temp=temp>>1;
                                exptemp=exptemp+1;
                            end
                        end 
                        temp=mantissax+mantissay;   
                        if (exptemp>2046)                      //check for overflow
                        begin
                            result64=0;
                            overflow=1;
                        end   
                        else
                        begin
                            overflow=0;
                            result64[51:0]=temp[51:0];        //assign result to output
                            result64[62:52]=exptemp;
                         end
                     end
                 end                     
            end
        mul:begin
                count=0;
                mantissax[52]=1;                       //appending 1 to msb to compute product
                mantissay[52]=1;
                if (signx==signy)                      //determine sign bit
                    result64[63]=0;
                else
                    result64[63]=1;
                if ((exponentx+exponenty)>3069 || (exponentx+exponenty)<1024)         //checking for overflow
                begin
                    if((exponentx+exponenty)>3069)
                    begin
                        overflow=1;
                        result32=64'h7fefffffffffffff;
                        underflow=0;
                    end
                    else if((exponentx+exponenty)<1024)
                    begin
                        underflow=1;
                        overflow=0;
                        result32=64'h0010000000000001;
                    end
                end
                else
                begin
                    overflow=0;
                    underflow=0;
                    temp=mantissax*mantissay;
                    temp3=temp[127];
                    for(i=0;i<150;i=i+1)                    //shifting temp to extract result
                    begin
                        if(!temp3)   
                        begin
                            temp=temp<<1;
                            temp3=temp[127];
                        end
                    end  
                    result64[51:0]=temp[126:75];
                    temp=mantissax*mantissay;
                    temp=temp>>104;           //figuring out how much mantissa affected exponent
                    for(i=0;i<200;i=i+1)
                    begin
                        if(temp>=2)
                        begin
                            temp=temp>>1;
                            count=count+1;
                        end
                    end
                    if ((count+exponentx+exponenty)>3069 || (count+exponentx+exponenty)<1024) //check for overflow again
                    begin
                        if((count+exponentx+exponenty)>3069)
                        begin
                            overflow=1;
                            underflow=0;
                            result32=64'h7fefffffffffffff;
                        end
                        else if((count+exponentx+exponenty)<1024)
                        begin
                            underflow=1;
                            overflow=0;
                            result32=64'h0010000000000001;
                        end
                    end  
                    else
                    begin
                        overflow=0;
                        underflow=0;
                        result64[62:52]=(exponentx+exponenty+count-1023); //add exponents
                    end
                end 
            end
        idle:result64=0;
        endcase
    end
end    
endmodule
