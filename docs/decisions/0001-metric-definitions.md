# 0001: Metric definitions frozen in M1

- Status: proposed
- Date: 2026-10-03
- Milestone: M1

## Context

`docs/DESIGN.md` left one item open for M1: the duration the hitch ratio is
divided by. M1's gate also freezes the percentile method. Writing the metrics
engine raised more edges the design did not pin down: what happens at exactly
the budget, whether the frame classes nest on every screen, how the observed
refresh rate tolerates timestamp jitter, and what an empty window reports.

Two reviews against the Flutter 3.47.5 sources then found how frames are
really produced during a test:

- **Frames run back to back for the whole test.** Under the `benchmarkLive`
  policy, the live test binding draws every frame and requests the next one
  as soon as each finishes, and `pump` only waits
  (`packages/flutter_test/lib/src/binding.dart`, `handleBeginFrame`,
  `handleDrawFrame`, `pump`). Every vsync should produce a frame, including
  while nothing changes on screen.
- **UI-thread work outside the frame shows up in two places.** The engine
  records a frame's vsync time when the signal arrives and posts the frame
  to the UI thread (`engine/src/flutter/shell/common/vsync_waiter.cc`);
  building starts only when the UI thread picks it up
  (`Animator::BeginFrame` in `shell/common/animator.cc`). Work that starts
  after the frame was requested, such as a stream listener decoding a
  message, lands in `vsyncOverhead`, not in `buildDuration`. Work already
  queued when the next frame is requested delays the request itself
  (`Animator::RequestFrame` posts it as a UI task), so the next frame starts
  on time and the cost shows only as vsyncs with no frame. So does work that
  runs after a frame is stamped as built and before the next request:
  semantics, tree finalisation and post-frame callbacks.
- **A slow raster thread also costs frames.** When the two-frame pipeline is
  full, `Animator::BeginFrame` skips the frame and tries again at the next
  vsync.
- **Raster time stops at the GPU.** The rasterizer records its finish after
  handing the frame over; GPU execution is not in it.

These definitions decide every number a baseline holds. Changing one later
invalidates the baselines recorded under it, so they are settled before any
device data exists, except where marked open.

## Decision

1. **UI time is the wait for the UI thread plus the build.**

   `UI time = vsyncOverhead + buildDuration`

   The UI thread cannot start the next frame until this one is built, so UI
   time over `B` means a vsync was missed, whatever made the frame wait. The
   pipelining that lets `totalSpan` exceed `B` without a dropped frame is
   between the UI and raster threads, and does not apply here. A negative
   wait counts as none.

2. **Missed vsyncs count the frames that never happened.** Because every
   vsync should produce a frame during a test, a gap of `k` intervals
   between consecutive frames' `vsyncStart` means `k − 1` vsyncs passed with
   no frame. A frame whose UI time spans `n` intervals already explains the
   first `n` of them, and that lateness is its overrun, so the count is
   `max(0, k − max(1, ⌈UI time ÷ B⌉))` per gap. Each gap is rounded to whole
   intervals of `B`; gaps of zero or less are ignored; long gaps count in
   full, because during a test they are freezes. This catches the UI work
   that per-frame times miss, and frames skipped while the raster pipeline
   was full; the latter may overlap with raster overrun. It is also
   reported as time, count × `B`, so the same freeze reads alike on every
   screen. The count assumes `B` is right: a span that fails the
   refresh-rate guard is `INVALID` (decision 6).

3. **Rendering time is the hitch ratio's denominator.**

   `rendering time = frame count × B + Σ positive overrun`

   `hitch ratio = Σ positive overrun (ms) ÷ rendering time (s)`

   It is defined from the frames alone, so it needs no second clock and
   does not depend on where a window's boundaries fall between frames.
   Because frames run back to back during a test, it is close to the
   window's wall-clock length. Idle time inside a window therefore adds
   smooth frames, which dilute the hitch ratio, the janky rate and the p90
   and p99 values. The hitch time, the counts, the worst values and the
   missed vsyncs are not diluted. Spans should wrap the flow tightly, and
   absolute budgets are set per flow from M8's data. **(open, M2: whether
   the hitch time also adds missed vsyncs. M2 measures both on the phones
   before the hitch ratio is frozen.)**

4. **Percentiles use nearest rank.** `p` is a whole number from 1 to 100.
   Sort the values ascending and take rank `⌈p × n ÷ 100⌉`, counting from 1,
   computed in integers. The result is always one of the values. The worst
   value is p100.

5. **Frame classes nest by construction and use these edges**, with
   `slowest = max(UI time, raster time)`:

   | Class | Rule |
   | --- | --- |
   | Smooth | `slowest ≤ B` |
   | Janky | `slowest > B` |
   | Severe | Janky, and `slowest > 2B` |
   | Stall | Severe, and `slowest ≥ 100 ms` |

   A frame of exactly `B` is smooth and one of exactly `2B` is janky, not
   severe. For any screen faster than 20 Hz, `2B` is under 100 ms, so the
   stall rule is the same as the design's. The thread tag compares UI time
   and raster time with `B` separately.

6. **Observed refresh rate is the mode of the vsync gaps after smooth
   frames, with a tolerance.** Take the gap from each smooth frame's
   `vsyncStart` to the next reported frame's, in the order the frames were
   reported (not by `frameNumber`). A janky frame pushes the next vsync back
   by whole intervals, so the gap after it is left out. Ignore gaps of zero
   or less and gaps of 100 ms or more, which are freezes rather than
   refresh intervals. For each gap `g`, its group is every
   gap from `0.95 g` to `1.05 g`, both edges included. The largest group
   wins, ties going to the shorter `g`. The interval is the nearest-rank
   median of that group, and the rate is `1 000 000 ÷ interval` hertz. With
   no usable gap, there is no observed rate. The tolerance absorbs timestamp
   jitter; 5% keeps 120 Hz and 144 Hz (8.33 ms and 6.94 ms, 20% apart)
   distinct.

   Frames run back to back during a test, so this is the screen's rate
   throughout. The refresh-rate guard checks every span in two ways. A span
   that fails either is `INVALID` and none of its metrics are used, since a
   wrong `B` distorts all of them (at a real rate of two thirds of the
   declared one or less, every gap reads as a missed vsync).

   - **The declared rate is read at the start and at the end of the span**,
     because Android updates it when the display mode changes. `B` comes
     from the first read, and the two reads must match within 5%.
   - **The observed rate must match in every part of the span**, not only
     overall: a screen that drops from 120 Hz to 60 Hz for the last third
     of a span still reads 120 Hz overall. The span's frames are cut into
     consecutive one-second slices by `vsyncStart`, the last one shorter;
     each gap belongs to the slice of the frame it follows. Every slice with
     at least 10 qualifying gaps must match the declared rate within 5%.
     **(open, M8: slice length and minimum.)**

   A change too brief to give a slice 10 qualifying gaps, or during which
   every frame is janky, can still pass if the declared rate is back where
   it started by the end of the span. Outside a test, frames are drawn on
   demand and the observed rate follows the requests instead.

7. **A refresh rate must be positive and finite.** A screen can report 0
   when its rate is not known. The recorder checks the declared rate first
   and makes the run `INVALID` with a named reason, rather than crashing.

8. **Raster time is the raster thread's time up to handing the frame to the
   GPU.** GPU-bound work may show up only indirectly, as raster time on a
   later frame or as missed vsyncs. **(open, M8: a GPU-bound plant shows
   whether it is caught on both phones.)**

9. **Units.** Times are kept in microseconds, as `FrameTiming` reports them.
   The budget is fractional (16 666.67 µs at 60 Hz). Results are reported in
   milliseconds, milliseconds per second, multiples of `B` and hertz.

10. **Empty windows.** Counts, including missed vsyncs, are 0. Rates,
    percentiles, the worst UI and raster times, the hitch ratio and the
    observed refresh rate have no value: they are undefined, not zero.

## Consequences

- UI-thread jank is caught whichever way it lands: as UI time when the work
  starts after the frame was requested, as missed vsyncs when it was
  already queued or ran after the frame was built. M4's `sync_decode` plant
  decodes in a stream listener, and M2 and M8 confirm both paths on both
  phones; iOS reports the vsync time from `CADisplayLink`, which is not yet
  verified for this.
- Test code runs on the same UI thread. Finders, expectations and gesture
  dispatch inside a span can cost frames and are counted as the app's.
  **(open, M5: measure the harness's cost and keep test steps outside
  spans where possible.)**
- Episodes cannot be split on gaps with no frames, because frames never
  pause during a test. **(open, M5: split on activity instead.)**
- A flow that renders fewer frames with the same hitches gets a higher hitch
  ratio. The frame count is reported beside it to explain that.
- A run where most frames are janky still reads the screen's real rate from
  its smooth frames, and a screen that really runs slower than declared is
  still caught, in every slice with smooth frames, because they are spaced
  at its real interval.
- From frame timings alone, a screen at half its declared rate looks the
  same as an app that misses every other vsync. A slice where the app does
  that throughout reads as a slower screen, so its span is `INVALID`, not
  `FAIL`. Base and head run interleaved on the same unit, so such a result
  that repeats on the head and not on the base points at the code.
  **(open, M9: how that is reported.)**
- Baselines recorded under these definitions stay comparable until a later
  record supersedes this one.
