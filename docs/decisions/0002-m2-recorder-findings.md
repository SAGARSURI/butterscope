# 0002: Recorder and metric findings from M2

- Status: proposed
- Date: 2026-10-04
- Milestone: M2

## Context

M2 ran the frame recorder on the sample app's calibration screen on both
phones: 35 valid runs on the Galaxy S24 and 33 on the iPhone 17 Pro. Each
run recorded a window where a box animates and one where nothing changes
on screen. Planted work showed where each kind of jank lands, and on the
S24 the display was forced from 120 Hz to 60 Hz during a window. The
iPhone ran twice with its screen capped at 60 Hz. The data is in
[`docs/measurements/m2.md`](../measurements/m2.md).

M2 had to settle what `docs/DESIGN.md` and decision record
[0001](0001-metric-definitions.md) left open for it: the flush rules, how
window boundaries match frames, whether `benchmarkLive` produces a frame
on every vsync, the slice length and minimum for rate mismatches, what
`Display.refreshRate` reports when the rate changes, whether GPU work is
caught, how much missed vsyncs overlap raster overrun, whether hitch time
adds missed vsyncs, and which log carries results off an iPhone.

What the runs showed:

- **Every vsync produced a frame under `benchmarkLive`, including while
  nothing changed.** Every clean window on both phones held 600 frames
  within ±0.4%, with no skipped frame numbers. ProMotion stayed at 120 Hz
  in the still window.
- **Frame numbers match.** `PlatformDispatcher.frameData.frameNumber`
  bounds the window against `FrameTiming.frameNumber` with no frame lost
  or added at the edges. When the raster pipeline was full, the skipped
  frame numbers equalled the missed vsyncs as decision 0001 counts them
  (S24 `slow_raster`: 238.3 and 239; iPhone `gpu_heavy`: 454 and 454).
- **Flushes were fast.** No flush timed out. In profile the slowest clean
  flush took 88 ms and the slowest of any took 166 ms, in an iPhone
  `gpu_heavy` run. In release the slowest took 355 ms. The timeouts are
  500 ms and 2 s. Rate reads,
  which arrive with each batch, came about 10 times a second in profile
  and twice in release.
- **Observed rates were steady.** One-second slices of clean runs read
  119.8 to 120.2 Hz on both phones, a jitter of 0.2% against the 5%
  tolerance. The S24's forced change was flagged in the first full slice
  after it.
- **Neither phone reported its rate.** `Display.refreshRate` read
  120 Hz in all 91 reads of the two rate-change windows while the screen
  ran at 60 Hz. On the iPhone, with Limit Frame Rate switched on before
  launch, all 180 reads of two runs said 120 Hz while every one-second
  slice ran at exactly 60 Hz. Each window then looked like
  `postframe_decode`: half the frames, 299 missed vsyncs, 0% janky, and
  a 60 Hz observed rate. Nothing in the frame timings tells the two
  apart; the rig rules and the interleaved comparison of decision 0001
  do.
- **`Display.refreshRate` is the rate at launch.** It is a `final` field
  that changes only when the engine sends a new display list
  (`lib/ui/hooks.dart`, `_updateDisplays`, called from
  `Shell::OnDisplayUpdates` in `shell/common/shell.cc`). In Flutter
  3.47.5 that happens only at startup, and on Android also on a
  configuration change (`FlutterEngine.java`, `FlutterView.java`,
  `onConfigurationChanged`). Android's display listener
  (`shell/platform/android/io/flutter/view/VsyncWaiter.java`,
  `onDisplayChanged`) passes a new rate only to the engine's vsync
  waiter (`vsync_waiter_android.cc`, `OnUpdateRefreshRate`), never to
  Dart. On iOS the rate sent at startup is `VSyncClient.refreshRate`
  before its first vsync, which is the screen's maximum
  (`FlutterEngine.mm`, `updateDisplays`; `VSyncClient.swift`, `init`).
  This corrects decision 0001's statement that Android updates the
  declared rate when the display mode changes.
- **GPU work showed as raster time on both phones.** The `gpu_heavy`
  shader raised p99 raster time to 1.55 `B` on the S24 and 8.9 `B` on the
  iPhone, with skipped frames, so the raster thread waited on the GPU.
- **On iOS, UI work between frames shows as missed vsyncs, not UI time.**
  `listener_decode` was 9% janky on the S24 but 0% on the iPhone, where it
  missed 91 vsyncs per window. iOS adds the `CADisplayLink` that drives
  vsync to the UI thread's run loop
  (`shell/platform/darwin/ios/framework/Source/VSyncClient.swift`, the
  task posted in `init`), so while that thread is busy the callback
  waits, then starts the frame from the latest vsync, and the wait is
  never seen (inferred from the source and the data).
  On the S24 the wait landed in `vsyncOverhead`, as 0001 predicted.
- **`postframe_decode` showed only as missed vsyncs on both phones**:
  exactly half the frames, 60 Hz observed, 0% janky and a hitch ratio of
  0.
- **Missed vsyncs and raster overrun count the same time.** On the S24
  raster plants, the overrun and missed vsyncs × `B` each came to about
  1.9 s per window. Adding them doubles the hitch time. The vsync a slow
  raster frame costs is lost in the gap right after it or, because the
  pipeline holds two frames, in the gap after the next frame: on the
  iPhone `gpu_heavy`, 190 of 223 such frames lost it one frame later.
- **Overheads are small.** The recorder's callback cost about 240 to
  380 µs per second in profile and 75 to 200 in release, about 2 to 3 µs
  per frame. With the recorder on, p99 build and raster time from a
  timeline trace moved by at most 0.13 ms against runs with it off, and
  in both directions, within the noise between runs. In clean runs the
  median `vsyncOverhead` was about 0.8 ms on
  the S24 and 0.18 ms on the iPhone, with p99 at most 2.0 ms (0.24 `B`).
  Semantics added under one missed vsync per window on either phone.
- **Two S24 windows had raster time near `B` without missing a vsync.**
  One clean still window had a median raster time of 8.1 ms against about
  2 ms in the others, and 33% janky frames, yet it drew all 600 frames.
  Rate-change run 1 shows the same at 60 Hz. One reading, not confirmed:
  raster time there included waiting on the display. It never happened on
  the iPhone.
- **Logs.** Android logcat dropped about 400 of 1,300 lines per run
  without warning; 20 frames per line fixed it. On iOS, profile output
  reaches the `flutter drive` transcript; release output needs
  `idevicesyslog` from libimobiledevice.
- **Plants.** `slow_raster` and `backdrop_blur`, tuned on the S24, cause
  no jank on the iPhone; `gpu_heavy` drops it to about 16 Hz.

## Decision

1. **Window boundaries use frame numbers.** The recorder starts and ends
   a window at `PlatformDispatcher.frameData.frameNumber` and keeps the
   `FrameTiming`s numbered after the start, up to the end. Vsync
   timestamps are not used for boundaries.

2. **Flush rules are frozen as built.** After `stop`, the recorder waits
   until a timing numbered at or past the window's last frame arrives,
   for at most 500 ms in profile and debug and 2 s in release. The engine
   batches timings every 100 ms in profile and every 1 s in release
   (`Shell::OnFrameRasterized`, `shell/common/shell.cc`), so the timeouts
   leave about three times the slowest profile flush and twice the release
   batch period. A timeout is recorded in the window.

3. **`benchmarkLive` is confirmed** on both phones, including the still
   window. Decision 0001's open item on it is closed.

4. **Rate-mismatch slices stay at one second, with at least 10
   qualifying gaps and a 5% tolerance.** Clean slices vary by 0.2%. A
   slice at 120 Hz holds about 120 gaps and one at 60 Hz about 60, so the
   minimum is met unless nearly every frame is janky.

5. **The declared-rate guard stays, and the rate mismatch carries the
   detection.** On neither phone did `Display.refreshRate` follow the
   screen: not the S24 forced to 60 Hz mid-run, nor the iPhone capped at
   60 Hz from launch. In Flutter 3.47.5 Dart gets the rate only at
   startup, and on Android after a configuration change, so a rate change
   mid-run never reaches the guard on either platform. Only the per-slice
   observed rate showed the drop. The guard stays because it is cheap, it
   still catches a configuration change on Android, and a later Flutter
   may send rate changes to Dart. **(open, M3: the rate mismatch is not
   computed by any code yet.)**

6. **Missed vsyncs are explained by raster time too.** Decision 0001's
   count per gap of `k` intervals after frame `i` becomes
   `max(0, k − n)`, where

   `n = max(1, ⌈UI(i) ÷ B⌉, ⌈raster(i) ÷ B⌉, ⌈raster(i − 1) ÷ B⌉ − k(i − 1))`

   with `k(i − 1)`, at least 1, the intervals of the gap before. A slow
   raster frame's lateness is already its overrun, so the vsyncs it costs
   are not counted again, whether they fall in the gap right after it or,
   through the two-frame pipeline, the gap after the next frame. Only the
   intervals its own gap did not use carry over, so no raster time
   explains two gaps. Missed vsyncs now count only the vsyncs that no
   frame's own lateness explains.

7. **Hitch time adds missed vsyncs.**

   `hitch time = Σ positive overrun + missed vsyncs × B`

   `rendering time = frame count × B + hitch time`

   `hitch ratio = hitch time (ms) ÷ rendering time (s)`

   Without this, the hitch ratio reads 0 for work that runs between
   frames: `postframe_decode` halves the frame rate on both phones, and
   `listener_decode` drops 15% of the iPhone's frames, yet both read 0.
   With decision 6, nothing is counted twice: on the saved runs the
   S24 raster plants gain at most one vsync, the iPhone `gpu_heavy` gains
   32 that its slow frames do not explain (4,093 to 4,359 ms), and the
   S24's 60 Hz switch counts once
   (1,155 ms, against 1,747 ms for a plain sum). The same work now reads
   alike on both phones. The owner chose this over keeping decision
   0001's overrun-only hitch time.

8. **GPU-bound work is caught as raster time on these phones.** Decision
   0001's open item for M2 is closed. Other GPUs may behave differently;
   M8 still checks M4's `gpu_blur` in real flows.

9. **UI-thread work lands as UI time on Android and as missed vsyncs on
   iOS.** Both are gate metrics, so it is caught either way. A gate on the
   janky rate alone would miss it on iOS.

10. **Raster time can include waiting on the display.** Seen in 2 of 23
    S24 windows, it adds overrun with no missed vsync. It is kept as an
    open question for real flows. **(open, M8: how often, and whether
    raster time over `B` with no missed vsync should count.)**

11. **Results leave the iPhone** through the `flutter drive` transcript in
    profile and `idevicesyslog` in release. Android output packs several
    frames per logcat line. **(open, M7: the packing in schema v1.)**

12. **Plant costs move to M4**, whose gate is that each plant visibly
    janks. The S24 values stay. **(open, M4: the raster plants per
    platform.)**

## Consequences

- No baseline exists yet, so changing decisions 0001.2 and 0001.3 costs
  none. The metrics engine changes in its own pull request.
- The hitch ratio becomes the one number that sees all three ways jank
  lands. Missed vsyncs stay a gate metric of their own, with raster loss
  removed from them.
- A screen that drops its rate without reporting it raises the hitch
  ratio with the missed vsyncs, as it already raised them. Decision
  0001's comparison by symmetry still settles the cause.
- On both phones, the declared-rate guard alone would never void a span;
  the rate mismatch is what catches a slower screen. A rig that leaves
  Limit Frame Rate on reads like an app that drops every other frame, so
  the rig rules in DESIGN 7.4 matter more than the guard.
- `flutter drive` must run with `--keep-app-running` on iOS, or the
  phone asks to trust the developer before every run.
- The display-wait reading on the S24 could make raster overrun a false
  positive in some runs. Interleaved base and head runs on one unit keep
  it symmetric until M8 measures it.
