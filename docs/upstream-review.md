# Upstream PR review

The fork starts at `c682de9f4acc61d8f4c7779efb48149d3baa3a8e`, equal to
`rmonic79/MiSTer-CRT-Adjust/master` when inspected. The five open PRs were
read with their complete patches, issue comments & review submissions.
PR #3 contains the author's comment that its integration needs another
test from scratch. The review-submission lists are empty for these PRs.

| PR | Reference basis | Decision |
|---|---|---|
| [1](https://github.com/rmonic79/MiSTer-CRT-Adjust/pull/1) | `rtl/analog_hsize.sv`, push/pop, `nactive_run`, HSync pointer reset; simulation bench | Retain ping-pong storage. This patch targets the older stretch-only interface. Its occupancy bound assumes a slower reader; it does not establish bidirectional scaling, wide Groovy rasters, or FPGA timing. |
| [2](https://github.com/rmonic79/MiSTer-CRT-Adjust/pull/2) | `examples/sys_top_snippet.v`, measured `vga_base`; README divider | Apply the measured-period correction to the current quarter-cycle accumulator, rather than restore the older whole-cycle example. Clamp the read period to one clock; keep the `hs_ref_out` reset. |
| [3](https://github.com/rmonic79/MiSTer-CRT-Adjust/pull/3) | `docs/emu-side-integration.md`, core output boundary, VBlank warning, scandoubler caveat | Incorporate the wiring guidance into the current guide. Verify HDMI routing from the consuming framework. Do not import the older `analog_hsize` integration verbatim. |
| [4](https://github.com/rmonic79/MiSTer-CRT-Adjust/pull/4) | `crt_adjust.sv` & `crt_adjust_sys.sv`, `hoff_ext` before `hoff_s` | Apply the signed widening in both modules. Test every offset from -48 through +48 in both modes. |
| [5](https://github.com/rmonic79/MiSTer-CRT-Adjust/pull/5) | Both modules, `AW` parameter & bank indexing | Apply configurable depth. Also size signed sync taps from the raster totals. Test 2570-pixel totals, 625-line totals & `AW=13`. |

[Issue #6](https://github.com/rmonic79/MiSTer-CRT-Adjust/issues/6) is addressed
in both RTL variants & the published OSD examples. The 97-position list wraps
at 97. The 15-step vertical list wraps at 15; index 15 falls back to zero.
Tests compile the expressions extracted from the actual examples.

`crt_vsize_fixed.sv` is a new Cabinet adaptation of the upstream
`rtl/crt_vsize.sv` photometric path, including `isqrt_h` & `isqrt_l`. It retains
gamma-2 two-tap interpolation, but replaces progressive frame state, the
eight-subphase scheduler & delayed VSync with field-local storage & a parallel
pipeline. The original PVM retimer remains available separately; Groovy does
not instantiate it.

## Validation commands

```sh
python3 tests/run_tests.py
verilator --lint-only --top-module crt_vsize_fixed rtl/crt_vsize_fixed.sv
yosys -p 'read_verilog -sv rtl/crt_vsize_fixed.sv; hierarchy -top crt_vsize_fixed; proc; opt; memory_dff; memory_collect; stat'
```

The scaler matrix uses Verilator; signed offsets, OSD decodes, the divider &
mask tests use Icarus. `IVERILOG`, `VVP` & `VERILATOR` override executable
commands. Generic Yosys memory collection is a storage-inference check, not
a Cyclone V fit or TimeQuest result.
