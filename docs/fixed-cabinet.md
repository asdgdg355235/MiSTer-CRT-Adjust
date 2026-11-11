# Fixed-timing Cabinet scaler

`rtl/crt_vsize_fixed.sv` resamples rows within each progressive frame or
interlaced field. Positive `size` enlarges; negative `size` reduces the image.
The default range is -7 through +7 physical scanlines per field. In 480i,
one step therefore represents two rows across the complete frame.

## Timing and clipping

HS, VS, field metadata & both input CEs pass through the same four-clock
pipeline. No divider, line-period generator, VSync delay or parity generator
runs in this stage. Half-line edges therefore keep their input phase.
Zero size & unsupported dimensions select a combinational, byte-exact bypass.
Configuration changes latch on native VSync; assert `reset` for modeline or
clock changes.

The output begins two lines after source active video when enlarging. A
reduction of N lines begins N+2 lines late so both interpolation neighbours
have arrived. The last requested output line falls two lines plus any
enlargement into the source's lower blanking. Pixels reaching native VSync
are clipped; the scaler never moves sync to make room. Small front porches
therefore crop the bottom of an enlarged picture. Fixed timing cannot promise
that every enlarged source row remains visible in that blanking budget.

`vb_in` must be true vertical blank. `vb_out` describes the resized window,
including its VSync clipping. Pass it downstream with `ce_out`. The observed
window height is returned in `picture_height` after a completed field;
`picture_top` gives its starting line offset. On a new geometry, height uses
the requested value until that field is measured. These outputs let the
consumer place edge masks & compensate its OSD centering.

## Storage and scheduling

The minimum bound used here is `MAX_DELTA+4` lines. The implementation also
requires an even ring depth so adjacent source rows occupy separate banks.
For `MAX_DELTA=7`, the smallest even depth is twelve lines. The default store
is `12 * 2560 * 24 = 737280` bits, or 92160 bytes, plus 192 tag bits & validity
registers. Groovy's existing FIFO VRAM is destructive, sequential storage;
it cannot reread the two rows needed for interpolation. Altering its drain
schedule would also change the streaming timing, so this adapter leaves it
untouched.

Each RGB bank has one synchronous read port & one write port. Consecutive
source rows occupy opposite banks. Reads do not require duplicated RGB RAM.
A Q16 inverse-coordinate step is divided once during vertical blank, then
advanced per output row. Parallel gamma decoding, weighted blending & the
split square-root encoder accept one pixel per clock. The eight-clock CE
requirement of the original sequential pipeline does not apply to this
adapter. Tests cover uniform ratios 1, 2, 4, 8 & 16, plus Groovy-generated
6 & 12 ratios in the integration test.

Per-slot row tags & completion bits prevent reads from overwritten or
unfinished rows. Missing rows produce black RGB & set `underrun` until the
next field or reset. They do not stall the input, add a queue, or emit old
field pixels. Out-of-range widths bypass the scaler. The default supports
up to 2560 active pixels & 1024 source lines per field.

At maximum enlargement the reader trails the writer by at most nine lines;
maximum reduction requires nine lines of initial lead. There is no added
full-frame delay. The fixed pixel pipeline adds four `clk` periods to the
line storage delay. M10K packing, DSP mapping & timing closure require the
consuming core's Quartus fit; the logical bit count is not a fit report.

## Edge masking

`crt_edge_mask.sv` replaces selected edge RGB with black. Horizontal &
vertical amounts are independent, measured from the processed active window.
It does not change DE, CE, sync, field metadata, or pixel consumption.
Disabled masking & zero amounts pass every RGB sample unchanged. There is
no image RAM in the mask. Vertical coordinates restart for each field. Separate measured edge heights
for the two field IDs keep odd-height modes from borrowing the other field's
bottom edge. A geometry change settles those measurements over its next fields.
