#!/usr/bin/env python3
"""Self-checking Icarus tests. IVERILOG and VVP may contain command arguments."""
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def run(top, sources, temp):
    out = temp / top
    subprocess.run(shlex.split(os.environ.get('IVERILOG', 'iverilog')) +
                   ['-g2012', '-s', top, '-o', str(out)] + [str(p) for p in sources], check=True)
    subprocess.run(shlex.split(os.environ.get('VVP', 'vvp')) + [str(out)], check=True)

def main():
    with tempfile.TemporaryDirectory(prefix='crt-tests-') as tmp:
        tmp = Path(tmp)
        run('tb_adjust', [ROOT/'rtl/crt_adjust.sv', ROOT/'rtl/crt_adjust_sys.sv', ROOT/'tests/tb_adjust.sv'], tmp)
        # Compile the actual published decode expressions, not copies in a test.
        hp = (ROOT/'examples/core_side_snippet.v').read_text()
        vp = (ROOT/'examples/vsize_integration_snippet.v').read_text()
        h_expr = re.search(r'wire signed \[8:0\] hpos_off =.*?;', hp, re.S)[0]
        v_expr = re.search(r'wire \[3:0\] vsz_idx.*?wire signed \[5:0\] crt_vsz_step =.*?;', vp, re.S)[0]
        bench = tmp/'tb_decode.sv'
        bench.write_text('module tb_decode; reg [127:0] status=0; reg [6:0] hpos_d=0;\n'+h_expr+'\n'+v_expr+'''
integer i,expected;
initial begin
for(i=0;i<97;i=i+1) begin hpos_d=i; #1; expected=i<=48?i:i-97;
if(hpos_off!==expected) $fatal(1,"H-position index %0d",i); end
for(i=0;i<15;i=i+1) begin status[107:104]=i; #1; expected=i<=7?i:i-15;
if(crt_vsz_step!==expected) $fatal(1,"V-size index %0d",i); end
$display("PASS: all 97 H-position and 15 V-size OSD labels match decoded values"); $finish;
end endmodule
''')
        run('tb_decode', [bench], tmp)
        run('tb_mask', [ROOT/'rtl/crt_edge_mask.sv',ROOT/'tests/tb_mask.sv'], tmp)
        divider = (ROOT/'examples/core_side_snippet.v').read_text()
        divider = divider[divider.index('reg [7:0] pixel_gap'):divider.index('// ─── 4.')]
        bench = tmp/'tb_divider.sv'
        bench.write_text("module tb_divider; reg clk_sys=0; always #5 clk_sys=~clk_sys; reg ce_pix=0, crt_on=1; reg signed [4:0] hsize_s=0; wire hs_ref_rise=0;\n"+divider+"""
integer base,change,n,cnt,t,period;
initial begin
for(base=2;base<=16;base=base+2) begin
 for(change=-7;change<=7;change=change+7) begin
  hsize_s=change;
  for(n=0;n<4*base;n=n+1) begin @(negedge clk_sys); ce_pix=n%base==0; end
  if(pixel_period!=base) $fatal(1,"clock ratio measurement");
  cnt=0; period=base*4+change; if(period<4) period=4;
  for(n=0;n<period;n=n+1) begin
    @(negedge clk_sys); ce_pix=n%base==0;
    if(rd_ce) cnt=cnt+1;
  end
  if(cnt!=4) $fatal(1,"quarter clock divider base=%0d step=%0d count=%0d",base,change,cnt);
 end
end
$display("PASS: measured quarter-cycle divider at native ratios 2..16, shrink and enlarge"); $finish;
end endmodule
""")
        run('tb_divider', [bench], tmp)

        # The parallel scaler test matrix runs faster as compiled RTL.
        verilator = shlex.split(os.environ.get('VERILATOR', 'verilator'))
        for name, parameters in [('small', []), ('wide', ['-GLINE_PX=2560','-GWIDE_ONLY=1'])]:
            build = tmp/name
            result = subprocess.run(verilator + ['--binary','--timing','-Wno-fatal','--top-module','tb_fixed',
                                    '-j','2','--Mdir',str(build)] + parameters +
                                    [str(ROOT/'rtl/crt_vsize_fixed.sv'),str(ROOT/'tests/tb_fixed.sv')],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            if result.returncode:
                print(result.stdout)
                result.check_returncode()
            subprocess.run([str(build/'Vtb_fixed')], check=True)


if __name__ == '__main__':
    main()
