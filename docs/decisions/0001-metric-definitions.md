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

Reviewing the engine against the Flutter 3.47.5 sources found three wrong
assumptions in the first draft:

- **UI-thread work outside the frame was invisible.** The engine records a
  frame's vsync time when the signal arrives, then posts the frame to the UI
  thread (`shell/common/vsync_waiter.cc`); building starts only when the UI
  thread picks it up (`Animator::BeginFrame` in `shell/common/animator.cc`).
  Work that keeps the UI thread busy, such as a stream listener decoding a
  message, a timer or a platform message handler, lands in `vsyncOverhead`,
  not in `buildDuration`. Judging the UI thread on build time alone counted
  such frames as smooth.
- **The observed refresh rate assumed frames run back to back.** Flutter
  draws a frame only when one is requested, and the `benchmarkLive` policy
  keeps it that way. When frames follow data, such as price updates every
  33 ms, the gaps follow the data.
- **Apple's 5 ms/s threshold does not transfer to sparse frames**, because
  rendering time is short when frames are few.

These definitions decide every number a baseline holds. Changing one later
invalidates the baselines recorded under it, so they are settled before any
device data exists.

## Decision

1. **UI time is the wait for the UI thread plus the build.**

   `UI time = vsyncOverhead + buildDuration`

   The UI thread cannot start the next frame until this one is built, so UI
   time over `B` means a vsync was missed, whatever made the frame wait. The
   pipelining that lets `totalSpan` exceed `B` without a dropped frame is
   between the UI and raster threads, and does not apply here. A negative
   wait counts as none.

2. **Rendering time is the hitch ratio's denominator.**

   `rendering time = frame count × B + Σ positive overrun`

   `hitch ratio = Σ positive overrun (ms) ÷ rendering time (s)`

   Time with no frames, such as a test waiting on a fake or between gestures,
   adds nothing. The ratio is always below 1000 ms/s. It is for comparing a
   flow with its own baseline. When frames run back to back, rendering time
   is close to wall-clock time and Apple's 5 ms/s reading applies; when
   frames are sparse it reads higher (ten updates a second for 10 s at
   120 Hz is under 1 s of rendering, so one 50 ms hitch reads about
   57 ms/s). Absolute budgets are therefore set per flow from M8's data.

   Considered and rejected:

   - The span's wall-clock duration. Idle time varies between runs of the
     same test and dilutes a regression: a 30 ms hitch reads 15 ms/s in a
     2 s span and 60 ms/s in the 0.5 s it actually played.
   - First `vsyncStart` to last `rasterFinish`. Still counts idle gaps
     between bursts of frames.
   - The sum of episode durations. Depends on the idle-gap threshold, which
     M8 tunes, so the metric would move when that tuning changes.

3. **Percentiles use nearest rank.** `p` is a whole number from 1 to 100.
   Sort the values ascending and take rank `⌈p × n ÷ 100⌉`, counting from 1,
   computed in integers. The result is always one of the values. The worst
   value is p100.

4. **Frame classes nest by construction and use these edges**, with
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

5. **Observed refresh rate is the mode of the vsync gaps after smooth
   frames, with a tolerance, and the guard reads it only from the
   calibration animation.** Take the gap from each smooth frame's
   `vsyncStart` to the next reported frame's, in the order the frames were
   reported (not by `frameNumber`). A janky frame pushes the next vsync back
   by whole intervals, so the gap after it is left out. Ignore gaps of zero
   or less and gaps of 100 ms or more (rendering paused). For each gap `g`,
   its group is every gap from `0.95 g` to `1.05 g`, both edges included.
   The largest group wins, ties going to the shorter `g`. The interval is
   the nearest-rank median of that group, and the rate is
   `1 000 000 ÷ interval` hertz. With no usable gap, there is no observed
   rate. The tolerance absorbs timestamp jitter; 5% keeps 120 Hz and 144 Hz
   (8.33 ms and 6.94 ms, 20% apart) distinct.

   This equals the screen's rate only while frames run back to back. The
   refresh-rate guard therefore compares the declared rate with the rate
   observed on the calibration animation (M2), which runs continuously at
   the start of every run. The rate observed in a span or episode is a
   diagnostic.

6. **A refresh rate must be positive and finite.** A screen can report 0
   when its rate is not known. The recorder checks the declared rate first
   and makes the run `INVALID` with a named reason, rather than crashing.

7. **Raster time is the raster thread's time up to handing the frame to the
   GPU.** GPU execution is not in it, so GPU-bound work may show up only
   indirectly, on a later frame. **(open, M8: a GPU-bound plant shows
   whether it is caught on both phones.)**

8. **Units.** Times are kept in microseconds, as `FrameTiming` reports them.
   The budget is fractional (16 666.67 µs at 60 Hz). Results are reported in
   milliseconds, milliseconds per second, multiples of `B` and hertz.

9. **Empty windows.** Counts are 0. Rates, percentiles, the worst UI and
   raster times, the hitch ratio and the observed refresh rate have no
   value: they are undefined, not zero.

## Consequences

- Jank from work outside the frame, the common case when messages are
  decoded on the UI isolate, is caught and tagged `ui`. M4's `sync_decode`
  plant decodes in a stream listener to prove it, and M2 checks that the
  normal wait on both phones is well under `B`.
- A test that waits longer, or less, between gestures gets the same hitch
  ratio, as long as the frames are the same.
- A flow that renders fewer frames with the same hitches gets a higher hitch
  ratio. The frame count is reported beside it to explain that.
- Flows that draw on demand cannot make a run `INVALID` through the
  refresh-rate guard, because the guard reads the calibration animation.
- A run where most frames are janky still reads the screen's real rate from
  its smooth frames, and a screen that really runs slower than declared is
  still caught, because its smooth frames are spaced at its real interval.
- Baselines recorded under these definitions stay comparable until a later
  record supersedes this one.
