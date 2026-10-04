# Review rules

Greptile reviews every pull request. [`.greptile/config.json`](../.greptile/config.json)
gives it rules taken from [DCM's code metrics](https://dcm.dev/docs/metrics/),
at DCM's default thresholds, so functions, classes and files stay small
enough to read, test and change safely. A rule only reports code that the
pull request adds or changes, and names the measured value and the
threshold.

## What is checked

| Rule id | DCM metric | Reported when | Severity |
| --- | --- | --- | --- |
| `dcm-cyclomatic-complexity` | [cyclomatic-complexity](https://dcm.dev/docs/metrics/function/cyclomatic-complexity/) | over 15 | high |
| `dcm-maximum-nesting-level` | [maximum-nesting-level](https://dcm.dev/docs/metrics/function/maximum-nesting-level/) | over 5 | medium |
| `dcm-source-lines-of-code` | [source-lines-of-code](https://dcm.dev/docs/metrics/function/source-lines-of-code/) | over 60 | medium |
| `dcm-lines-of-code` | [lines-of-code](https://dcm.dev/docs/metrics/function/lines-of-code/) | over 100 | low |
| `dcm-number-of-parameters` | [number-of-parameters](https://dcm.dev/docs/metrics/function/number-of-parameters/) | over 6 | medium |
| `dcm-widgets-nesting-level` | [widgets-nesting-level](https://dcm.dev/docs/metrics/function/widgets-nesting-level/) | over 8 | medium |
| `dcm-number-of-used-widgets` | [number-of-used-widgets](https://dcm.dev/docs/metrics/function/number-of-used-widgets/) | over 20 | medium |
| `dcm-number-of-methods` | [number-of-methods](https://dcm.dev/docs/metrics/class/number-of-methods/) | over 10 | medium |
| `dcm-weighted-methods-per-class` | [weighted-methods-per-class](https://dcm.dev/docs/metrics/class/weighted-methods-per-class/) | over 45 | medium |
| `dcm-depth-of-inheritance-tree` | [depth-of-inheritance-tree](https://dcm.dev/docs/metrics/class/depth-of-inheritance-tree/) | over 5 | medium |
| `dcm-number-of-implemented-interfaces` | [number-of-implemented-interfaces](https://dcm.dev/docs/metrics/class/number-of-implemented-interfaces/) | over 3 | medium |
| `dcm-number-of-added-methods` | [number-of-added-methods](https://dcm.dev/docs/metrics/class/number-of-added-methods/) | over 10 | low |
| `dcm-number-of-overridden-methods` | [number-of-overridden-methods](https://dcm.dev/docs/metrics/class/number-of-overridden-methods/) | over 10 | low |
| `dcm-number-of-imports` | [number-of-imports](https://dcm.dev/docs/metrics/file/number-of-imports/) | over 15 | low |
| `dcm-number-of-external-imports` | [number-of-external-imports](https://dcm.dev/docs/metrics/file/number-of-external-imports/) | over 6 | medium |
| `dcm-technical-debt` | [technical-debt](https://dcm.dev/docs/metrics/file/technical-debt/) | any added | medium |

**Scope.** Size and complexity rules apply to code under `lib/`. Test files
are left out: a test file's `main` holds all of its groups, so it is long by
design. The technical-debt rule applies to every Dart file, tests included:
it reports each added TODO, `// ignore:`, `// ignore_for_file:`,
`// cognitive_complexity:ignore` or `// undead:ignore` comment (file-wide
forms included), `as dynamic` cast, `@Deprecated` annotation and
`// @dart=` comment.

**One project choice.** Constructors are exempt from the parameter count.
DCM's definition names functions and methods, and an immutable value class
takes one named parameter per field, so its constructor grows with its
fields.

## Computed in CI

The rules above are judged by Greptile reading the diff. These are computed
instead, from the Dart syntax tree, by tools from
[analytica.dart](https://github.com/kevmoo/analytica.dart):
[`cognitive_complexity`](https://pub.dev/packages/cognitive_complexity),
[`dedupe`](https://pub.dev/packages/dedupe) and
[`undead`](https://pub.dev/packages/undead).
They are dev dependencies of the root `pubspec.yaml`, which pins their
versions; `pubspec.lock` pins everything they depend on.
[`tool/analytica.sh`](../tool/analytica.sh) runs them and sets their limits.

| Check | Tool | Fails when | Limit's source |
| --- | --- | --- | --- |
| Cognitive complexity | `cognitive_complexity` | a function scores above 15 | [SonarSource's whitepaper](https://www.sonarsource.com/docs/CognitiveComplexity.pdf) and the tool's default |
| File length | `cognitive_complexity --max-file-lines` | a file has more than 400 lines | the `dart-cognitive-complexity` skill |
| Shallow helpers | `shallow --fail-on-safe-inline` | a helper is `SAFE_INLINE` (below) | the cognitive complexity limit |
| Split plan | `file_split` | never; it prints a plan for each file over 400 lines | |
| Duplicated code | `dedupe --fail-threshold=0` | a block appears more than once under `lib/` | the tool's minimum block: 40 tokens and 4 lines |
| Dead code | `undead --fail-on-undead` | a declaration has no use outside tests | any finding |

- **Cognitive complexity** charges extra for nesting, and flat `switch` arms
  cost nothing, so it tracks how hard a function is to read. The cyclomatic
  rule above counts paths, which sets how many tests a function needs.
- **File length** counts every line, comments and blank lines included, plus
  the empty line after a final newline: `wc -l` shows one fewer. A generated
  file, such as `*.g.dart`, is left out.
- **Shallow helpers** are functions and methods outside the public API, not
  overrides, with exactly one caller and none in tests, that are also tiny
  (at most 6 body lines and a score of 2 or less), take 5 parameters or more,
  take 3 or more with a signature about as long as the body, or are a short
  top-level or static function called from another file. `SAFE_INLINE` means
  pasting the helper into its caller keeps the caller at 15 or below, so the
  helper adds a name and a jump without hiding any complexity. Inline it. A
  helper whose caller would go over 15 is reported but passes.
- **A split plan** groups a long file's declarations by how they depend on
  each other. For each group it suggests a file name, the imports it needs
  and the private names that would have to become public.
- **Duplicated code** compares the token sequences of every `lib/` folder
  together, so a copy in another package counts. Comments are ignored and
  string and number literals count as equal, so a copy with different
  messages or constants still matches; renamed variables do not. Near-copies
  with a few lines added or removed match too. Tests are not scanned.
- **Dead code** follows references from each package's roots. A library's
  roots are what its files outside `lib/src/` export, plus its tests and the
  other workspace packages that use it. A package with `bin/` or
  `lib/main.dart` is an app, and its roots are those entry points. A
  declaration nothing reaches is dead, and so is one only tests reach.

CI annotates each failure where it starts. The run's summary page has each
function's score and each tool's report. Locally, `melos run complexity`,
`melos run duplication` and `melos run dead-code` run the same checks, and
`melos run check` includes them. Claude Code runs `melos run check` before
each commit it makes and blocks the commit when it fails (see
[`.claude/settings.json`](../.claude/settings.json)).

**Fixing a finding.** Each tool has an agent skill in
[`.claude/skills`](../.claude/skills):
[`dart-cognitive-complexity`](../.claude/skills/dart-cognitive-complexity/SKILL.md)
has the refactoring patterns,
[`dart-dedupe`](../.claude/skills/dart-dedupe/SKILL.md) how to extract a
shared helper, and [`dart-undead`](../.claude/skills/dart-undead/SKILL.md) how
to delete dead code safely. To extract part of a function, the
`cognitive_complexity` package's `data_flow` tool lists the inputs, mutations
and outputs of a line range, and the score the function would have after
the extraction:
`dart run cognitive_complexity:data_flow <file>:<start>-<end>`. It needs a line
range, so it does not run in CI.

**No suppressions.** A finding is fixed in the code, not marked with the
`// cognitive_complexity:ignore` or `// undead:ignore` comments (or their
`_for_file` forms) that the tools honour. When a finding cannot be fixed,
for example duplication that must stay for type safety, the owner decides.

## Not checked, and why

- **Halstead volume and maintainability index.** Both are computed from
  every operator and operand token, and the index combines Halstead volume,
  cyclomatic complexity and source lines with logarithms. A reviewer reading
  a diff cannot compute them reliably, and Greptile asks for rules it can
  measure.
- **Coupling between object classes and response for a class.** DCM's pages
  do not say which types or calls count (core types such as `int` and
  `List`, for example), so the counts would vary from one review to the next.
- **Tight class cohesion and weight of a class.** Both flag immutable value
  types, which expose data by design. DCM exempts widgets from both, but not
  value classes.

## Changing a rule

Change the rule in `.greptile/config.json` and its row here in the same pull
request. Greptile applies changes to `.greptile/` from the next pull request
it reviews. The computed checks' limits live in `tool/analytica.sh`; change
them there and in the table above. The tools' versions live in the root
`pubspec.yaml`, and Dependabot opens a pull request for each new release, so
its CI run shows what the new version reports. undead is the exception while
it is pinned to a git commit: moving it back to a release is done by hand.
