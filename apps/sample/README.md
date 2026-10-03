# butterscope_sample

A domain-neutral app used to prove Butterscope. Each screen stresses one
cause of dropped frames, and its integration tests are written the way any
team writes functional tests.

- M2 adds a calibration screen: a constant animation with a predictable frame
  count.
- M4 adds the six sample screens, their integration tests and the planted
  regressions.

## Platform folders

The Android and iOS folders are generated with the pinned Flutter version
rather than written by hand. Run this once on a machine with FVM, then commit
the result:

```sh
tool/bootstrap_sample.sh
```
