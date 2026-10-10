# 0005: The public API, episodes and what M5 measured

- Status: accepted
- Date: 2026-10-10
- Milestone: M5

## Context

M5 built the API a team writes: one line that attaches Butterscope to a
test file, spans around the flows to gate, and episodes that split each
test on their own. DESIGN.md left six items open for M5: the API names
(6.1), which ordinary tests run unchanged under `benchmarkLive` (6.2), how
episodes split (2, 6.3), how frames are attributed to tests (6.5), Patrol
(6.6) and the harness's cost (6.8). The data is in
[`docs/measurements/m5.md`](../measurements/m5.md). Every run was on the
same Galaxy S24 and iPhone 17 Pro as M2 and M4, with Flutter 3.47.5 in
profile mode.

What the runs showed:

- **M4's tests pass with only the attach line,** clean and with each
  screen's plant: 7 of 7 builds on each phone. No test file needed more
  than the line. Butterscope itself needed one change, below.
- **A blinking cursor kept iOS tests from settling.** On the first
  iPhone run every Search test waited 40 to 80 s after typing, drawing
  1,000 to 21,000 idle frames, until the app was sent to the background.
  On iOS a focused field's cursor fades with an animation that restarts
  from a zero-length timer (`_onCursorTick` in
  `widgets/editable_text.dart`). Under `benchmarkLive` a pump waits only
  while frames keep running, so `pumpAndSettle` almost never lands in
  the gap between two fades. Under the default `fadePointers` each pump
  draws one frame and checks right after it, so M4's tests found the gap.
  Android blinks on a periodic timer and was not affected. With the
  cursor held still, the Search tests took 1 to 2 s and all builds
  passed. Apart from this, `pumpAndSettle` settled under `benchmarkLive`
  on both phones, as the source predicted.
- **Spans report every metric.** In every run on both phones, every span
  reported all 19 gate metrics and all 8 diagnostics. Every planted
  span was clearly worse than its clean span, 3.6 to 11.9 times its
  hitch ratio on the S24. But a span covers one short action, where M4's
  probe ran the same action for 5 s, so a span's janky share is not
  M4's.
  `raster_clip` and `gpu_blur` reached 92 to 100% of a span's frames.
  `ui_busy` and `sync_decode` showed as missed vsyncs, not janky frames.
  The S24's clean Feed and Gallery spans were 13 to 15% janky, against
  0 to 1.3% on the iPhone. The ordinary tests keep semantics on, which M4
  found costs the S24's Feed 4.5 to 6.1% of frames, so part of that is
  likely semantics (inferred). The owner accepted this reading on
  2026-10-09.
- **The S24 draws its first frames at 60 Hz.** In the test that only
  launches the app, the S24 drew 5 or 6 frames at 60 Hz; the iPhone drew
  11 or 12 at 120 Hz. Every longer test drew at 120 Hz on both phones.
- **Every candidate episode rule repeated.** Two rules were tried, each at
  150, 300, 500 and 1000 ms of quiet: A splits on input or animation, B
  on input only. In 5 clean runs per phone every rule repeated every
  test's episode count. Under A, the streams on Activity and Inbox
  animate throughout, so each of those tests stayed one episode, and at
  150 ms A split two Inbox tests differently on the two phones. B at
  300 ms was chosen. In 10 fresh runs per phone it repeated every test's
  count in 10 of 10 (the bar was 9 of 10), with the same 32 episodes per
  run on both phones. Every episode carried a page tag, metrics and
  diagnostics. The final split was rerun over the same 10 runs per phone
  and gave the same counts.
- **One test sits near the quiet stretch.** In "Feed comes back" the tap
  that opens the detail page comes 317 to 429 ms after the test starts,
  317.2 ms at the least. A tap within 300 ms of the start would join the
  first episode, so the margin is about 17 ms.
- **Reading the tree costs no more frames than an empty span; gestures
  cost some on a real screen; typing costs the most.** Each step ran 50
  times, 100 ms apart, in a 5 s span of its own, in 5 runs per phone. The
  ms columns are each call's elapsed time on a stopwatch, not UI time: an
  async call's time can include a frame drawn while it waits.

  | Step | Screen | S24 median ms | S24 janky per span | iPhone median ms | iPhone janky per span |
  | --- | --- | --- | --- | --- | --- |
  | Finders, `expect`, `tester.widget` | Still | 0.5 to 0.6 | 0 | 0.3 | 0 |
  | Finders, `expect`, `tester.widget` | Feed | 1.1 to 1.9 | 0 | 1.1 to 1.8 | 0 |
  | `tap`, `drag` | Still | 2.0 to 2.2 | 0 to 1 | 1.5 to 1.7 | 0 |
  | `tap`, `drag` | Feed | 6.1 to 6.2 | 0 to 6, up to 27 missed vsyncs | 5.4 | 0 |
  | `enterText`, one keystroke | Still | 2.5 | 0 to 1 | 1.3 | 0 |
  | `enterText`, one keystroke | Search | 10.8 | 23 to 49 | 5.2 | 1 to 2 |

  Empty spans of the same length lost 0 or 1 janky frame a run on the
  S24 and none on the iPhone; the finder spans lost no more. On Search
  each keystroke also runs the app's search, inside `onChanged`
  (`apps/sample/lib/src/search/search_screen.dart`), so that row's time
  and frames are mostly the app's response, which a person typing would
  cause too. This is inferred from the still screen, where the same
  keystroke into a field with no handler cost 2.5 ms on the S24 and lost
  0 or 1 janky frame a run, as an empty span did.
- **iPhone runs failed four times for reasons outside the test.** Twice
  the phone had dropped from its cable to Wi-Fi debugging. Once the
  launch went through Xcode and never attached. Once the app was stopped
  mid-test over USB, with no cause found. Once the phone was reconnected
  by cable, and the previous run's app was stopped by hand before each
  run, every run passed on its first try.

## Decision

1. **The API is frozen.** A team writes two calls, and an app may add one
   class:

   | Name | Signature | Package |
   | --- | --- | --- |
   | `attachButterscope` | `void attachButterscope()` | `butterscope_test` |
   | `span` | `Future<T> span<T>(String name, Future<T> Function() body)` | `butterscope_test` |
   | `ButterscopeRouteObserver` | `class ButterscopeRouteObserver extends NavigatorObserver` | `butterscope` |

   `attachButterscope()` goes once at the top of a test file's `main`,
   before any `testWidgets` and outside any `group`. Calling it again in
   the same run does nothing, so a file that runs other files' `main`s
   still records one run. `span`'s future fails with a `StateError`
   before `attachButterscope()`, outside a test or inside another span,
   and with an `ArgumentError` for a name already used in the run. M6
   may add named options to `attachButterscope` without breaking it.
   DESIGN 6.1 is closed.

2. **One recording covers the run; tests, spans and episodes are marks
   inside it.** A mark stores the latest frame number, a time and a read
   of the declared rate. Each test's start and end are marked in `setUp`
   and `tearDown`, labelled with the test's full name from
   `TestHandle.current.name` (`package:test_api/hooks.dart`, test_api
   0.7.12), because `flutter_test` keeps the description private. Frames
   drawn between tests belong to no test. Metrics are computed from the
   frames between marks after the last test. DESIGN 6.5 is closed.

3. **Ordinary tests run unchanged under `benchmarkLive`, with the text
   cursor held still.** `attachButterscope()` sets
   `EditableText.debugDeterministicCursor`, which is not limited to
   debug builds. A span that types does not measure the cursor's fade.
   DESIGN 6.2 is closed.

4. **Episodes split on input, after 300 ms without it.** The first
   episode starts with the test. A later one starts at a pointer event
   that follows at least 300 ms without one, counted from the test's
   start for its first. Animation does not count. With
   `ButterscopeRouteObserver` in the app, a change of page starts an
   episode at the input that led to it: input that ended less than
   300 ms before the change, or else at the change itself. It starts
   none when an episode started less than 300 ms before that point, so a
   tap less than 300 ms after an episode starts stays in that episode,
   with the page it opens. Each episode is tagged with the page on top at
   its end, by its route name. Every frame of a test belongs to exactly
   one episode. A mouse's hover, and a
   pointer arriving or leaving, are not input. The rule and its 300 ms
   are `EpisodeRule.inputOnly` in `package:butterscope`, and the report
   keeps the raw activity, so a host tool can split saved runs again by
   another rule. DESIGN 2 and 6.3 are closed.

5. **`ButterscopeRouteObserver` lives in `butterscope`,** because the
   app's own code holds it and `butterscope_test` is a dev dependency. It
   follows the navigator's `didChangeTop`, so a page removed from the top
   updates the tag and a page replaced below it does not. Only page
   routes count, so a dialog does not split an episode. The app's first
   page tags the first episodes without splitting one. It watches the
   root navigator only, and it does nothing until Butterscope listens, so
   it can stay in a release build.

6. **Diagnostic times are in milliseconds, and raster cache figures are
   each field's peak.** The gate's per-frame times stay multiples of `B`,
   so one threshold fits every screen. Diagnostics explain a cause, which
   reads best in time. A cache count or size is a level, not a cost, so a span
   reports its highest. DESIGN section 5 says so.

7. **Test steps inside a span cost the app's frames by these amounts,
   and a span holds only its flow.** DESIGN 6.8 gains the table above and
   this rule:
   - Inside a span go the flow's own gestures and typing, and the pumps
     that wait for them.
   - Setup goes before the span, and checks of the result after it. They
     cost little, but inside a span they add frames that are not the
     flow, and those dilute its rates (DESIGN section 5).
   - A finder the flow needs, such as the target of
     `scrollUntilVisible`, may stay inside. At 10 calls a second, finders
     and expectations lost no more frames than an empty span on either
     phone.

8. **The Patrol check moves out of M5,** to the adoption plan after M11,
   where a production app's runner is known. Verifying it now means
   adding Patrol's native test targets to the sample on both platforms,
   for a runner no milestone uses. `attachButterscope()` relies only on
   `IntegrationTestWidgetsFlutterBinding`, which `PatrolBinding` extends,
   so it should work, but that stays unverified. DESIGN 6.6 is marked
   **(open, adoption plan)**.

9. **The rig rules gain three lines.** DESIGN 7.4 and 7.5 now say:
   - The warm-up must draw at 114 Hz or more in every test of 11 frames
     or more, or the batch stops. Until M6's rate mismatch, a capped
     screen reads as an app losing half its frames. 0001 judges a slice's
     rate only from 10 vsync gaps or more, which take 11 frames; the
     check borrows that minimum, so a test that only launches the app is
     not checked.
   - On Android, the runner of the ordinary tests now stops the previous
     run's app before each run, as the probe's does, since the tests now
     record frames.
   - An iPhone run goes over its USB cable, never Wi-Fi debugging. Both
     runs that fell back to Wi-Fi failed.

## Consequences

- The names in decision 1 are fixed for v1. Renaming one needs a new
  decision record and breaks every attached test file.
- A span's numbers cannot be compared with M4's probe windows. M8 sets
  per-flow budgets from spans, against each flow's own clean span on the
  same phone, as DESIGN section 9 already requires.
- Every span with gestures carries their cost. On the S24 a real screen's
  tap or drag took 6 ms a call and, in some runs, cost missed vsyncs.
  Base and head run the same test code, so a comparison stands, but a
  clean span on the S24 does not read 0.
- A span around typing measures the app's response to each keystroke as
  much as the keystroke. That is what a person typing would cause, so it
  stays inside the flow.
- "Feed comes back" is 17 ms from a different episode count. M8 should
  report episode counts per run, so a test that drifts across the line
  shows.
- Episodes are advisory and never gated, so a different rule later
  changes no verdict. The report's raw activity lets M8 or M9 test one on
  saved runs.
- The M5 report is still provisional (schema 0). It holds no identity
  beyond the build mode and no issue list yet; M6 and M7 add them.
- `tool/m4/` stays until M7's `collect` replaces its reading side. Spans
  now do the probe's job.
- `tool/m5/run_tests.sh` stops the previous app only on Android. On the
  iPhone, `--keep-app-running` left the app running after each run, and
  it was stopped by hand before the harness runs. The runner should do
  that on iOS too before M8's runs.
