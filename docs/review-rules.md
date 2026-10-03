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
it reports each added TODO, `// ignore:` or `// ignore_for_file:` comment,
`as dynamic` cast, `@Deprecated` annotation and `// @dart=` comment.

**One project choice.** Constructors are exempt from the parameter count.
DCM's definition names functions and methods, and an immutable value class
takes one named parameter per field, so its constructor grows with its
fields.

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
it reviews.
