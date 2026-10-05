# butterscope_sample

A domain-neutral app used to prove Butterscope. Each screen stresses one
cause of dropped frames, and its integration tests are written the way any
team writes functional tests.

- M2 adds a calibration screen: a constant animation with a predictable frame
  count.
- M4 adds the six sample screens, their integration tests and the planted
  regressions.

## Sample screens

The app is a catalogue: 5,000 items generated from a fixed seed, so every
run sees the same data. It makes no network calls; any real HTTP request
throws.

| Screen | What it does |
| --- | --- |
| Feed | Scrolling list of item cards; tapping one opens Detail |
| Search | Filters the items by title or tag as you type |
| Detail | One item: a large picture under a frosted title panel, its facts and related items |

M4's other three screens and the plants for every screen are still to
come.

## Calibration screen and plants

The calibration screen has two phases: an animated phase, where a box
turns and slides without pause, and a still phase, where nothing on screen
changes. A test sets the phase; tapping the screen toggles it by hand.

The calibration screen has its own route. A plant is switched on at build
time, one at a time, and runs only in the animated phase:

```sh
fvm flutter run --profile --route=/calibration \
  --dart-define=BUTTERSCOPE_PLANT=<name>
```

| Name | What it does | Where it should show |
| --- | --- | --- |
| `listener_decode` | A stream listener busy for 1.5 frame budgets, every 50 ms | UI time |
| `postframe_decode` | The same work in a post-frame callback, every frame | Missed vsyncs |
| `slow_raster` | 40 layers of opacity and save-layer clips | Raster time |
| `backdrop_blur` | 6 full-screen backdrop blurs | Raster time |
| `gpu_heavy` | A full-screen fragment shader with a 500-step loop per pixel | GPU work, which showed as raster time on the S24 because the raster thread waits on the GPU |

The costs are tuned so each plant visibly drops frames on the Galaxy S24
in profile mode. On the iPhone 17 Pro, `slow_raster` and `backdrop_blur`
drop none and `gpu_heavy` drops about 3 frames in 4
([M2 measurements](../../docs/measurements/m2.md)). **(open, M4: tuned per
platform.)**

## Platform folders

The Android and iOS folders are generated with the pinned Flutter version
rather than written by hand. Run this once on a machine with FVM, then commit
the result:

```sh
tool/bootstrap_sample.sh
```
