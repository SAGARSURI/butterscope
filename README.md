# Butterscope

Butterscope watches every frame Flutter renders while your integration tests
run. It reports jank per flow and flags a flow that gets slower than its
baseline, on Android and iOS.

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
[FVM](https://fvm.app). CI reads the same file. The repo is a
[pub workspace](https://dart.dev/tools/pub/workspaces) run with
[Melos](https://melos.invertase.dev), configured in the root `pubspec.yaml`.

Once per clone:

```sh
# Links the pinned Flutter at .fvm/flutter_sdk.
fvm use
# Once per machine. Puts `melos` in ~/.pub-cache/bin, which must be on PATH.
fvm dart pub global activate melos
# Resolves every package.
melos bootstrap
```

Day to day:

```sh
melos run check           # what CI checks: format, analyze, test, complexity
melos run check:changed   # the same, for the packages this branch changed
melos analyze             # every package, infos included
melos format              # every package; `dart format .` covers the repo
melos test                # every package with a test folder
melos run complexity      # the complexity tools over every lib/ folder
```

`check:changed` analyzes and tests the packages changed since the branch left
`origin/main` and every package that depends on them, using Melos's `--diff`
and `--include-dependents` filters. Uncommitted edits count, staged or not; a
new file counts once it is staged with `git add`. A change to a file every
package shares, such as the root `pubspec.yaml` or `analysis_options.yaml`,
checks every package instead. It then runs the complexity tools over every
package. CI always checks everything.

`melos run complexity` runs the tools in the
[`cognitive_complexity`](https://pub.dev/packages/cognitive_complexity)
package, pinned in [`tool/complexity.sh`](tool/complexity.sh). It fails on a
function that scores above 15, a file over 400 lines, or a helper with one
caller that should be inlined, and prints a plan for splitting a long file.
Claude Code runs it before each commit it makes. See
[`docs/review-rules.md`](docs/review-rules.md).

- Melos runs on the SDK at `.fvm/flutter_sdk`, so every command uses the
  pinned Flutter. The global Melos hands over to the version pinned in the
  root `pubspec.yaml`.
- Versions every package shares (the Dart and Flutter constraints,
  `very_good_analysis`) are set once, under `melos: command: bootstrap:` in
  the root `pubspec.yaml`. Change them there and run `melos bootstrap`, which
  writes them into each package. CI fails if a package disagrees.
- `.fvmrc` turns off FVM's own Melos integration (`updateMelosSettings`): it
  writes the SDK path to a `melos.yaml`, which Melos 8 no longer reads.
