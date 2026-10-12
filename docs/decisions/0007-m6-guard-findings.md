# 0007: Guards, rate mismatch, run identity and semantics

- Status: accepted
- Date: 2026-10-12
- Milestone: M6

## Context

M6 made every report say whether its run and spans can be trusted, and
why not. It built the guards DESIGN 7.2 names, the per-slice rate
mismatch (0001 item 6, 0002 decision 4) and the run identity in 7.3.
DESIGN left semantics open for M6 (7.2), and 0005 left the harness's
cost with semantics on open for it. The data is in
[`docs/measurements/m6.md`](../measurements/m6.md). Every run was on the
same Galaxy S24 and iPhone 17 Pro as M2 to M5, with Flutter 3.47.6 in
profile mode, from 2026-10-11 to 2026-10-12.

What M6 built:

- **The rate mismatch** (#33). Each span and episode is cut into
  one-second slices. A slice with at least 10 qualifying gaps whose rate
  differs from the declared one by more than 5% is flagged, with its
  second, gap count and observed rate. It never voids anything.
- **A device-state plugin in `butterscope`** (#34). Dart cannot read the
  thermal state, power saving, the model or the OS version, so Kotlin
  and Swift code reads them behind one method channel,
  `butterscope/device`. Flutter 3.47.6 leaves plugins reached only
  through dev dependencies out of Android release builds
  (`flutter_tools/lib/src/flutter_plugins.dart`, line 1408), and a plugin
  reached only through `butterscope_test` counts as one
  (`package_graph.dart`, line 40). So the code lives in `butterscope`,
  which apps already list for the route observer. It has no third-party
  dependency.
- **Guards and identity** (#35). Run guards are read at the run's start,
  each test's start and end, and the run's end: outside every test's
  frames, so they cost no measured frame. Span guards are judged from
  the recording. A failed run guard voids the run and every span in it.
- **A runner that checks each run** (#36), `tool/m6/run_tests.sh`, and
  the semantics comparison (#37).

What the runs showed:

- **Clean runs are valid.** Every clean run of `app_test.dart` on the
  S24, and every one on the iPhone that started at nominal, was VALID
  for the run and every span, with semantics recorded on each span, and
  flagged no rate mismatch: 3 in #36 and 10 in #37 on each phone, each
  batch after an uncounted warm-up. Three more iPhone runs started at
  `fair` and were void by the thermal guard alone (below).
- **Each guard fired when its condition was forced**, at its level, and
  named nothing else but, in some iPhone runs, the thermal state `fair`:
  debug build, frame policy, animations (Android's
  animation scale at 0, iOS Reduce Motion), thermal (the S24 forced to
  `moderate` over adb; the iPhone at a real `fair`) and power saving, on
  both phones. A span shorter than 11 vsyncs was void by `tooFewVsyncs`
  alone on both phones. Text scale and locale void a run only when they
  change during it; a run launched with a larger font or another
  language came back with the value in its identity and no text scale
  or locale reason.
- **Some guards are checked by unit test only.** Neither phone reports a
  change of declared rate (0002 decision 5), so the declared-rate guards
  are not forced. A span left open at its test's end, an app built
  without the plugin, and a text scale or locale that changes mid-run
  are unit tests too. Xcode's Device Conditions could not force the
  iPhone's thermal state: Xcode 27 has no Devices window in its Window
  menu. The guard fired on real `fair` reads instead.
- **The rate mismatch catches a slower screen, and only that.** On the
  S24, switched to Standard (60 Hz) mid-run, the declared rate stayed
  at 120 and every part after the switch flagged each judged slice at 60
  Hz; launched in Standard, the S24 declared 60 and flagged nothing. On
  the iPhone, Limit Frame Rate kept the declared rate at 120 while every
  span ran at 60 and flagged, in two runs. Low Power Mode capped the
  iPhone at 60 Hz the same way; it voids the run by itself. The S24's
  battery saver kept 120 Hz on the charger. No clean run flagged a
  slice.
- **Frame policy off `benchmarkLive` can stall the final flush.** On the
  S24 the recording's last frame waited for a timing until the flush gave
  up at 500 ms. The run is void by the frame policy anyway.
- **Semantics costs a few missed vsyncs, not janky frames.** Each phone
  ran `app_test.dart` five times as `testWidgets` leaves semantics (on)
  and five times with `semanticsEnabled: false`. With semantics on, the
  S24's hitch ratio median was higher on all six spans, and its missed
  vsyncs median on five, for example feed scroll at 5 missed vsyncs
  against 2. On the iPhone only feed scroll moved. The janky rate
  barely moved on either phone. No gap was larger than the wider of the
  two groups' spreads across runs, so five runs cannot separate it from
  noise.
- **Semantics spread runs wider on some spans and narrower on others.**
  With semantics on, the spread across runs was wider on the S24's
  detail and gallery spans (hitch ratio 54 against 17, and 114 against
  75) and the iPhone's feed (60 against 29), and narrower on the S24's
  inbox (26 against 36) and in the gallery's janky rate.
- **Semantics does not make the harness's steps dearer, except typing
  on the iPhone.** With semantics on, each of M5's harness steps cost at
  most 0.1 ms more than M5 measured with it off, and often less. Typing
  on the iPhone cost 7.0 ms a keystroke against 5.2; on the S24 it cost
  less, 7.2 ms against 10.8. On both phones a typing span missed more
  vsyncs: 7 to 19 against 5 to 11 on the S24, and 4 to 6 against 0 to 3
  on the iPhone. M5 ran on Flutter 3.47.5, and four of the five iPhone
  runs were at `fair`.
- **The iPhone reads `fair` within minutes on its cable**: about 8 to 13
  minutes into a session of runs, and straight after a build. Three clean
  runs at `fair` matched three at nominal: every span's range overlapped,
  and the median was the same or better at `fair` on five of six. Apple
  describes `fair` as slightly elevated and `serious` as the state where
  performance may be impacted (`ProcessInfo.ThermalState`). The sample is
  small and the app light.

What the Flutter source showed:

- **The semantics read is the binding's.** DESIGN read
  `PlatformDispatcher.semanticsEnabled`, which reports only the phone's
  accessibility services. `testWidgets` turns semantics on with a handle
  opened in the test body (`flutter_test/lib/src/widget_tester.dart`,
  line 180), which sets `SemanticsBinding.semanticsEnabled`
  (`flutter/lib/src/semantics/binding.dart`, line 148), not the platform
  flag. The binding's flag starts from the platform's, so TalkBack and
  VoiceOver show in it too.
- **A failed test leaves semantics on.** The handle is disposed only
  after the test body returns (`widget_tester.dart`, line 197), so after
  a test throws, later spans in the file read semantics on. No unit test
  pins this: a test that must fail would fail the suite.
- **`disableAnimations` lives on `SemanticsBinding`**
  (`semantics/binding.dart`, line 241), which `WidgetsBinding` mixes in.
  DESIGN cited it on `WidgetsBinding`; the read is the same.
- **The Flutter version needs no define.** The `flutter` tool adds
  `FLUTTER_VERSION` and the engine revision to every build it makes
  (`flutter_tools/lib/src/runner/flutter_command.dart`, lines 1515 and
  1572), and the app reads them through `FlutterVersion`. DESIGN 7.3 said
  both the Flutter version and the app commit are passed with
  `--dart-define`; only the app commit is.

## Decision

1. **Semantics: record it, and compare like with like** (option B).
   `testWidgets` keeps its default. Each span records whether semantics
   was on at its start and at its end. It never voids a span. Spans are
   compared and pooled only with spans that read the same at both.
   Option A, requiring `semanticsEnabled: false` in every observed test,
   was not taken: the data does not show a clearly wider spread with
   semantics on, and A would add an argument to every team test, or void
   its spans. **(open, M8: whether semantics-on noise hides a small
   regression.)**
2. **iOS `fair` leaves a run valid.** The thermal guard voids a run when
   Android reports any status but `none`, or iOS reports `serious` or
   `critical`, or the phone cannot say. The identity still records the
   state at the run's start, so a baseline can be checked for it.
3. **The guards as built, and their levels** (DESIGN 7.2):

   | Guard | Read | Level |
   | --- | --- | --- |
   | `buildMode` | `kDebugMode`, `kProfileMode`, `kReleaseMode` | Run |
   | `framePolicy` | The binding's `framePolicy`, at each test's start and end | Run |
   | `animations` | `SemanticsBinding.disableAnimations`; on iOS also Reduce Motion | Run |
   | `textScale` | `PlatformDispatcher.textScaleFactor` at each test's start, against the run's start | Run |
   | `locale` | `PlatformDispatcher.locale` at each test's start, against the run's start | Run |
   | `thermal` | The plugin, at the run's start, each test's start and the run's end | Run |
   | `lowPower` | The plugin, as for thermal | Run |
   | `deviceState` | The plugin could not be reached | Run |
   | `declaredRate` | A declared rate of 0 or not finite anywhere in the recording (0001 item 7) | Run |
   | `declaredRateChange` | A declared rate inside a span more than 5% from its start | Span |
   | `tooFewVsyncs` | A span whose rendering time (0001) lasts fewer than 11 vsyncs: frames drawn, plus its hitch time in vsyncs | Span |
   | `openAtTestEnd` | A span still open when its test ends | Span |

   Each failure is named with where it was seen and, when it says more,
   the value read. Semantics is recorded on each span and is not a guard.
4. **Text scale and locale are identity, not declared values** (plan
   question 3). The run's start stamps them; a later read that differs
   voids the run. Runs with different values are not comparable.
5. **A span must last 11 vsyncs** (plan question 4): the frames one rate
   slice needs for its 10 gaps. The count is the span's rendering time
   divided by `B`: frames drawn, plus missed vsyncs, plus late frames'
   overrun as a share of `B`. So a span that janks badly is not voided
   for drawing few frames, and the count can be fractional.
6. **The identity** (DESIGN 7.3) is the device model, OS version, build
   mode, thermal state at the run's start, Flutter version and engine
   revision, app commit, text scale, locale and the report schema
   version. The app commit is passed with
   `--dart-define=BUTTERSCOPE_APP_COMMIT=<sha>`; the Flutter version
   comes from the tool.
7. **`butterscope` carries native code** for the device reads (plan
   question 2), with no third-party dependency. DESIGN 10's "Flutter
   only" becomes "no third-party dependencies".
8. **The runner's checks** (DESIGN 7.4):
   - The warm-up must be VALID and flag no rate mismatch. This replaces
     M5's rule that it draw at 114 Hz or more. A guard the batch names
     in `ALLOW` may void the warm-up too, as it may void a counted run.
   - On Android the runner also stops when a third-party app holds more
     than 300 MB (plan question 6). On 2026-10-10 a trading app left in
     the background held about 812 MB and raised the S24's clean Search
     and Inbox loss.
   - On iOS the runner stops the previous app with `devicectl`, and
     refuses to start while Xcode is open.

## Consequences

- Every report now says whether its run and each span can be trusted,
  and why not. M9's judge reads the reasons; M7 freezes their names in
  schema v1.
- Under B a span with semantics on has no baseline from a span with it
  off, and the reverse. A test that fails leaves semantics on for the
  rest of its file, so those later spans may find no matching baseline.
  How a run with a failed test is judged is M9's.
- Clean S24 spans do not read 0: semantics adds a few missed vsyncs.
  Base and head run the same tests, so a comparison stands. Whether
  that noise hides a small regression is M8's to measure, when it
  plants regressions in real flows.
- An iPhone can run on its cable without cooling breaks. If a heavier
  app does throttle at `fair`, the identity shows the state, and M8 can
  split its data by it.
- The S24's thermal rule is unchanged: `light` still voids a run.
- The guards checked by unit test only stay unproven on a phone. The
  declared-rate guards cannot be forced on either phone (0002 decision
  5). The iPhone's thermal guard was proven only at `fair`, which no
  longer voids, so it is now unproven on that phone at `serious`.
- Apps built for Android release runs must list `butterscope` under
  their own dependencies, or the device reads are missing and the run is
  void by `deviceState`.
- An app that ships `ButterscopeRouteObserver` also ships the plugin's
  channel. It is idle until a run reads it.
