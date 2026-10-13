# butterscope_report

The lines a Butterscope report is printed as on the phone, how the host
reads them back, and the report's schema. Pure Dart, so the phone side
(`butterscope_test`) and the host CLI (`butterscope_cli`) share one copy
and cannot drift.

```
BSCOPE <runId> start
BSCOPE <runId> report <i>/<n> <crc> <json chunk>
BSCOPE <runId> frames <i>/<n> <crc> <json array of up to 20 frames>
```

`<crc>` is the CRC-32 of `<runId> <kind> <i>/<n> <payload>`, in 8 hex
digits. A reader names every line that is missing, mangled or contradicted
by another; it never drops one silently.

`checkReport` and `checkFrames` check what the lines carry against schema
v1 and name each field that breaks it. The lines and the schema are in
[`docs/report-schema.md`](../../docs/report-schema.md), proposed until
M7's gate freezes them.
