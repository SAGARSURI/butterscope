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

## Code

- Resolve every analyzer and lint finding by changing the code. Suppressions
  are off limits: `// ignore:`, `// ignore_for_file:`, and turning a rule off
  in `analysis_options.yaml`. When a finding cannot be resolved, stop and
  report it to the owner: the finding, why the code cannot satisfy it, and
  the next steps you propose.
- Each test pins one behaviour and fails when that behaviour breaks. Derive
  expected numbers by hand from the decision record, and show the arithmetic
  in a comment when it is not obvious.
- Docs use plain English and short sentences. Prose wraps at 80 columns;
  tables and links may run longer.

## Workflow

1. After changing a dependency or plugin, and after bringing in changes from
   `main`, run `melos bs` (bootstrap).
2. Before every push, run `melos run check:changed` and push only when it
   passes. An agent working where Flutter is not installed (a cloud
   sandbox, for example) cannot run it: say so in the pull request and let
   CI run the checks.

- `melos run check` runs formatting, analysis and tests for every package.
  CI also runs `melos bootstrap` and fails if that changes any file, so
  commit `pubspec.lock` with the pubspec change. Versions every package
  shares are edited only under `melos: command: bootstrap:` in the root
  `pubspec.yaml`.

## Git

- The repository is public: keep product, company and client names out of
  code, docs and commit messages.
- Branches: `m<N>/<topic>` for milestone work; `ci/`, `docs/`, `chore/` for
  the rest. Pull requests target `main`, each small enough to review in one
  sitting.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):
  `<type>(<scope>): <imperative summary>`. Types: `feat`, `fix`, `perf`,
  `refactor`, `test`, `docs`, `build`, `ci`, `chore`. The scope is the
  package when the change sits in one (`butterscope`, `butterscope_test`,
  `butterscope_cli`, `butterscope_sample`). A breaking change adds `!` after
  the scope and a `BREAKING CHANGE:` footer. The body says why.
