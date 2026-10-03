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
| **Build time** | `FrameTiming.buildDuration`: UI thread work for one frame. |
| **Raster time** | `FrameTiming.rasterDuration`: raster thread work for one frame. |
| **Overrun** | `max(build, raster) − B`. Positive means the frame was late. |
| **Hitch ratio** | Total positive overrun (ms) per second of a span or episode. |
| **Episode** | A continuous burst of frames, split automatically by idle gaps. |
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
4. **The engine may batch `FrameTiming` reports about once a second.** The
   recorder discards stale timings before a window and waits after it until
   every frame has been reported. **(open, M2: exact flush rules.)**
5. **Window boundaries are matched to frames** by one of two existing APIs
   **(open, M2: which one holds)**:
   - `PlatformDispatcher.frameData.frameNumber` against
     `FrameTiming.frameNumber` (the docs do not say they match), or
   - `SchedulerBinding.currentSystemFrameTimeStamp` against
     `FrameTiming.timestampInMicroseconds(FramePhase.vsyncStart)`.
6. **Timelines are for people, not gates.** A failing flow is diagnosed by
   re-running it locally with DevTools or `traceAction`.

## 4. Classifying frames

**Budget.** `B = 1000 / refreshRate`, where `refreshRate` is the test view's
`FlutterView.display.refreshRate`, read at the start of every run and stored
in its identity.

Each frame gets one class. The classes are nested: every stall is severe and
every severe frame is janky.

| Class | Rule | Why |
| --- | --- | --- |
| Smooth | `build ≤ B` and `raster ≤ B` | |
| Janky | `build > B` or `raster > B` | At least one vsync was missed. |
| Severe | `max(build, raster) > 2B` | Several vsyncs missed: a visible hitch. |
| Stall | `max(build, raster) ≥ 100 ms` | A perceived freeze. Wall-clock, not budget-relative, because 150 ms feels the same at 60 Hz and 144 Hz. **(open, M8: tune 100 ms.)** |

**Thread tag.** Each janky frame is tagged `ui`, `raster` or `both`. This is
the first fork of Flutter's own triage advice: UI time is Dart work;
raster-only time is rendering cost (`saveLayer`, clips, shadows, opacity).

**Not used for jank:** `totalSpan` (vsync to raster finish) and
`vsyncOverhead`. The UI and raster threads are pipelined, so `totalSpan` can
exceed `B` with no dropped frame. Both are kept as latency diagnostics.

**Overrun is an estimate.** `FrameTiming` has no timestamp for when a frame
reached the screen, so overrun approximates how late it was.

**Observed refresh rate** = the most common gap between consecutive
`vsyncStart` timestamps while frames are continuous. Janky frames produce gaps
that are multiples of the interval, so the mode is used, not the mean.

## 5. Metrics

All gate metrics are normalised to `B`, so one threshold is correct on 60, 90,
120 and 144 Hz screens.

### Gate metrics (per span)

| Metric | Definition |
| --- | --- |
| **Hitch ratio** (headline) | Σ positive overrun (ms) ÷ span duration (s). Starting budget: **5 ms/s**, Apple's threshold for a good experience. |
| Janky rate | Janky frames ÷ frames, reported overall and per thread. |
| Severe count | Number of severe frames. |
| Stall count | Number of stalls. |
| p90, p99 build | As multiples of `B`. |
| p90, p99 raster | As multiples of `B`. |
| Worst build, worst raster | As multiples of `B`. |
| Frame count | Secondary: explains changes in the others (fewer trivial frames can make averages worse). |

**Percentiles** use the nearest-rank method, so results never depend on a
library's interpolation. **Span duration** for the hitch ratio is fixed in M1.
**(open, M1.)**

### Diagnostic metrics (recorded, never gated)

- Averages of build and raster time.
- p90 and p99 of `vsyncOverhead` and `totalSpan` (latency, for example
  tick-to-pixel on a live price screen).
- Raster cache counts and bytes from `FrameTiming` (`layerCacheCount`,
  `layerCacheBytes`, `pictureCacheCount`, `pictureCacheBytes`).
- Garbage-collection counts are **not** collected: they need the VM timeline.

## 6. The passive observer

1. **One line attaches.** A call at the top of a test file's `main`, before
   any `testWidgets`, sets the frame policy, records the whole run, and emits
   the report when the tests finish. **(open, M5: API names.)**
2. **Frame policy: `benchmarkLive`.** The live test binding defaults to
   `fadePointers`, which renders frames at the test's own pump rhythm, not at
   vsync. `LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive` lets the
   engine schedule frames the way a real device does. Flutter's docs warn
   that changing the policy can change test behaviour, so M5 records which
   ordinary tests run unchanged. A run whose frames are not vsync-driven is
   `INVALID` (section 7).
3. **Episodes** split the run automatically: a new episode starts after an
   idle gap with no frames (**100 ms to start, open M8**). An optional
   navigator observer tags each episode with its route. Episodes are
   advisory: the same flow can split differently from run to run.
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

### What the report contains

- **Identity** (section 7.3) and **validity** with reasons.
- **Per span:** every gate and diagnostic metric.
- **Per episode:** the same metrics, plus the route tag when available.
- **Issues:** one entry per janky frame: time offset, span or episode, thread,
  overrun as a multiple of `B`, class.

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
| Refresh rate | Declared (`Display.refreshRate`) vs observed (section 4) | Must match. |
| Animations | `WidgetsBinding.instance.disableAnimations`; on iOS also `PlatformDispatcher.accessibilityFeatures.reduceMotion`, because Reduce Motion does not set `disableAnimations` | Both must be false. |
| Text scale | `PlatformDispatcher.textScaleFactor` | Must equal the declared value (1.0 unless the run declares otherwise). |
| Locale | `PlatformDispatcher.locale` | Must equal the declared value. |
| Semantics | `PlatformDispatcher.semanticsEnabled` | **(open, M6.)** `testWidgets` turns semantics on by default (`semanticsEnabled: true`), so either observed tests pass `semanticsEnabled: false`, or semantics becomes part of the identity. |
| Too few frames | Frame count per span | Below the span's minimum is `INVALID` (for example, a list too short to scroll). |
| Thermal | Android `PowerManager` thermal status (Android 10+); iOS `ProcessInfo.thermalState`; both through a small plugin | Above nominal: wait and retry. |
| Low-power mode | Android `PowerManager.isPowerSaveMode()`; iOS `ProcessInfo.isLowPowerModeEnabled` | Must be off. |

### 7.3 Identity

Every run is stamped with: device model, OS version, declared and observed
refresh rate, build mode, thermal state at start, Flutter version and app
commit (both passed with `--dart-define`), and the Butterscope report schema
version.

Two runs are **comparable** only when every identity field except the app
commit matches. Where possible, base and candidate run on the same physical
unit in the same session, interleaved.

### 7.4 Rig rules

- Dedicated devices: not shared with manual testing, OS auto-update off.
- Do Not Disturb on, auto-lock off, battery at 50% or more, a cooldown between
  runs, and the phone out of its case.
- **Samsung Galaxy S24** (Android): Motion smoothness set to Adaptive,
  which allows up to 120 Hz. Adaptive lets the screen drop its rate on its
  own; the refresh-rate guard catches that.
- **iPhone 17 Pro** (iOS): ProMotion, adaptive up to 120 Hz. Limit Frame Rate
  off (Settings › Accessibility › Motion), because it caps the screen at
  60 Hz; Reduce Motion and Low Power Mode off. ProMotion also drops its rate
  on its own; the refresh-rate guard catches that. **(open, M2: what
  `Display.refreshRate` reports while ProMotion varies.)**
- **Info.plist on iOS:** `CADisableMinimumFrameDurationOnPhone` matches what
  ships to users. Without it a ProMotion iPhone holds a Flutter app to 60 Hz.
  Flutter 3.47.5's app template sets it to true, so the sample app can reach
  120 Hz.

### 7.5 Build rules

- Locally: `flutter drive --profile --no-dds` on a physical device.
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
   corrupt chunk is reported, never silently dropped. **(open, M7: schema v1,
   and which log carries the chunks off an iPhone.)**
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
- Absolute budgets exist at two levels, warn and error.
- A self-check compares `main` with `main` and must pass.
- Unstable flows (section 6, item 7) are reported, not gated.

**(open, M9: repetitions, statistic, noise thresholds, budgets.)**

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
