# 0008: Report schema v1 and the log channel

- Status: accepted
- Date: 2026-10-18
- Milestone: M7

## Context

M7 made results leave the phone on their own and land on the host as
checked JSON. Until M7 the report was schema 0: JSON in numbered
`BSCOPE-REPORT` lines, with no frames, no issue list and no checksum
(0005). M7 built:

- **`butterscope_report`** (#40), a pure Dart package that the phone and
  the host share: the line format, a CRC-32 on each line, and a reader
  that names every line it lost or could not trust.
- **Schema v1 on the phone** (#41): a `start` line before the first test,
  the report's JSON in `report` lines, and every frame of the run in
  `frames` lines, 20 to a line. The report gained the platform, every
  read of the declared rate, and DESIGN 6's issue list.
- **`butterscope collect`** (#42), which reads device logs or stdin and
  writes one `<runId>.json` per run, with the frames lost listed.
- **A runner** (#43), `apps/sample/tool/m7/run_tests.sh`, that reads the
  device log while each run goes and ends with `collect`.

The schema is in [`docs/report-schema.md`](../report-schema.md). The
runs are in [`docs/measurements/m7.md`](../measurements/m7.md): 27
counted runs on the same Galaxy S24 and iPhone 17 Pro as M2 to M6, with
Flutter 3.47.6, in profile and release, from 2026-10-13 to 2026-10-16.

What the runs showed:

- **Every line came off both phones whole**, in profile and release,
  once the three fixes below were in. That includes M5's harness test,
  about 12,800 frames and 700 lines a run.
- **Android drops a burst of lines.** In the first S24 run a run's 219
  lines were printed within 6 ms, and every line after about the 170th
  was lost, from logcat and from the `flutter drive` transcript alike:
  up to 800 frames. Pausing 20 ms after every 16 lines fixed it. It adds
  about 0.3 s to an app run and 0.8 s to a harness run, after the last
  test, so it costs no measured frame.
- **`idevicesyslog -p Runner` caught nothing.** idevicesyslog 1.4.0
  matches `-p` only against processes running when it starts, and the
  app always starts after it. Matching the text, `-m 'BSCOPE '`, caught
  every line. 0002 decision 11 named `-p`.
- **The iPhone's system log strips whitespace at a line's end.** In one
  release run, report line 12 of 78 was cut after `"Feed scrolls "`. It
  lost its space, failed its CRC, and `collect` wrote no file, as it
  should. No chunk now ends in whitespace but the last.
- **An iOS release run's lines reach only the system log.** The
  `flutter drive` transcript holds none of them. In profile the system
  log held every line the transcript did.
- **800-character report lines arrive whole in iOS release.** The longest
  line in an iOS release log was 1,067 characters, a harness `frames`
  line. The chunk length stays 800.
- **A forced loss is named, never hidden.** With the S24's log buffer
  shrunk to 64 KB and read after the run, the start line and report lines
  1 to 77 were gone. `collect` named each, wrote no file and exited 1.
- **Two void runs carried every line.** Two iPhone harness runs were void
  by the thermal guard (0007). Their lines arrived whole, so they count
  as passes here: M7 tests the channel, and validity is M6's guard.

## Decision

1. **Schema v1 is frozen** as [`docs/report-schema.md`](../report-schema.md)
   gives it: the three line kinds, the CRC, the fields, the guard names
   of 0007 decision 3, and the issue and frame rows. Any change to a line,
   a field or a name is schema 2, made through a new record. A reader
   rejects a field the schema does not list, so even an added field is a
   new version.
2. **Frames are packed 20 to a line** (0002 decision 11's open item).
   Losing a `frames` line costs only the frames it held; losing a
   `report` line costs the report.
3. **The report holds every frame of the run**, uncompressed. The
   harness's 700 lines a run arrived whole on both phones, so nothing
   needs to shrink yet.
4. **The device log is the only channel**, on both phones, in profile and
   release. On Android `adb logcat` is read from before the launch to the
   run's last line. On iOS `idevicesyslog --no-colors -m 'BSCOPE '` is
   read the same way; a profile run also keeps the `flutter drive`
   transcript, and `collect` counts a line found in both once. This
   replaces 0002 decision 11's `-p Runner`.
5. **The phone paces its lines**: a 20 ms pause after every 16, on both
   platforms. The iPhone was never run without it; one rule keeps the
   two phones' runs alike.
6. **No report chunk but the last ends in whitespace.** A cut moves back
   to keep it so; it also never splits a surrogate pair. Report chunks
   are 800 characters, longer only where no cut can satisfy both.
7. **Release runs launch as in M2**: `flutter run --release
   --no-resident` on Android, and `flutter build ios` then `devicectl` on
   iOS, since `flutter drive` refuses release builds
   (`flutter_tools/lib/src/drive/drive_service.dart`, line 161). The
   runner waits for the run's `start` line, as a release app has no VM
   service.
8. **A run passes when it arrives whole**, as `collect` judges it: a
   start line, every line with its CRC, a v1 report and as many frames
   as `frameCount`, with its file written. That holds whether the run is
   valid or void.

## Consequences

- M8 and M9 read `<runId>.json` files, not logs. Their numbers come from
  frames that are known to be whole.
- A lost report line loses the whole report: parts, metrics and issues.
  Only the frames survive. Each sample run printed about 80 report
  lines, and none was lost outside the forced loss. **(open, M10:
  whether the farm's device log keeps every line.)**
- The farm runs no host script (DESIGN 8), so `collect` must read
  LambdaTest's saved log as it reads a local one. Its prefixes do not
  matter: anything before `BSCOPE` is ignored.
- The runners in `tool/m5` and `tool/m6` read schema 0 lines, which the
  phone no longer prints. They stay, to show how M5's and M6's data was
  taken, and run at those milestones' commits. M8 runs `tool/m7`.
- A test's pass or fail is not in v1: test_api 0.7.12 gives a running
  test only its name. Adding it later is schema 2.
- The pause adds under a second to a run. A run with many more frames
  would add more: about 1.25 ms a line.
