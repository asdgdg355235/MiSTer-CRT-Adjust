`timescale 1ns/1ps
module tb_fixed #(parameter LINE_PX=32, WIDE_ONLY=0);
    reg clk=0;
    always #5 clk=~clk;
    reg reset=1, ce=0, ce2=0, hs=0, vs=0, hb=1, vb=1, field=0;
    reg signed [5:0] size=0;
    reg [15:0] width=16, height=240;
    reg [23:0] rgb=0;
    wire [23:0] out;
    wire co,c2o,ho,vo,hbo,vbo,fo,run,underrun;
    wire [15:0] oh;
    crt_vsize_fixed #(.LINE_PX(LINE_PX)) dut (
        .clk(clk),.reset(reset),.ce_in(ce),.ce2_in(ce2),.size(size),.width(width),.height(height),
        .rgb_in(rgb),.hs_in(hs),.vs_in(vs),.hb_in(hb),.vb_in(vb),.field_in(field),
        .rgb_out(out),.ce_out(co),.ce2_out(c2o),.hs_out(ho),.vs_out(vo),.hb_out(hbo),.vb_out(vbo),
        .field_out(fo),.running(run),.underrun(underrun),.picture_height(oh));
    reg [6:0] timing[0:4];
    reg [23:0] colors[0:4];
    reg [4:0] valid=0;
    reg checking=0, past_sync=0, inject=0, injected=0, fault_seen=0;
    integer py=0,px=0, delta=0, delay_l=0;
    integer k,yr,j,phase,src,alpha,aa,bb,rr,gg,blue,expected;
    integer checked_pixels=0;
    reg expect_line;
    always @(posedge clk) begin
        for(k=4;k>0;k=k-1) begin timing[k]=timing[k-1]; colors[k]=colors[k-1]; valid[k]=valid[k-1]; end
        delay_l=2+(delta<0 ? -delta : 0);
        yr=py-delay_l;
        if(ce && py==0 && px==-8) past_sync=0;
        if(vs) past_sync=1;
        expect_line=yr>=0 && yr<height+delta && !past_sync;
        timing[0]={ce,ce2,hs,vs,hb,!expect_line,field};
        expected=0;
        if(expect_line && !hb) begin
            // Independent inverse coordinate map and gamma-2 interpolation.
            phase=(height*65536/(height+delta))*yr;
            src=phase/65536;
            alpha=(phase%65536)/256;
            aa=src%256; bb=(src+1)%256;
            if(src>=height-1) alpha=0;
            rr=$rtoi($sqrt(((256-alpha)*aa*aa+alpha*bb*bb)/256));
            gg=px%256;
            blue=field ? 201 : 57;
            expected=(rr<<16)|(gg<<8)|blue;
        end
        if(inject && injected) expected=0;
        colors[0]=expected;
        valid[0]=expect_line && !hb;
        #1;
        if(reset) fault_seen=0;
        if(checking) begin
            if(!run) begin
                if({co,c2o,ho,vo,hbo,vbo,fo,out} !== {ce,ce2,hs,vs,hb,vb,field,rgb})
                    $fatal(1,"bypass changed video");
            end else begin
                if({co,c2o,ho,vo,hbo,fo} !== {timing[4][6:2],timing[4][0]})
                    $fatal(1,"timing/CE/field changed at delta=%0d y=%0d x=%0d",delta,py,px);
                if(co && !hbo && !vbo) begin
                    if(out !== colors[4]) $fatal(1,"pixel delta=%0d y=%0d x=%0d got=%h want=%h src=%0d pos=%h",delta,py,px,out,colors[4],dut.src_now,dut.pos_now);
                    checked_pixels=checked_pixels+1;
                end
                if(co && !hbo && valid[4] && vbo) $fatal(1,"missing resized row");
                if(underrun) begin
                    if(inject) fault_seen=1;
                    else $fatal(1,"ring underrun at delta=%0d row=%0d",delta,py);
                end
            end
        end
    end
    task scenario(input integer d, ratio, w, h, interlace, front);
        integer f,y,x,t,ht,vstart,vend,at;
        begin
            checking=0; injected=0;
            @(negedge clk); reset=1; ce=0; hb=1; vb=1; vs=0;
            repeat(8) @(negedge clk);
            reset=0; size=d; delta=d; width=w; height=h;
            ht=w+32;
            for(f=0;f<2;f=f+1) begin
                checking=(f==1);
                for(y=0;y<h+24;y=y+1) begin
                    for(x=0;x<ht;x=x+1) begin
                        vstart=(h+front)*ht+((interlace && f%2) ? ht/2 : 0);
                        vend=vstart+3*ht;
                        at=y*ht+x;
                        for(t=0;t<ratio;t=t+1) begin
                            @(negedge clk);
                            if(inject && f==1 && y==20 && x==8 && t==0) begin
                                force dut.complete=0; injected=1;
                            end
                            ce=t==0; ce2=(t==ratio/2); hs=(x>=w+16 && x<w+24);
                            hb=(x<8 || x>=w+8); vb=y>=h;
                            vs=(at>=vstart && at<vend); field=interlace && f%2;
                            py=y; px=x-8;
                            rgb={8'(y%256),8'((x-8)%256),8'(field ? 201 : 57)};
                        end
                    end
                end
            end
            checking=0;
            if(d!=0 && d>=-7 && d<=7 && w<=LINE_PX && h>=32 && checked_pixels==0) $fatal(1,"vacuous pixel test");
            if(inject) begin
                if(!fault_seen) $fatal(1,"underrun injection not observed");
                release dut.complete;
            end
            checked_pixels=0;
            $display("PASS: Cabinet delta=%0d CE=%0d width=%0d height=%0d interlace=%0d front=%0d",d,ratio,w,h,interlace,front);
        end
    endtask
    integer d,r;
    initial begin
        if(WIDE_ONLY) begin
            scenario(7,1,2560,240,0,12);
        end else begin
        for(d=-7;d<=7;d=d+1) scenario(d,8,16,240,0,12);
        for(r=1;r<=16;r=r*2) begin
            scenario(7,r,16,240,1,12);
            scenario(-7,r,16,240,1,12);
        end
        scenario(-7,2,32,288,1,12);
        scenario(0,1,16,240,1,2);
        scenario(7,4,16,240,1,2);
        scenario(7,2,33,240,0,12); // over-capacity source: byte-exact bypass
        scenario(31,2,16,240,0,12); // invalid request: byte-exact bypass
        inject=1; scenario(7,2,16,240,1,12);
        inject=0; scenario(-7,2,16,240,1,12); // reset recovery after missing rows
        end
        $display("PASS: fixed timing, half-line phase, pixel values, field isolation, ring wrap and reset");
        $finish;
    end
    initial begin #2000000000; $fatal(1,"timeout"); end
endmodule
