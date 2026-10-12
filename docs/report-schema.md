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
| `<i>/<n>` | The line's number, from 1, and how many lines of its kind there are: at most 100,000. |
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

PR 2 of M7 adds the report's fields here.
