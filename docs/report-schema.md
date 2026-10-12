# Report schema v1

- Status: **proposed** in M7. Decision record 0008 freezes it at M7's gate.
- Code: [`packages/butterscope_report`](../packages/butterscope_report),
  shared by the phone side and `butterscope collect`.

## Lines

The phone prints a run's report to the device log as lines:

```
BSCOPE <runId> start
BSCOPE <runId> report <i>/<n> <crc> <json chunk>
BSCOPE <runId> frames <i>/<n> <crc> <json array of frames>
```

| Part | Meaning |
| --- | --- |
| `start` | Printed before the first test. A run with a `start` line and no `report` line stopped before it reported. |
| `report` | The report's JSON without its frames, cut into chunks of up to 800 characters. A cut never splits a surrogate pair. |
| `frames` | 20 frames a line, the last line holding the rest, each line a JSON array of its own. |
| `<i>/<n>` | The line's number, from 1, and how many lines of its kind there are: at most 100,000, and a writer refuses more. |
| `<crc>` | CRC-32 (IEEE, as zlib), in 8 lowercase hex digits, of the UTF-8 bytes of `<runId> <kind> <i>/<n> <payload>`: the line after the tag, without the CRC. A mangled number fails it too. |

Anything before `BSCOPE` on a log line is ignored, so logcat and syslog
prefixes may stay.

## What a reader reports

A reader never drops a line silently. For each run it names:

| Problem | When | What it costs |
| --- | --- | --- |
| `noReport` | Other lines of the run and no `report` line. | The report. |
| `missingLine` | Line `i` of `n` never arrived. | That line. |
| `badChecksum` | Line `i` arrived, does not match its CRC, and no whole copy arrived. Its `n` counts only when no line of its kind arrived whole. | That line. |
| `conflictingLine` | Two whole copies of line `i` differ. Copies that agree count once. | That line: neither copy is used. |
| `countMismatch` | Whole lines of one kind disagree on `n`. | The report, for `report` lines. `frames` lines are read up to the largest `n`. |
| `malformedLine` | The tag and run id are readable, the rest is not, or `n` is over 100,000. | That line. |
| `badJson` | Every report line arrived but the JSON does not decode, or a `frames` line is not an array. | The report, or that line. |

Losing any `report` line loses the report. Losing a `frames` line costs
only its frames, listed as a gap from the first frame it held: 20 frames,
or to the end of the run for the last line.

## Fields

The `report` lines carry one JSON object. `checkReport` in
`butterscope_report` checks a report against this section and names each
field that breaks it by its path, such as `parts[2].metrics.janky`. A
field this section does not list breaks it too.

| Field | Type | Meaning |
| --- | --- | --- |
| `schema` | int | `1`. |
| `runId` | int | The id on the run's lines, picked before the first test. |
| `identity` | object | What the run was measured on: below. |
| `valid` | bool | Whether every run guard passed. |
| `reasons` | list of reasons | The run guards that failed. |
| `frameCount` | int | The frames recorded. The `frames` lines hold them. |
| `flushTimedOut`, `flushMicros`, `callbackMicros` | bool, int, int | Whether the wait for the last frames' timings timed out, so frames at the end may be missing; how long it took; and the recorder's total callback time. |
| `rateReads` | list of `[afterSamples, micros, hertz]` | Each read of the declared rate. `micros` is null when not known, `hertz` when not finite. |
| `parts` | list of parts | Tests, spans and episodes in the order they ended. A test's episodes come just before it. |
| `issues` | list of issues | One per janky frame: below. |
| `activity` | list of `[kind, startFrame, startMicros, endFrame, endMicros]` | Input and animation, `kind` being `input` or `animation`. |
| `pages` | list of `[frame, micros, page, cuts]` | Each page shown. `page` is null when the route has no name; `cuts` is false for the app's first page. |

A reason is `[guard, at]` or `[guard, at, value]`. v1 freezes the guard
names: `buildMode`, `framePolicy`, `animations`, `textScale`, `locale`,
`thermal`, `lowPower`, `deviceState`, `declaredRate`,
`declaredRateChange`, `tooFewVsyncs` and `openAtTestEnd`
(`docs/DESIGN.md` section 7.2).

Times called `micros` come from the recorder's clock; frame times come
from the engine's. Match frames to parts by frame number.

v1 does not say whether each test passed: test_api 0.7.12, which Flutter
3.47.6 pins, gives a running test only its name (`TestHandle` in
`hooks.dart`).

### Identity

| Field | Type | Meaning |
| --- | --- | --- |
| `platform` | string | `android` or `ios`. |
| `model`, `osVersion`, `thermalAtStart` | string or null | Null when the phone's state could not be read. |
| `buildMode` | string | `debug`, `profile` or `release`. |
| `flutterVersion`, `engineRevision` | string or null | As the `flutter` tool defined them. |
| `appCommit` | string | `BUTTERSCOPE_APP_COMMIT`, or `unknown`. |
| `textScale` | number | At the run's start. |
| `locale` | string | At the run's start, such as `en-GB`. |

### Parts

| Field | Present | Meaning |
| --- | --- | --- |
| `kind` | always | `test`, `span` or `episode`. |
| `name` | always | The test's full name, the span's name, or `episode <n>`. |
| `test` | episodes | The full name of the test it is in. |
| `page` | episodes, when known | The page on top. |
| `startFrame`, `endFrame`, `startMicros`, `endMicros` | always | Its marks. |
| `declaredHz`, `declaredHzAtEnd` | always | The declared rate at its marks, null when not finite. |
| `frames` | always | How many frames it holds. |
| `metrics` | when its start's rate gives a budget, and an episode's rate did not move | The gate metrics: below. |
| `declaredRateChanged` | episodes whose rate moved | `true`, in place of metrics. |
| `diagnostics` | always | Below. |
| `valid`, `reasons` | spans | Its verdict and its own failed guards. |
| `semantics` | spans | `[atStart, atEnd]`: whether semantics was on. |

A part holds only the fields its kind is listed with.

`metrics` holds the metrics of decision record 0001 against the budget
`B` its start declared: `observedHz`, `rateSlicesJudged`,
`rateMismatches` (each `[second, gaps, observedHz]`), `hitchRatio`,
`hitchMs`, `renderingMs`, `missedVsyncs`, `missedVsyncMs`, `janky`,
`jankyRate`, `jankyRateUi`, `jankyRateRaster`, `jankyRateBoth`, `severe`,
`stalls`, `uiP90B`, `uiP99B`, `worstUiB`, `rasterP90B`, `rasterP99B` and
`worstRasterB`. Counts are ints; the rest are numbers, or null where there
is nothing to measure.

`diagnostics` holds `avgUiMs`, `avgBuildMs`, `avgRasterMs`,
`vsyncOverheadP90Ms`, `vsyncOverheadP99Ms`, `totalSpanP90Ms` and
`totalSpanP99Ms`, each a number or null, and `rasterCachePeak`
(`layers`, `layerBytes`, `pictures`, `pictureBytes`) when the cache held
anything.

### Issues

One per janky frame of each span or episode with metrics whose declared
rate did not move (`docs/DESIGN.md` section 6). A test's frames give none.

| Index | Field | Meaning |
| --- | --- | --- |
| 0 | `part` | The span's or episode's index in `parts`. |
| 1 | `frame` | The engine's frame number. |
| 2 | `offsetMs` | Its vsync after the part's first frame's vsync. |
| 3 | `thread` | `ui`, `raster` or `both`. |
| 4 | `overrunB` | The slower thread's time past `B`, in multiples of `B`. |
| 5 | `class` | `janky`, `severe` or `stall`. |

### Frames

Each `frames` line is a JSON array of frame rows, in the order the engine
reported them. A row is 10 ints, named by `frameFields` in
`butterscope_report`; `checkFrames` checks them.

| Index | Field | Index | Field |
| --- | --- | --- | --- |
| 0 | `frame` | 5 | `totalSpanUs` |
| 1 | `vsyncStartUs` | 6 | `cacheLayers` |
| 2 | `vsyncOverheadUs` | 7 | `cacheLayerBytes` |
| 3 | `buildUs` | 8 | `cachePictures` |
| 4 | `rasterUs` | 9 | `cachePictureBytes` |
