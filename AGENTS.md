# AGENTS.md

Butterscope records every frame a Flutter app renders while its existing
integration tests run, and gates jank regressions per flow. Android and iOS
only.

## Read first, when it applies

- **Any change to behaviour:** [`docs/DESIGN.md`](docs/DESIGN.md) is the
  contract. Read the section you touch. Changing what it says needs a
  decision record in [`docs/decisions/`](docs/decisions/README.md), in the
  same pull request.
- **Metrics, budgets or frame classes:** decision record
  [0001](docs/decisions/0001-metric-definitions.md) defines every number a
  baseline holds.
- **Starting work:** the current milestone's "Done when" list on
  [GitHub](https://github.com/SAGARSURI/butterscope/milestones) is the scope.
- **Writing code under `lib/`:** [`docs/review-rules.md`](docs/review-rules.md)
  lists the size and complexity limits Greptile reviews against.
- **Setup and commands:** the Toolchain section of [`README.md`](README.md).

## How work moves

- Plan first. The owner (@SAGARSURI) approves a milestone's plan before its
  code is written, and signs off its gate before the next milestone starts.
- An assumption not yet verified is marked **(open, Mx)** in the docs, naming
  the earliest milestone that can measure it.
- The owner runs everything on devices (Galaxy S24, iPhone 17 Pro, LambdaTest).
  For a device step, hand over the exact commands and the output to bring
  back.

## Ground every claim

- Flutter is pinned in `.fvmrc`. Base each claim about Flutter, Dart or engine
  behaviour on that version's source or API docs, use only APIs that exist
  there, and cite the source file where a decision rests on it, as decision
  record 0001 does.
- Treat other tools the same way (Melos, Greptile, DCM, GitHub Actions): check
  the docs or source of the version in use.

## Public and domain-neutral

The repository is public. The sample app, examples, docs and commit messages
stay generic (a live board, a history feed, an amount form). Keep product,
company and client names out of all of them.

## Code

- Dart 3.13 style: constructors use `new` (`const new(...)`,
  `const new _(...)`, `factory name(...)`); value types are immutable
  `final class`es. `very_good_analysis` and `dart format` settle the rest.
- The `butterscope` core depends on Flutter only, so it can ship inside an
  app later.
- Each test pins one behaviour and fails when that behaviour breaks. Derive
  expected numbers by hand from the decision record, and show the arithmetic
  in a comment when it is not obvious.
- Docs use plain English and short sentences. Prose wraps at 80 columns;
  tables and links may run longer.

## Checks

- `melos run check` runs what CI runs: format, analyze with `--fatal-infos`,
  test. `melos run check:changed` is the quicker loop.
- CI fails when `pub get` or `melos bootstrap` changes any file, so commit
  `pubspec.lock` with the pubspec change. Versions every package shares are
  edited only under `melos: command: bootstrap:` in the root `pubspec.yaml`.
- CI reports each failure as an annotation on the failing line. Where Flutter
  cannot run (a sandbox without the SDK), push the branch and read them.

## Git

- Branches: `m<N>/<topic>` for milestone work; `ci/`, `docs/`, `chore/` for
  the rest. Pull requests target `main`, each small enough to review in one
  sitting.
- Commit subject: `<area>: <imperative summary>`, where the area is `M<N>`,
  `ci`, `docs`, `test`, `chore` or `fix`. The body says why.
