# Butterscope

Butterscope watches every frame Flutter renders while your integration tests
run. It reports jank per flow and flags a flow that gets slower than its
baseline, on Android and iOS.

It is a passive observer. Your tests drive the app as they already do; one
line in the test file attaches Butterscope. It scripts no interactions and
needs no app-specific code.

> Status: proof of concept. M1 (metrics engine), M2 (frame recorder) and M4
> (sample app, [0004](docs/decisions/0004-m4-sample-findings.md)) are done.
> M3's farm check moved to M10 and its rate mismatch to M6
> ([0003](docs/decisions/0003-m3-scope-moves.md)); M5 is next. Nothing gates
> a build yet.

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
melos run check           # CI's checks after bootstrap; run before pushing
melos analyze             # every package, infos included
melos format              # every package; `dart format .` covers the repo
melos test                # every package with a test folder
melos run complexity      # complex functions, long files, shallow helpers
melos run duplication     # code that appears twice under lib/
melos run dead-code       # declarations nothing uses
```

`melos run check` formats the repository (fixing what it finds), analyzes
it, runs every package's tests and then the complexity, duplication and
dead-code checks. Every check runs even when an earlier one fails, and the
last line names the ones that failed. Claude Code runs it before each commit
it makes, and skips it when only Markdown changed.

The last three checks run tools from
[analytica.dart](https://github.com/kevmoo/analytica.dart):
`cognitive_complexity`, `dedupe` and `undead`. They are dev dependencies of
the root `pubspec.yaml`, which pins their versions, and `pubspec.lock` pins
everything they depend on. Dependabot proposes new releases of
`cognitive_complexity` and `dedupe`; `undead` is pinned to a commit until a
release fixes it, and moving it back to a release is done by hand.
[`tool/analytica.sh`](tool/analytica.sh) runs them and sets their limits.
Each has an agent skill in `.claude/skills`. See
[`docs/review-rules.md`](docs/review-rules.md) for what fails each check.

- Melos runs on the SDK at `.fvm/flutter_sdk`, so every command uses the
  pinned Flutter. The global Melos hands over to the version pinned in the
  root `pubspec.yaml`.
- Versions every package shares (the Dart and Flutter constraints,
  `very_good_analysis`) are set once, under `melos: command: bootstrap:` in
  the root `pubspec.yaml`. Change them there and run `melos bootstrap`, which
  writes them into each package. CI fails if a package disagrees.
- `.fvmrc` turns off FVM's own Melos integration (`updateMelosSettings`): it
  writes the SDK path to a `melos.yaml`, which Melos 8 no longer reads.
