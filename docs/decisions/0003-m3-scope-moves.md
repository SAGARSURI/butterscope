# 0003: M3's farm check moves to M10 and the rate mismatch to M6

- Status: accepted
- Date: 2026-10-05
- Milestone: M3

## Context

M3 held three items. Two settled the device farm before anything was built
on it: a profile build (or release, if profile is refused) runs on one
LambdaTest model and reports its build mode, and the tagged line is
retrieved by script. Its gate said to stop and re-plan the farm before M4
if neither build mode ran there. The third computed the rate mismatch,
which decision 5 of [0002](0002-m2-recorder-findings.md) left open for M3
because no code computes it yet.

The farm items need a paid LambdaTest plan that runs instrumentation tests
on real devices, billed monthly. Nothing before M10 uses the farm: M4 to
M9 run on the Galaxy S24 and the iPhone 17 Pro, and the perf runs on pull
requests arrive in M10 (`docs/DESIGN.md` section 9.1). M7 also planned to
read M3's farm log.

The rate mismatch is reported per span and episode
([0001](0001-metric-definitions.md), decision 6). Spans and episodes
arrive in M5, so M3 could only have computed it per recorded window. M6
already forces each guard's condition on both phones, and the mismatch is
the flag that stands beside the declared-rate guard.

## Decision

1. **The farm check moves to the start of M10.** Its two items and its
   gate run before the CI loop is built on the farm. If neither profile
   nor release runs there, M10 re-plans the farm. DESIGN section 8 item 3
   is now open for M10.
2. **M7 collects from both phones only.** Reading the farm log moves to
   M10 with the farm check.
3. **The rate mismatch moves to M6.** It is computed per span and episode
   and must flag a forced or capped screen on both phones: the S24 in
   Standard mode, and the iPhone with Limit Frame Rate on. The rule is
   unchanged: one-second slices, at least 10 qualifying gaps, 5% (0001
   decision 6, 0002 decision 4).
4. **M3 closes with no build work.**

## Consequences

- No farm plan is paid for before M10. Whether the farm runs a profile
  build is learned at M10, the only milestone a "no" would change. M4's
  tests are plain `integration_test`, which LambdaTest's Flutter Dart
  runner runs, so a farm re-plan should not change them.
- Until M6, nothing flags a screen that runs slower than it declares. The
  rig rules (section 7.4) keep that out of M4 and M5 runs: the S24 in
  Adaptive and Limit Frame Rate off on the iPhone. A capped screen in
  those runs reads as an app that drops every other frame.
- The mismatch exists before M8's study and M9's judge, which use it.
