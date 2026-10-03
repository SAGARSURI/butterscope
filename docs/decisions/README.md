# Decision records

[`docs/DESIGN.md`](../DESIGN.md) is the contract every pull request is reviewed
against. Changing anything it says needs a decision record here, in the same
pull request as the change, approved by the project owner.

Name each file `NNNN-short-title.md`, numbered in order, and never edit an
accepted record: supersede it with a new one.

## Template

```markdown
# NNNN: Title

- Status: proposed | accepted | superseded by NNNN
- Date: YYYY-MM-DD
- Milestone: Mx

## Context

What we learned or what changed, with the evidence (run data, docs, links).

## Decision

What DESIGN.md now says, quoted or summarised.

## Consequences

What this makes easier, harder, or invalid (baselines, thresholds, APIs).
```
