---
description: Run a tiered code review over the current diff
argument-hint: "[optional: scope or PR ref]"
---

# /review — tiered code review

Run a self-correction + review pass over the current change set, honoring
`CLAUDE.base.md §3 Self-Correction` and §5 quality gates.

## Scope

$ARGUMENTS  (default: the current uncommitted diff / current branch)

## Protocol

1. **Self-correct first (§3):** generate → critically evaluate (what's wrong?
   what's missing?) → run all checks → score confidence 0–1. If < 0.85, fix
   before presenting the review.
2. **Review the diff** for correctness bugs, then reuse/simplification/efficiency.
3. **Gate it (§5):** lint 0, types 0, tests 100% pass, coverage > 80%, security
   0 high/critical, secrets 0 leaks.
4. Respect §7 boundaries — flag clinical/compliance/privacy/production-data
   changes as `[REQUIRES HUMAN REVIEW]`.

For a deeper, multi-persona pass prefer the `ce-code-review` skill (or `/code-review`).
This command is the always-available baseline review every repo can run.
