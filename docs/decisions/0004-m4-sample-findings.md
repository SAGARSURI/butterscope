# 0004: The sample app's plants and what M4 measured

- Status: accepted
- Date: 2026-10-06
- Milestone: M4

## Context

M4 built `apps/sample`: a catalogue app with six screens, ordinary
integration tests for each, and one planted regression per screen. M2's
five calibration plants moved into the same app. M4 had to show that each
plant visibly janks on both phones, and to set the plants' costs per
platform, which decision 12 of [0002](0002-m2-recorder-findings.md) left
open for M4. The data is in
[`docs/measurements/m4.md`](../measurements/m4.md).

What the runs showed:

- **The ordinary tests pass on both phones,** with no plant and with each
  screen's plant, in profile mode: 7 of 7 runs on each phone.
- **Every plant lands in the band.** With its phone's own cost, each
  plant cost its screen 10% to 60% of frames in 3 of 3 runs on both
  phones. The lowest was the iPhone's `sync_decode` at 16.4%; the highest
  the S24's `ui_busy` at 52.2%. Each cleared its screen's clean build by
  at least 15 points.
- **A clean screen does not lose 0%, and the floor differs by phone.**
  The S24's clean Search screen settled at about 4.5% of frames, steady
  to 0.4 points over 3 runs. Most of it is the harness's own typing:
  `enterText` costs 2 to 3 ms of UI time per keystroke on the S24. Every
  clean iPhone screen lost under 0.5%. M4's milestone asked for the
  clean build under 1%, which the S24's Search cannot meet without
  changing the test, not the app.
- **What is not the app's adds to the clean screens.** The first clean
  runs of one S24 batch lost up to about 4 points more on Search and
  Detail than the same screens later that hour, with under 3 GB of
  memory free. `flutter drive --keep-app-running` left the
  last run's app animating in the foreground, holding about 300 MB and
  half a CPU on the S24 while the next run was set up. Semantics, which
  `testWidgets` turns on unless told otherwise, cost the S24's clean
  Feed 4.5 to 6.1% of frames; with semantics off it lost 0.3 to 0.8%.
- **Costs do not carry over between phones.** With the S24's costs on the
  iPhone, `slow_raster` and `backdrop_blur` lost 0.05% of frames, and
  `gpu_heavy` lost 78% at 15 Hz. M2 saw the same.
- **Decoding a large image costs no frames.** `image_full_res`, the
  planned Gallery plant, cost 1.4% on the S24 against a clean 1.1%, and
  0.1% on the iPhone. Flutter decodes and uploads images off the UI and
  raster threads, so a full-size decode costs memory, not frames.
- **A larger blur radius is not a larger cost under Impeller.** Impeller
  blurs a copy shrunk by about 4 / sigma
  (`GaussianBlurFilterContents::CalculateScale` in
  `impeller/entity/contents/filters/gaussian_blur_filter_contents.cc`),
  so `gpu_blur`'s cost comes from stacking blurs, not from their sigma.
- **A timer plant's cost locks to its phase.** `listener_decode` fires
  every 50 ms, which is 6 frames at 120 Hz, on a timer not tied to
  vsync. At M2's 1.5 frame budgets its job cost at most one frame,
  depending on where it landed, so the S24 lost 8.0 to 16.5% in 3 runs
  and the iPhone 0.2 to 1.4%. At 3 budgets a job costs 2 or 3 frames, about 33%
  or 50%, and stays on one within a run.
- **The performance overlay misses GPU-bound frames on the iPhone.** On
  the S24 every raster and GPU plant shows in the overlay's raster
  chart. On the iPhone only the two blurs do; `raster_clip`,
  `slow_raster` and `gpu_heavy` chart at 0.1 to 3.6 ms while they cost
  43 to 47% of frames. `FrameTiming`'s raster span starts before the
  raster thread waits for a free drawable (`shell/common/rasterizer.cc`,
  `RecordRasterStart` before `DrawToSurfaceUnsafe`;
  `impeller/renderer/backend/metal/surface_mtl.mm`,
  `WaitForNextDrawable`). The overlay's stopwatch starts only after it
  (`flow/compositor_context.cc`, `BeginFrame`). When the GPU falls
  behind, that wait is where the time goes, so Butterscope sees it and
  the overlay does not.

## Decision

1. **A plant visibly janks** when, in 3 of 3 runs on each phone, it
   costs its screen 10% to 60% of frames and at least 10 points more
   than the mean of that screen's clean build on the same phone. The
   clean build must repeat within about 1 point across its 3 runs. This
   replaces M4's "clean build under 1%". A clean screen's loss belongs to
   the phone and the test, so it is measured, not required to be near 0.
   What must hold is that nothing else adds to it, so it repeats.

2. **Plant costs are set per platform.** Each plant has one cost knob,
   with one value for Android and one for iOS
   (`apps/sample/lib/src/plants/plant_costs.dart`). With its own phone's
   values, every plant passes decision 1 on that phone. Decision 12 of
   0002 is closed.

3. **The rig keeps outside work out of the clean screens.** DESIGN 7.4
   and 7.5 gain three rules:
   - Each batch starts with one warm-up run that is not counted.
   - On Android, the app left by the previous run is stopped before each
     probe or overlay run.
   - On Android, a run starts only with power saving off, Stay awake on
     for the charger in use, at least 2 GB of memory free, no thermal
     throttling and the battery at 38 °C or less.

   iOS reports none of this to the Mac, so the iPhone's are kept by
   hand. The probes run with semantics off. DESIGN 7.2 keeps semantics
   open for M6, with M4's cost as evidence.

4. **Gallery's plant is `photo_tint`.** Each time a cell scrolls in, it
   averages every pixel of a large copy of its photo on the UI thread.
   `image_full_res` is dropped, because it cannot cost frames.

5. **The performance overlay is a manual check on Android only.** On the
   S24 the raster and GPU plants also show in the overlay. On the
   iPhone only the blurs do, so the others, like the UI-thread plants,
   are judged by frames lost. DESIGN section 4 records why.

## Consequences

- M8 measures `photo_tint`, not `image_full_res`, on Gallery. Its
  milestone text changes to match.
- A gate cannot assume a clean flow loses nothing. Each flow is compared
  with its own clean baseline on the same phone, as DESIGN section 9
  already requires.
- Costs tuned on one phone are not evidence for another. A new phone
  model needs its own values before its plants mean anything.
- M5's harness cost item has a first number: `enterText` costs 2 to
  3 ms of UI time per keystroke on the S24.
- On iOS, the overlay cannot confirm a GPU-bound regression that
  Butterscope reports. Butterscope's numbers come from `FrameTiming`,
  which includes the wait.
- The iPhone's `raster_clip` cost of 350 layers draws the feed cards at
  about (254/255)^350 ≈ 0.25 opacity, because 8-bit alpha caps each
  layer at 254/255. The plant is meant to cost frames, so this stays;
  a plant that keeps the cards opaque would need new costs.
