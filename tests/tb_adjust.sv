`timescale 1ns/1ps
module adjust_case #(parameter SYS=0, MODE=1)(input clk, input signed [8:0] offset, output hb);
    integer x=0;
    always @(posedge clk) x <= x==255 ? 0 : x+1;
    wire hs=x<16, blank=x<96 || x>=160;
    generate if(SYS) begin: s
        crt_adjust_sys #(.HTOTAL(256),.VTOTAL(64),.HPOS_MODE(MODE)) dut (
            .clk(clk),.pxl_cen(1'b1),.pxl2_cen(1'b1),.active(1'b1),
            .hsize(5'sd0),.hoffset(offset),.voffset(6'sd0),
            .r_in(8'd91),.g_in(8'd51),.b_in(8'd17),
            .hs_in(hs),.vs_in(1'b0),.hb_in(blank),.vb_in(1'b0),.hb_out(hb));
    end else begin: c
        crt_adjust #(.HTOTAL(256),.VTOTAL(64),.HPOS_MODE(MODE)) dut (
            .clk(clk),.pxl_cen(1'b1),.pxl2_cen(1'b1),.active(1'b1),
            .hsize(5'sd0),.hoffset(offset),.voffset(6'sd0),
            .r_in(8'd91),.g_in(8'd51),.b_in(8'd17),
            .hs_in(hs),.vs_in(1'b0),.hb_in(blank),.vb_in(1'b0),.hb_out(hb));
    end endgenerate
endmodule

module tb_adjust;
    reg clk=0;
    always #5 clk=~clk;
    reg signed [8:0] offset=0;
    wire [3:0] hb;
    adjust_case #(.SYS(0),.MODE(0)) a(clk,offset,hb[0]);
    adjust_case #(.SYS(0),.MODE(1)) b(clk,offset,hb[1]);
    adjust_case #(.SYS(1),.MODE(0)) c(clk,offset,hb[2]);
    adjust_case #(.SYS(1),.MODE(1)) d(clk,offset,hb[3]);
    crt_adjust #(.HTOTAL(2570),.VTOTAL(625),.AW(13)) wide (
        .clk(clk),.pxl_cen(1'b1),.pxl2_cen(1'b1),.active(1'b1),.hsize(5'sd0),
        .hoffset(offset),.voffset(-6'sd31),.r_in(8'd0),.g_in(8'd0),.b_in(8'd0),
        .hs_in(1'b0),.vs_in(1'b0),.hb_in(1'b1),.vb_in(1'b1));
    crt_adjust_sys #(.HTOTAL(2570),.VTOTAL(625),.AW(13)) wide_sys (
        .clk(clk),.pxl_cen(1'b1),.pxl2_cen(1'b1),.active(1'b1),.hsize(5'sd0),
        .hoffset(offset),.voffset(-6'sd31),.r_in(8'd0),.g_in(8'd0),.b_in(8'd0),
        .hs_in(1'b0),.vs_in(1'b0),.hb_in(1'b1),.vb_in(1'b1));
    integer counts[0:3];
    integer p,i,j;
    initial begin
        for(p=-48;p<=48;p=p+1) begin
            @(negedge clk) offset=p;
            repeat(4*256) @(negedge clk);
            if(b.c.dut.hoff_s !== p || d.s.dut.hoff_s !== p) $fatal(1,"signed offset %0d",p);
            if(a.c.dut.hoff_s !== 0 || c.s.dut.hoff_s !== 0) $fatal(1,"sync mode content offset");
            if(wide.hshift_tap !== (p<0 ? 2570+p : p)) $fatal(1,"wide horizontal tap");
            if(wide_sys.hshift_tap !== wide.hshift_tap || wide.vshift_tap !== 594 || wide_sys.vshift_tap !== 594)
                $fatal(1,"wide vertical tap");
            for(j=0;j<4;j=j+1) counts[j]=0;
            for(i=0;i<256;i=i+1) begin
                @(negedge clk);
                for(j=0;j<4;j=j+1) if(!hb[j]) counts[j]=counts[j]+1;
            end
            for(j=0;j<4;j=j+1) if(counts[j]!=64) $fatal(1,"offset=%0d variant=%0d pixels=%0d",p,j,counts[j]);
        end
        $display("PASS: 97 horizontal offsets, both variants and modes, 2570x625 taps");
        $finish;
    end
endmodule
