# Butterscope

Butterscope watches every frame Flutter renders while your integration tests
run. It reports jank per flow and fails a pull request when a flow gets
slower than its baseline.

It is a passive observer. Your tests drive the app as they already do; one
line in the test file attaches Butterscope. It scripts no interactions and
needs no app-specific code.

> Status: proof of concept, milestone **M0** (repository and design record).
> Nothing here is usable yet.

## How it decides

- **Budget per frame:** `B = 1000 / refresh rate` ms, read from the device for
  every run. A frame over `B` on the UI or raster thread is janky.
- **Headline metric:** hitch ratio, the milliseconds of lateness per second of
  a flow.
- **Verdict:** `PASS`, `FAIL` or `INVALID` for each named flow. `INVALID`
  means the run could not be trusted (a debug build, animations off, a
  throttled phone); it never counts against your code.

The full set of rules is in [docs/DESIGN.md](docs/DESIGN.md).

## Layout

| Path | What it is |
| --- | --- |
| `packages/butterscope` | Runtime core: frame recorder, metrics, report. Depends on Flutter only. |
| `packages/butterscope_test` | The one-line attach for integration tests. A dev dependency. |
| `tools/butterscope_cli` | Host CLI: `collect` results from a device or farm log, `judge` them against a baseline. |
| `apps/sample` | A domain-neutral sample app with ordinary integration tests, used to prove the framework. |
| `docs/DESIGN.md` | The agreed design. Changes go through `docs/decisions/`. |

## Toolchain

Flutter is pinned in [`.fvmrc`](.fvmrc) and managed with
[FVM](https://fvm.app). CI reads the same file.

```sh
fvm install
fvm flutter pub get
fvm flutter analyze
```

The repo is a [pub workspace](https://dart.dev/tools/pub/workspaces): one
`pub get` at the root resolves every package.
