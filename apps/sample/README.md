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
| Activity | Live save counts for 40 items, bumped by a fake feed every 100 ms |
| Inbox | Messages from a fake socket, sent as JSON every 500 ms and decoded on a background isolate |
| Gallery | A grid of photos; tapping one opens it full screen |

### Screen plants

Each screen has one planted mistake that makes it slow, never wrong. A plant
is switched on at build time, one at a time:

```sh
fvm flutter run --profile --dart-define=BUTTERSCOPE_PLANT=<name>
```

| Name | Screen | What it does | Where it should show |
| --- | --- | --- | --- |
| `raster_clip` | Feed | Wraps every card in layers of opacity and save-layer clips | Raster time |
| `ui_busy` | Search | Scores every item with an edit distance on every keystroke, on the UI thread, and lists the best matches first | UI time |
| `rebuild_all` | Activity | Rebuilds and lays out every row, each with a bar of many boxes, on every bump | UI time |
| `sync_decode` | Inbox | Decodes each batch on the UI thread instead of a background isolate | UI time |
| `image_full_res` | Gallery | Decodes every grid photo at full size instead of the cell's size | UI and raster time |
| `gpu_blur` | Detail | A large backdrop blur over the header picture | Raster time |

Inbox messages carry header entries that the screen never shows, so each
batch takes real work to decode; the clean build decodes the same messages
on a background isolate.

`--dart-define=BUTTERSCOPE_OVERLAY=on` shows Flutter's performance overlay,
for screenshots of where a plant's cost lands.

### Tests

Each screen has widget tests under `test/`, which CI runs, and integration
tests under `integration_test/`, one file per screen, written the way an
app team writes functional tests. `integration_test/app_test.dart` runs all
six. This runs them on a phone in profile mode, once with no plant and once
with each screen plant, and prints a pass or fail line per run:

```sh
tool/m4/run_tests.sh <device-id>
```

Name plants after the device to run only those; `clean` is the build with
no plant. M2's calibration plants are left out unless named, because no
ordinary test opens the calibration screen. Logs go to
`build/m4_tests/<device-id>/`.

### Probe

`integration_test/m4_probe_test.dart` measures how much each plant costs
its screen. It opens each screen in turn and records one 5 s window with
M2's recorder while a scripted action runs: flings on Feed, Gallery and
Detail, typing on Search, and waiting on Activity and Inbox, whose streams
do the work. Frames lost are the window's length times the screen's rate,
less the frames recorded. A plant passes when its screen loses 10% to 60%
of its frames in 3 of 3 runs on each phone, with the clean build under 1%.

```sh
tool/m4/run_probe.sh <device-id> clean raster_clip raster_clip=12
RUNS=3 tool/m4/run_probe.sh <device-id> clean ui_busy
```

A build is `clean`, a plant, or a plant and a cost: `raster_clip=12` sets
the plant's knob with `--dart-define=BUTTERSCOPE_COST`, so each candidate
value is a build rather than an edit. The script prints the frames each
screen lost, marks the planted screen, and stops when a clean screen drew
under 114 Hz, since a capped screen reads as a plant losing frames.
M2's plants run M2's calibration probe instead, where the animated window
is the planted one; `calibration` runs it with no plant. Transcripts and
summaries go to `build/m4_probe/<device-id>/`.

The six gallery photos in `assets/photos` are 4032 x 3024 (12 MP)
landscapes painted from fixed seeds by
[`tool/m4/make_photos.dart`](tool/m4/make_photos.dart). Running it again
writes the same files.

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

The table gives the Galaxy S24's costs. Each plant's cost has a value per
platform in [`lib/src/plants/plant_costs.dart`](lib/src/plants/plant_costs.dart),
because the same work costs the two phones very different amounts: with
the S24's costs, `slow_raster` and `backdrop_blur` dropped no frames on the
iPhone 17 Pro and `gpu_heavy` dropped about 3 in 4
([M2 measurements](../../docs/measurements/m2.md)). The iPhone's values and
every screen plant's values are first guesses. **(open, M4: set by the
probe runs.)**

## Platform folders

The Android and iOS folders are generated with the pinned Flutter version
rather than written by hand. Run this once on a machine with FVM, then commit
the result:

```sh
tool/bootstrap_sample.sh
```
