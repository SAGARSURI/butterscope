# butterscope_report

The lines a Butterscope report is printed as on the phone, and how the host
reads them back. Pure Dart, so the phone side (`butterscope_test`) and the
host CLI (`butterscope_cli`) share one copy and cannot drift.

```
BSCOPE <runId> start
BSCOPE <runId> report <i>/<n> <crc> <json chunk>
BSCOPE <runId> frames <i>/<n> <crc> <json array of up to 20 frames>
```

`<crc>` is the CRC-32 of the line's payload, in 8 hex digits. A reader
names every line that is missing, mangled or contradicted by another; it
never drops one silently. The format is proposed until M7's gate freezes it
(`docs/DESIGN.md` section 8).
