`timescale 1ns/1ps
module tb_mask;
    reg clk=0;
    always #5 clk=~clk;
    reg reset=1, ce=1, enable=0, hb=1, vb=1, field=0;
    reg [7:0] horizontal=0,vertical=0;
    reg [15:0] width=32,height=240;
    reg [23:0] rgb=24'habcdef;
    wire [23:0] out;
    crt_edge_mask dut(.*,.rgb_in(rgb),.rgb_out(out));
    integer mode,f,y,x,expected;
    initial begin
        repeat(5) @(negedge clk); reset=0;
        for(mode=0;mode<4;mode=mode+1) begin
            enable=mode!=0; horizontal=mode==1 ? 0 : 4; vertical=mode==1 ? 0 : 3;
            for(f=0;f<2;f=f+1) begin
                field=f%2;
                for(y=0;y<244;y=y+1) begin
                    for(x=0;x<48;x=x+1) begin
                        @(negedge clk);
                        vb=y>=240; hb=x>=32;
                        rgb=24'habcdef;
                        #1;
                        expected=enable && !hb && !vb && (x<horizontal || x+horizontal>=32 || y<vertical || y+vertical>=240) ? 0 : rgb;
                        if(out!==expected[23:0]) $fatal(1,"mask mode=%0d field=%0d y=%0d x=%0d got=%h want=%h",mode,f,y,x,out,expected);
                    end
                end
            end
        end
        $display("PASS: independent RGB masks, off/zero identity, 240-line fields, both field transitions");
        $finish;
    end
endmodule
