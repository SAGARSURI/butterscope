# 0001: Metric definitions frozen in M1

- Status: proposed
- Date: 2026-10-03
- Milestone: M1

## Context

`docs/DESIGN.md` left one item open for M1: the duration the hitch ratio is
divided by. M1's gate also freezes the percentile method. Writing the metrics
engine raised four more edges the design did not pin down: what happens at
exactly the budget, whether the frame classes nest on every screen, how the
observed refresh rate tolerates timestamp jitter, and what an empty window
reports.

These definitions decide every number a baseline holds. Changing one later
invalidates the baselines recorded under it, so they are settled before any
device data exists.

## Decision

1. **Rendering time is the hitch ratio's denominator.**

   `rendering time = frame count × B + Σ positive overrun`

   `hitch ratio = Σ positive overrun (ms) ÷ rendering time (s)`

   When frames run back to back, rendering time is close to wall-clock time,
   so Apple's 5 ms/s reading still applies. Time with no frames, such as a
   test waiting on a fake or between gestures, adds nothing. The ratio is
   always below 1000 ms/s.

   Considered and rejected:

   - The span's wall-clock duration. Idle time varies between runs of the
     same test and dilutes a regression: a 30 ms hitch reads 15 ms/s in a
     2 s span and 60 ms/s in the 0.5 s it actually played.
   - First `vsyncStart` to last `rasterFinish`. Still counts idle gaps
     between bursts of frames.
   - The sum of episode durations. Depends on the idle-gap threshold, which
     M8 tunes, so the metric would move when that tuning changes.

2. **Percentiles use nearest rank.** Sort the values ascending and take rank
   `⌈p × n ÷ 100⌉`, counting from 1, computed in integers. The result is
   always one of the values. The worst value is p100.

3. **Frame classes nest by construction and use these edges:**

   | Class | Rule |
   | --- | --- |
   | Smooth | `max(build, raster) ≤ B` |
   | Janky | `max(build, raster) > B` |
   | Severe | Janky, and `max(build, raster) > 2B` |
   | Stall | Severe, and `max(build, raster) ≥ 100 ms` |

   A frame of exactly `B` is smooth and one of exactly `2B` is janky, not
   severe. For any screen faster than 20 Hz, `2B` is under 100 ms, so the
   stall rule is the same as the design's.

4. **Observed refresh rate is the mode of the vsync gaps after smooth
   frames, with a tolerance.** Take the gap from each smooth frame's
   `vsyncStart` to the next frame's, in frame order. A janky frame pushes the
   next vsync back by whole intervals, so the gap after it says how late the
   frame was, not how fast the screen is; it is left out. Ignore gaps of zero
   or less and gaps of 100 ms or more (rendering paused). For each gap, count
   the gaps within ±5% of it. The gap with the most neighbours wins, ties
   going to the shorter gap. The interval is the nearest-rank median of that
   group, and the rate is `1 000 000 ÷ interval` hertz. With no usable gap,
   there is no observed rate. The tolerance absorbs timestamp jitter; 5%
   keeps 120 Hz and 144 Hz (8.33 ms and 6.94 ms, 20% apart) distinct.

5. **Units.** Times are kept in microseconds, as `FrameTiming` reports them.
   The budget is fractional (16 666.67 µs at 60 Hz). Results are reported in
   milliseconds, milliseconds per second, multiples of `B` and hertz.

6. **Empty windows.** Counts are 0. Rates, percentiles, the worst frame, the
   hitch ratio and the observed refresh rate have no value: they are
   undefined, not zero.

## Consequences

- A test that waits longer, or less, between gestures gets the same hitch
  ratio, as long as the frames are the same.
- A flow that renders fewer frames with the same hitches gets a higher hitch
  ratio. The frame count is reported beside it to explain that.
- A run where most frames are janky still reads the screen's real rate from
  its smooth frames, so the refresh-rate guard cannot turn a regression into
  `INVALID`. A run with no smooth frame has no observed rate; M6 decides how
  the guard treats that, and it must not hide a janky run.
- A screen that really runs slower than declared is still caught: its smooth
  frames are spaced at its real interval.
- Baselines recorded under these definitions stay comparable until a later
  record supersedes this one.
