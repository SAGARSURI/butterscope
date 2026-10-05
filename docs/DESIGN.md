# Butterscope design

- Status: **draft for approval** (milestone M0)
- Scope: Android and iOS. Desktop and web are out of scope.
- Changes: once approved, this document changes only through a decision record
  in [`docs/decisions/`](decisions/README.md).

Items marked **(open, Mx)** are deliberately undecided; the named milestone
measures them and records the answer here.

## 1. What Butterscope is

Butterscope attaches to a team's existing Flutter integration tests, records
every frame the app renders while they run, reports performance issues per
flow, and catches regressions against a baseline. A device run is too slow
for every push, so it runs when a pull request asks for it, after merges to
`main` and before a release (section 9.1).

Three roles stay separate, as in Android Macrobenchmark, XCTest metrics,
Lighthouse user flows and Reassure:

| Role | Who does it |
| --- | --- |
| **Driver**: moves through the flow | The team's own integration test. Butterscope scripts no interactions. |
| **Observer**: records frames | Butterscope, inside the app process, with no host connection. |
| **Judge**: decides PASS / FAIL / INVALID | `butterscope judge` on the host, from collected reports. |

**The principle.** Frame times on a real device are never deterministic:
thermal state, GC, background work and adaptive refresh rates shift them. The
**verdict** is deterministic: with fixed inputs, fixed definitions and a fixed
decision rule, the same build on the same rig gets the same verdict.

**Not in the PoC:** iOS on the device farm (the PoC runs iOS on one local
iPhone), regression detection on `main` and the release gate (section 9.1),
desktop, web, startup time, field telemetry, automated Timeline capture, and
any app-specific code (for example a fake socket client).

## 2. Terms

| Term | Meaning |
| --- | --- |
| **B** | Frame budget in ms: `1000 / refreshRate`. 16.67 at 60 Hz, 8.33 at 120 Hz. |
| **UI time** | `FrameTiming.vsyncOverhead + buildDuration`: the wait for the UI thread after the vsync, plus building the frame. Work outside the frame, such as a stream listener or a timer, shows up in the wait. |
| **Raster time** | `FrameTiming.rasterDuration`: raster thread work for one frame, up to handing it to the GPU. |
| **Overrun** | `max(UI, raster) − B`. Positive means the frame was late. |
| **Hitch time** | Total positive overrun plus missed vsyncs × `B`: how late the frames were, plus the frames that never came. |
| **Hitch ratio** | Hitch time (ms) per second of rendering in a span or episode. |
| **Rendering time** | Frame count × `B` plus the hitch time. During a test frames run back to back, so it is close to wall-clock time. |
| **Missed vsyncs** | Vsyncs that passed with no frame between consecutive frames, beyond those a late frame explains. |
| **Episode** | A part of a run split out automatically, without the test marking it. **(open, M5: how to split.)** |
| **Span** | A named window a test marks around a flow. Gates apply to spans. |
| **Run** | One execution of one test file on one device. |
| **Identity** | The fields stamped on every run that decide what it can be compared with. |

## 3. Measurement source

1. **Gate metrics come from `FrameTiming` only**, received through
   `SchedulerBinding.addTimingsCallback`. This works in profile and release
   builds with no VM service, so the same numbers can later come from
   production.
2. **Butterscope has its own recorder.** It does not use
   `IntegrationTestWidgetsFlutterBinding.watchPerformance`, because that
   method also traces the VM timeline and reports through `reportData`, which
   only reaches a host under `flutter drive`.
3. **Flutter's built-in "missed budget" counters are never used.**
   `kBuildBudget` is a 16 ms constant in `flutter_driver` and defaults to
   16 ms in `flutter_test`; neither follows the real refresh rate, so on a
   120 Hz screen a 12 ms frame drops a frame but is not counted. Butterscope
   recomputes everything from raw durations.
4. **The engine batches `FrameTiming` reports**, every 100 ms in debug and
   profile builds and every second in release, or at 100 frames. The
   recorder discards stale timings before a window. After it, the recorder
   waits until a timing numbered at or past the window's last frame
   arrives, for at most 500 ms in profile and debug and 2 s in release,
   and records a timeout in the window. On both phones no flush timed out;
   the slowest took 355 ms, in release
   ([0002](decisions/0002-m2-recorder-findings.md)).
5. **Window boundaries are frame numbers.** A window starts and ends at
   `PlatformDispatcher.frameData.frameNumber` and keeps the timings whose
   `FrameTiming.frameNumber` falls after its start, up to its end. On both
   phones this lost no frame at the edges, and a frame skipped while the
   raster pipeline was full leaves a gap in the numbers
   ([0002](decisions/0002-m2-recorder-findings.md)).
6. **Timelines are for people, not gates.** A failing flow is diagnosed by
   re-running it locally with DevTools or `traceAction`.

## 4. Classifying frames

**Budget.** `B = 1000 / refreshRate`, where `refreshRate` is the test view's
`FlutterView.display.refreshRate`. Flutter's Android embedding updates it
when Android reports a display change, so the recorder reads it at the
start and end of each span and each time a batch of timings arrives, about
10 times a second in profile and twice in release. Each read is placed in
the frame sequence after the last frame reported before it. A span's `B`
comes from the read at its start, and an episode's from the last read before
its first frame. Each span and episode records its declared and observed
rate, so one run can hold different rates (section 7.3).

Each frame gets one class. The classes are nested: every stall is severe and
every severe frame is janky.

| Class | Rule | Why |
| --- | --- | --- |
| Smooth | `UI ≤ B` and `raster ≤ B` | |
| Janky | `UI > B` or `raster > B` | At least one vsync was missed. |
| Severe | `max(UI, raster) > 2B` | Several vsyncs missed: a visible hitch. |
| Stall | Severe, and `max(UI, raster) ≥ 100 ms` | A perceived freeze. Wall-clock, not budget-relative, because 150 ms feels the same at 60 Hz and 144 Hz. **(open, M8: tune 100 ms.)** |

**Thread tag.** Each janky frame is tagged `ui`, `raster` or `both`. This is
the first fork of Flutter's own triage advice: UI time is Dart work, in the
frame or keeping it waiting; raster-only time is rendering cost (`saveLayer`,
clips, shadows, opacity).

**Why UI time includes the wait.** The engine records the vsync when the
signal arrives and starts building only when the UI thread is free, so work
that keeps the UI thread busy delays the frame without appearing in
`buildDuration`. The UI thread cannot start the next frame until this one is
built, so UI time over `B` is a missed vsync whatever the cause. Work already
queued when the next frame is requested delays the request itself, so that
frame starts on time; so does work that runs after a frame is stamped as
built (semantics, tree finalisation, post-frame callbacks). Both show only as
missed vsyncs (section 5). On iOS the vsync callback itself runs on the UI
thread, so a busy UI thread delays it, and work between frames shows as
missed vsyncs rather than UI time
([0002](decisions/0002-m2-recorder-findings.md)).

**Not used for jank:** `totalSpan` (vsync to raster finish). The UI and
raster threads are pipelined, so `totalSpan` can exceed `B` with no dropped
frame. It is kept as a latency diagnostic.

**Raster time stops at the GPU.** GPU execution is not in `rasterDuration`,
so GPU-bound work may show up only indirectly. On both phones the raster
thread waited on the GPU, so a GPU-heavy plant showed as raster time and
skipped frames ([0002](decisions/0002-m2-recorder-findings.md)). M8 checks
M4's `gpu_blur` in real flows. Raster time can also include waiting on the
display: two S24 windows had raster time near `B` with every frame drawn.
**(open, M8: how often, and whether such frames should count.)**

**Overrun is an estimate.** `FrameTiming` has no timestamp for when a frame
reached the screen, so overrun approximates how late it was.

**Observed refresh rate** = the most common gap from a smooth frame's
`vsyncStart` to the next frame's, grouping each gap with those within ±5% of
it and ignoring gaps of 100 ms or more, which are freezes, not refresh
intervals. A janky frame pushes the next vsync back by whole intervals, so
the gap after it is left out and the mode is used, not the mean. Under
`benchmarkLive` frames run back to back for the whole test, so this is the
screen's rate throughout, unless the app misses vsyncs. It is also taken in
one-second slices, because one mode over a whole span hides a drop in part
of it. A slice with at least 10 qualifying gaps whose rate differs from the
declared one by more than 5% is a **rate mismatch**. Clean slices on both
phones varied by 0.2% ([0002](decisions/0002-m2-recorder-findings.md)).
(Outside a test Flutter draws on demand, and the gaps follow the requests
instead.)

**A rate mismatch is a flag, never `INVALID` on its own.** From frame
timings alone, a screen at half its declared rate looks the same as an app
that misses every other vsync. Voiding the span would let a severe,
repeatable regression pass, so it is judged with its declared `B`, and its
missing frames count as **missed vsyncs**, a gate metric, which can `FAIL`.
They are the only signal when every frame that renders stays within `B`:
those frames are smooth, so the janky rate reads zero, and the hitch ratio
sees them only through the missed vsyncs it adds.
The comparison decides the cause (section 9). Only a change in the declared
rate itself makes a span `INVALID` (section 7.2). See
[0001](decisions/0001-metric-definitions.md).

## 5. Metrics

All gate metrics are normalised to `B`, so one threshold is correct on 60, 90,
120 and 144 Hz screens.

### Gate metrics (per span)

| Metric | Definition |
| --- | --- |
| **Hitch ratio** (headline) | Hitch time (ms) ÷ rendering time (s), where hitch time is Σ positive overrun + missed vsyncs × `B`. Compared with the flow's baseline. Idle time in a span adds smooth frames and dilutes it, so absolute budgets are set per flow from M8's data. The missed vsyncs let it see frames that never rendered, such as work between frames ([0002](decisions/0002-m2-recorder-findings.md)). |
| Missed vsyncs | Vsyncs with no frame between the span's frames, beyond what a late frame explains: the frame's own UI or raster time, or the raster time of the frame before it, since the raster pipeline holds two frames. That part is already overrun. Reported as time, count × `B`, so the same freeze reads alike on every screen. Catches UI work that per-frame times miss, and is the only metric besides the hitch ratio that sees dropped frames between smooth ones. |
| Janky rate | Janky frames ÷ frames, reported overall and per thread. |
| Severe count | Number of severe frames. |
| Stall count | Number of stalls. |
| p90, p99 UI | As multiples of `B`. |
| p90, p99 raster | As multiples of `B`. |
| Worst UI, worst raster | As multiples of `B`. |
| Frame count | Secondary: explains changes in the others (fewer trivial frames can make averages worse). |

**Percentiles** use the nearest-rank method, rank `⌈p × n ÷ 100⌉` of the
sorted values, so results never depend on a library's interpolation; the
worst value is p100. The hitch ratio divides by **rendering time**, defined
from the frames alone. Idle time inside a span adds smooth frames, which
dilute the hitch ratio, the janky rate and p90/p99, but not the hitch time,
the counts, the worst values or the missed vsyncs; spans should wrap the flow
tightly. An empty window has counts of 0 and no value for rates, percentiles
or the hitch ratio ([0001](decisions/0001-metric-definitions.md)).

### Diagnostic metrics (recorded, never gated)

- Averages of UI, build and raster time.
- p90 and p99 of `vsyncOverhead` (the wait for the UI thread, to tell it
  apart from build time) and `totalSpan` (latency, for example tick-to-pixel
  on a live price screen).
- Raster cache counts and bytes from `FrameTiming` (`layerCacheCount`,
  `layerCacheBytes`, `pictureCacheCount`, `pictureCacheBytes`).
- Garbage-collection counts are **not** collected: they need the VM timeline.

## 6. The passive observer

1. **One line attaches.** A call at the top of a test file's `main`, before
   any `testWidgets`, sets the frame policy, records the whole run, and emits
   the report when the tests finish. **(open, M5: API names.)**
2. **Frame policy: `benchmarkLive`.** The live test binding defaults to
   `fadePointers`, which renders frames at the test's own pump rhythm, not at
   vsync. Under `LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive` the
   binding draws every frame at vsync and requests the next one as soon as
   each finishes, so frames run back to back for the whole test and every
   missed vsync is visible. This is read from the source; the policy's own
   documentation describes scheduling that follows real frame requests. M2
   confirmed it on both phones, including a window where nothing changes
   on screen ([0002](decisions/0002-m2-recorder-findings.md)). Flutter's
   docs warn that changing the policy can
   change test behaviour, so M5 records which ordinary tests run unchanged.
   A run whose frames are not vsync-driven is `INVALID` (section 7).
3. **Episodes** split the run automatically. An optional navigator observer
   tags each episode with its route. Episodes are advisory: the same flow can
   split differently from run to run. Frames never pause under
   `benchmarkLive`, so episodes cannot split on gaps with no frames.
   **(open, M5: split on activity instead.)**
4. **Named spans** mark the flows that are gated:
   `span('open detail', () async { … })`. Names are stable across runs, so
   only spans are compared with a baseline. Spans are flat in v1 (no
   nesting).
5. **Frames are attributed to the test that produced them.** **(open, M5:
   mechanism.)**
6. **Test runners:** plain `integration_test` is the primary target. Patrol
   should work unchanged because `PatrolBinding` extends
   `IntegrationTestWidgetsFlutterBinding`. **(open, M5: verified.)**
7. **Data determinism is the app's job.** Flows run against the app's own
   fakes (for example, a socket client replaying recorded frames at the
   transport layer, so decoding and state merging still run for real).
   Butterscope only detects nondeterminism, for example frame counts that
   vary a lot between repetitions, and marks the flow unstable.
8. **Test code shares the UI thread.** Finders, expectations and gesture
   dispatch run between frames, so inside a span they can cost frames that
   are counted as the app's. **(open, M5: measure the harness's cost and
   keep test steps outside spans where possible.)**
9. **Recording is cheap; metrics come later.** While recording, the
   recorder only stores timings and the refresh rates it reads. Metrics are
   computed after recording stops, so they never cost a measured frame.

### What the report contains

- **Identity** (section 7.3) and **validity** with reasons.
- **Per span:** its declared and observed refresh rate, and every gate and
  diagnostic metric.
- **Per episode:** its declared and observed refresh rate and the same
  metrics, plus the route tag when available. An episode whose declared
  rate changed reports that instead of metrics: it is not gated, but a
  wrong `B` would mislead its readers just the same. Rate mismatches are
  flagged beside the metrics of the span or episode they fall in.
- **Issues:** one entry per janky frame in a span or episode that passed the
  refresh-rate guard: time offset, span or episode, thread, overrun as a
  multiple of `B`, class.

## 7. Validity and environment

### 7.1 Verdicts

Every run, and every span in it, ends as **PASS**, **FAIL** or **INVALID**.
`INVALID` means a measurement precondition failed. It is retried and reported
as an infrastructure problem, and it never counts against the code.

### 7.2 Guards

Every variable is either pinned on the rig or detected by Butterscope. A
detected mismatch makes the run `INVALID` with a named reason.

| Guard | Detection | Rule |
| --- | --- | --- |
| Build mode | `kDebugMode`, `kProfileMode`, `kReleaseMode` | Debug is `INVALID`. Profile and release are both valid and recorded. |
| Frame policy | The binding's `framePolicy` | Must be `benchmarkLive`. |
| Refresh rate | Declared (`Display.refreshRate`, read as in section 4), for every span and episode | Every declared read after the one that set `B` must match it within 5%. A span that fails is `INVALID` and none of its metrics are used, since a wrong `B` distorts all of them; an episode that fails reports the reason instead of metrics. A declared rate that is 0 or not finite is `INVALID`. The observed rate is not a guard: a rate mismatch is flagged and settled by comparison (sections 4 and 9). |
| Animations | `WidgetsBinding.instance.disableAnimations`; on iOS also `PlatformDispatcher.accessibilityFeatures.reduceMotion`, because Reduce Motion does not set `disableAnimations` | Both must be false. |
| Text scale | `PlatformDispatcher.textScaleFactor` | Must equal the declared value (1.0 unless the run declares otherwise). |
| Locale | `PlatformDispatcher.locale` | Must equal the declared value. |
| Semantics | `PlatformDispatcher.semanticsEnabled` | **(open, M6.)** `testWidgets` turns semantics on by default (`semanticsEnabled: true`), so either observed tests pass `semanticsEnabled: false`, or semantics becomes part of the identity. |
| Too few frames | Frame count per span | Below the span's minimum is `INVALID` (for example, a list too short to scroll). |
| Thermal | Android `PowerManager` thermal status (Android 10+); iOS `ProcessInfo.thermalState`; both through a small plugin | Above nominal: wait and retry. |
| Low-power mode | Android `PowerManager.isPowerSaveMode()`; iOS `ProcessInfo.isLowPowerModeEnabled` | Must be off. |

### 7.3 Identity

Every run is stamped with: device model, OS version, build mode, thermal
state at start, Flutter version and app commit (both passed with
`--dart-define`), and the Butterscope report schema version.

The refresh rate is not a run field. Each span and episode records the
declared rate it was measured at and its observed rate, because the declared
rate can change during a run. A change inside a span makes that span
`INVALID`, and one inside an episode leaves it without metrics (section 7.2).

Two runs are **comparable** only when every identity field except the app
commit matches. Within comparable runs, spans are matched by name, and a
span's results are compared, or pooled across repetitions, only with results
whose declared rate matches its own within 5%. A candidate span with no
baseline at its rate is `INVALID` and retried, like a failed guard; the run's
other spans are still judged. Where possible, base and candidate run on the
same physical unit in the same session, interleaved.

### 7.4 Rig rules

- Dedicated devices: not shared with manual testing, OS auto-update off.
- Do Not Disturb on, auto-lock off, battery at 50% or more, a cooldown between
  runs, and the phone out of its case.
- **Samsung Galaxy S24** (Android): Motion smoothness set to Adaptive,
  which allows up to 120 Hz. Adaptive lets the screen drop its rate on its
  own. When the S24 was forced to 60 Hz mid-run, `Display.refreshRate`
  kept reporting 120 Hz, so only a rate mismatch flags such a drop
  (section 4, [0002](decisions/0002-m2-recorder-findings.md)). Stay awake
  (Developer options) on, so the screen never locks during a run.
- **iPhone 17 Pro** (iOS): ProMotion, adaptive up to 120 Hz. Limit Frame Rate
  off (Settings › Accessibility › Motion), because it caps the screen at
  60 Hz; Reduce Motion and Low Power Mode off. Under `benchmarkLive`
  ProMotion held 120 Hz, even while nothing changed on screen. With Limit
  Frame Rate on, `Display.refreshRate` still reported 120 Hz while the
  screen ran at 60 Hz, so only a rate mismatch flags a capped or slower
  screen ([0002](decisions/0002-m2-recorder-findings.md)).
- **Info.plist on iOS:** `CADisableMinimumFrameDurationOnPhone` matches what
  ships to users. Without it a ProMotion iPhone holds a Flutter app to 60 Hz.
  Flutter 3.47.5's app template sets it to true, so the sample app can reach
  120 Hz.

### 7.5 Build rules

- Locally: `flutter drive --profile --no-dds --keep-app-running` on a
  physical device. Without `--keep-app-running`, `flutter drive` uninstalls
  the app when it stops
  (`packages/flutter_tools/lib/src/drive/drive_service.dart`, `stop()`); on
  an iPhone signed by a personal developer account, the phone then asks to
  trust the developer again before every run. `flutter drive` does not
  drive release builds, so release runs are launched directly. Xcode stays
  closed during iOS runs, or the launch goes through it and stalls.
- Same Flutter SDK and flavour as the release build; only the data layer is
  faked.
- Third-party SDKs (analytics, crash reporting, APM) stay initialised: their
  main-thread cost is real, and an SDK upgrade can itself be the regression.
- The perf entrypoint sets `HttpOverrides.global` to fail any real HTTP call,
  so a stray request fails loudly instead of adding random latency.

## 8. Getting results off the device

1. **Locally**, the report is printed as tagged, numbered chunks, because
   device logs can truncate long lines (Android logcat does). `butterscope
   collect` reads `adb logcat` or a saved log, reassembles the chunks,
   validates the schema and writes one JSON file per run. A missing or
   corrupt chunk is reported, never silently dropped. Logcat drops lines
   without warning when they come fast (about 400 of 1,300 one-frame lines
   in M2), so chunks must stay few and dense. On an iPhone, profile output
   reaches the `flutter drive` transcript, and release output is read with
   `idevicesyslog` from libimobiledevice
   ([0002](decisions/0002-m2-recorder-findings.md)). **(open, M7: schema
   v1.)**
2. **On the device farm** (LambdaTest, Real Device App Automation), tests run
   through the **Flutter Dart** runner as Android instrumentation, so gestures
   come from inside the app process. The Appium route is not used: it embeds
   a server in the measured app, its UiAutomator2 path typically turns
   semantics on, and remote gestures add timing jitter.
3. LambdaTest's guide builds a debug app; Butterscope needs a profile build,
   with release as the fallback. **(open, M3: proven on the farm.)**
4. The farm runs no host script, so reports leave through the device log
   (requested with the build's `deviceLog` option) and are fetched through
   LambdaTest's API.
5. The farm assigns a device by model, not by unit, so farm runs need more
   repetitions; dedicated private devices are an option later.

## 9. Decision rules

Designed in M9 from M8's measurements. These principles are fixed now:

- A candidate is compared with a baseline from `main` on the same device
  model, never with an absolute number alone.
- Each flow is repeated; a change counts only when it is larger than the
  measured noise and statistically significant (the approach of Reassure and
  criterion.rs).
- Absolute budgets exist at two levels, warn and error, set per flow from
  M8's measurements.
- A self-check compares `main` with `main` and must pass.
- **Rate mismatches are settled by symmetry** (section 4). Base and head
  run interleaved on the same unit, so a screen that drops on its own is as
  likely in either. Mismatches in most head repetitions of a span and few
  base ones point at the change: every repetition is judged and the span
  can `FAIL`, on missed vsyncs when the frames that rendered were smooth.
  Otherwise the mismatched repetitions are left out and re-run, and a span
  that cannot get enough clean repetitions is `INVALID`.
- Unstable flows (section 6, item 7) are reported, not gated.

**(open, M9: repetitions, statistic, noise thresholds, budgets, and the
thresholds for "most" and "few" rate mismatches.)**

### 9.1 When it runs

No device run happens on every push. Each flow is repeated with and without
the change, with cooldowns in between: for example, 5 flows × 30 s × 5
repetitions × 2 builds is 25 minutes of device time, before builds, installs
and farm queueing. M8 measures the real figure.

| Trigger | What runs | Blocks? | In the PoC |
| --- | --- | --- | --- |
| Every push to a pull request | Host checks: format, analyze, unit tests | Yes: merging, through `required` | Yes |
| A pull request labelled `perf` | Its flows, base vs head on one device model | No: the verdict is posted on the pull request for review | Yes (M10) |
| Every merge to `main` | All flows, head only, compared with recent `main` runs | No: a regression is reported with the merges that could have caused it | No |
| A release candidate | All flows, against the last release | Yes: the release waits | No |

- **Why not block every pull request:** time and farm capacity. AndroidX runs
  its benchmarks after merge, not before. It finds regressions by step fitting
  over several builds, because two runs alone are not enough. Its advice for
  running on a pull request is to inform review, not block it.
- **Who adds `perf`:** the author or a reviewer, for changes to a gated flow,
  shared UI, the data layer or an SDK upgrade.
- **Option not taken for the PoC:** a merge queue, which runs the device
  check once per merge before `main`. GitHub offers merge queues only on
  organization repositories (public, or private on Enterprise Cloud).

**(open, M9: label name; whether a `perf` FAIL ever blocks; the step-fit
window on `main`.)**

## 10. Packages

| Package | Role | Dependencies |
| --- | --- | --- |
| `butterscope` | Recorder, metrics, report | Flutter only. Safe to ship in an app later. |
| `butterscope_test` | One-line attach, spans, episodes | `butterscope`, `flutter_test`, `integration_test`. A dev dependency. |
| `butterscope_cli` | `collect`, `judge` | Pure Dart; host only. |
| `butterscope_sample` | Proof app with ordinary tests and planted regressions | Not shipped. |

- **No third-party runtime dependencies** in `butterscope`.
- **Lints:** [very_good_analysis](https://pub.dev/packages/very_good_analysis)
  11.x, as a dev dependency of every package; one shared
  `analysis_options.yaml` at the root.
- **Toolchain:** Flutter 3.47.5 (Dart 3.13.4), pinned in `.fvmrc`; CI reads the
  same file.
- **CI gate:** branch protection requires one check, `required`, which passes
  only when every other CI job succeeded. Each new job is added to its
  `needs`. Dependabot bumps the GitHub Actions weekly.

## 11. References

- Flutter: [FrameTiming](https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html),
  [FramePhase](https://api.flutter.dev/flutter/dart-ui/FramePhase.html),
  [FrameData](https://api.flutter.dev/flutter/dart-ui/FrameData-class.html),
  [Display](https://api.flutter.dev/flutter/dart-ui/Display-class.html),
  [PlatformDispatcher](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher-class.html),
  [LiveTestWidgetsFlutterBindingFramePolicy](https://api.flutter.dev/flutter/flutter_test/LiveTestWidgetsFlutterBindingFramePolicy.html),
  [watchPerformance](https://api.flutter.dev/flutter/package-integration_test_integration_test/IntegrationTestWidgetsFlutterBinding/watchPerformance.html),
  [kBuildBudget](https://api.flutter.dev/flutter/flutter_driver/kBuildBudget-constant.html),
  [testWidgets](https://api.flutter.dev/flutter/flutter_test/testWidgets.html),
  [UI performance](https://docs.flutter.dev/perf/ui-performance).
- iOS: [iPhone 17 Pro specs](https://support.apple.com/en-us/125090),
  [ProcessInfo](https://developer.apple.com/documentation/foundation/processinfo),
  [ProMotion refresh rates](https://developer.apple.com/documentation/quartzcore/optimizing_promotion_refresh_rates_for_iphone_13_pro_and_ipad_pro).
- CI: [Fighting regressions with benchmarks in CI (AndroidX)](https://medium.com/androiddevelopers/fighting-regressions-with-benchmarks-in-ci-6ea9a14b5c71),
  [GitHub merge queues](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue).
- Prior art: [JankStats](https://developer.android.com/topic/performance/jankstats),
  [FrameTimingMetric](https://developer.android.com/reference/androidx/benchmark/macro/FrameTimingMetric),
  [XCTest hitches (WWDC20)](https://developer.apple.com/videos/play/wwdc2020/10077/),
  [Lighthouse user flows](https://github.com/GoogleChrome/lighthouse/blob/HEAD/docs/user-flows.md),
  [Reassure](https://github.com/callstack/reassure),
  [Criterion.rs](https://bheisler.github.io/criterion.rs/book/analysis.html).
- Farm: [LambdaTest Flutter Dart on Android](https://www.testmuai.com/support/docs/getting-started-with-flutter-dart-android-automation/),
  [Patrol on LambdaTest](https://patrol.leancode.co/documentation/integrations/lambdatest).
