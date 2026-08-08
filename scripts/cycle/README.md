# Autonomous cycle harness

Deterministic tooling for **state-based, multi-cycle-per-day autonomous
engineering**. It replaces the part of the loop that should never be left to
model judgement — what the world looks like, and whether a merge is permitted —
with scripts that are testable, fail-closed, and cheap to re-run.

The judgement parts (implementing, reviewing a diff) stay with the agent. The
mechanical parts live here.

## Why this exists

Measured on 2026-08-07, before any of this landed:

| Observation | Value |
|---|---|
| `engineering-routine` exit rows, all time | **15 SKIP / 1 OK** |
| Dominant skip reason | `NO_CHANGE — AI-executable queue empty` (15th consecutive) |
| Open PRs across the fleet | **52** |
| Non-draft, `CLEAN`, mergeable right now | **43** |
| PRs that had ever been reviewed (`reviewDecision`) | **0** |
| Median age of a mergeable PR | **7 days** (max 21) |

The fleet was not slow because cycles ran once a day. It was slow because the
pipeline **had no exit**: correct, green, mergeable work accumulated for weeks
because merge authority did not exist, and nothing ever reviewed a diff. Raising
cycle frequency without an exit would only have grown the queue faster.

So the first thing this harness adds is a *safe* exit — and the gate that makes it
safe is the part with the tests.

## The scripts

| Script | Role | Mutates? |
|---|---|---|
| `cycle-state.ps1` | One snapshot of the world: per-repo git state, every open PR with mergeability + size, ranked work queue, and what is blocked and why | No |
| `cycle-gate.ps1` | Decides whether ONE PR may be merged. All merge authority lives here | No |
| `cycle-merge.ps1` | Merges, only on gate `ALLOW`. Dry-run unless `-Execute` | Yes |
| `cycle-lock.ps1` | Single-owner lock with stale/dead-PID recovery | Lock file only |
| `cycle-metrics.ps1` | Append cycle events; render the per-day operator summary | Append-only |
| `cycle-time.ps1` | Shared timestamp handling (dot-sourced). Read this before touching any date logic | No |
| `Test-CycleGate.ps1` | 41 assertions over the gate. Run before trusting a change | No |

## Quick start

```bash
pwsh -NoProfile -File scripts/cycle/Test-CycleGate.ps1
```

```bash
pwsh -NoProfile -File scripts/cycle/cycle-state.ps1 -OutFile D:\state\cycles\state-latest.json
```

```bash
pwsh -NoProfile -File scripts/cycle/cycle-gate.ps1 -Repo alexmclaren/orryx-core -Pr 42
```

Dry-run a merge (changes nothing):

```bash
pwsh -NoProfile -File scripts/cycle/cycle-merge.ps1 -Repo alexmclaren/orryx-core -Pr 42
```

Today's throughput:

```bash
pwsh -NoProfile -File scripts/cycle/cycle-metrics.ps1 -Summary
```

## The merge gate

`cycle-gate.ps1` returns `ALLOW` or `BLOCK` with a reason code per failure. It is
the single place merge authority is decided; `cycle-merge.ps1` does nothing on its
own judgement.

Criteria, each with tests:

| # | Check | Blocks with |
|---|---|---|
| C1 | Not a draft | `IS_DRAFT` |
| C2 | `mergeable=MERGEABLE` and `mergeStateStatus=CLEAN` | `NOT_MERGEABLE`, `MERGE_STATE_NOT_CLEAN` |
| C3 | CI evidence exists **and** every check is green | `NO_CI_EVIDENCE`, `CI_NOT_GREEN`, `CI_INCOMPLETE` |
| C4 | Declared required contexts present and green, matched **byte-exactly** | `REQUIRED_CONTEXT_MISSING`, `REQUIRED_CONTEXT_NOT_GREEN`, `PROTECTION_FILE_MISSING`, `PROTECTION_UNDECLARED_FOR_BASE` |
| C5 | No `CHANGES_REQUESTED`, no unresolved threads | `CHANGES_REQUESTED`, `UNRESOLVED_REVIEW_THREADS`, `REVIEW_THREADS_UNVERIFIED` |
| C6 | No human-only surface in the diff | `HUMAN_ONLY_SURFACE` |
| C6b | No explicit human-gate marker in title/body/labels | `REQUIRES_HUMAN_REVIEW_TAG` |
| C7 | Scope within ceilings (40 files / 800 additions) | `SCOPE_TOO_MANY_FILES`, `SCOPE_TOO_MANY_ADDITIONS`, `NO_FILES_REPORTED` |
| C8 | Independent, SHA-pinned review approving the current head | `NO_INDEPENDENT_REVIEW`, `REVIEW_STALE`, `REVIEW_NOT_APPROVED`, `REVIEW_NOT_INDEPENDENT`, `REVIEW_NO_REVIEWER`, `REVIEW_UNREADABLE` |

### Five decisions worth understanding before you change it

**1. Absent CI is not green.** `mergeStateStatus: CLEAN` on a repo with zero
workflows means "nothing failed because nothing ran". `orryx-standards` has no
workflows at all, so its PRs report `CLEAN` with no evidence whatsoever. Zero
checks blocks with `NO_CI_EVIDENCE`. `-AllowNoCI` overrides it, is off by
default, and is recorded in the verdict so it shows up in evidence.

**2. Review is pinned to the head SHA, not the PR number.** A review approves a
tree. If a commit lands afterwards, the review is stale and the gate blocks
(`REVIEW_STALE`). This is why the review artifact stores `reviewed_sha`.

**3. Self-approval is not review.** If the review artifact's `reviewer` equals its
`authored_by`, it is rejected (`REVIEW_NOT_INDEPENDENT`).

**4. Required contexts are matched case-sensitively.** Requiring a workflow *name*
where GitHub reports a *job id* deadlocks every PR against a check that never
reports — a trap already recorded in `branch-protection.json`. The gate asserts
declared contexts are present and successful rather than trusting
`mergeStateStatus`.

**5. The merge race is closed server-side.** `cycle-merge.ps1` passes
`gh pr merge --match-head-commit <sha>`, so GitHub itself rejects the merge if the
head moved after review. A local re-check would leave a window open.

`--admin` is deliberately not plumbed through anywhere. Bypassing branch
protection is the boundary this harness exists to respect.

### Human-only surfaces

Any changed path matching these classes blocks with `HUMAN_ONLY_SURFACE`:
`migration`, `secret`, `money_or_legal`, `infrastructure`, `ci_or_policy`,
`prod_config`, `privacy_phi`.

**A path scan alone is not enough.** `CLAUDE.base.md` §7 defines
`[REQUIRES HUMAN REVIEW]` as how an author marks a change human-gated, and that
marker lives in the PR title/body/labels, not in a file path. Found live on
2026-08-08: orryx-flow #49 (`fix(security): reject non-access JWTs as bearer
credentials [REQUIRES HUMAN REVIEW]`) passed every path-based check and was
ALLOWed. C6b now blocks on that marker, on `DO NOT MERGE`, and on
`do-not-merge` / `human-gated` labels.

Deliberately broad. A false block costs one human glance; a false allow can cost
production. Tune the patterns in `cycle-gate.ps1` (`$HumanOnlyPatterns`) and add a
test alongside.

## The review artifact

`D:\state\cycles\reviews\<owner>__<repo>__<pr>.json`

```json
{
  "reviewed_sha": "8f2c...",
  "verdict": "APPROVE",
  "reviewer": "review-pass-<cycle-id>",
  "authored_by": "implement-pass-<cycle-id>",
  "criteria": { "acceptance_met": true, "regressions_considered": true },
  "at": "2026-08-08T03:31:20Z"
}
```

`reviewer` must differ from `authored_by`, and `reviewed_sha` must equal the PR's
current head. For a PR the harness did not author (e.g. Dependabot), set
`authored_by` to the actual author (`dependabot`) — the review is still
independent.

## Evidence and metrics

- **Evidence** — `D:\state\cycles\evidence\<owner>__<repo>__<pr>__<phase>.json`,
  phase ∈ `blocked | dryrun | attempt | merged | failed`. `attempt` is written
  *before* the merge call, so a crash mid-merge is distinguishable from never
  having tried.
- **Metrics** — `D:\reports\evolution\cycle-metrics.jsonl`, one row per event
  (`cycle_start`, `task_selected`, `review_done`, `merge_attempt`, `cycle_end`,
  `halt`, `idle`).
- **Daily summary** — `cycle-metrics.ps1 -Summary [-Date YYYY-MM-DD]`.

`idle` rows carry `queue_depth=N` in `detail`, which is what makes
*idle-despite-available-work* measurable instead of invisible.

## Timestamps — read this before touching date logic

`ConvertFrom-Json` silently coerces any ISO-8601-looking string to `[datetime]`
and re-renders it in local format with the `Z` stripped:

```
raw JSON    : "ts":"2026-08-07T12:01:04Z"
after parse : 08/07/2026 12:01:04     [System.DateTime]
```

This caused **three separate defects while this harness was being written**: a PR
age table where failed parses silently carried the previous row's age forward
(reporting 153 days for a 7-day-old PR), an exit-log day filter, and a runner lock
that read every lock as stale and therefore never locked at all.

Never read a timestamp through `ConvertFrom-Json`. Use `Get-IsoUtcField` on the
raw line, then `Read-IsoUtc`. Both are in `cycle-time.ps1`.

Date **labels** are LOCAL (Australia/Brisbane, UTC+10, no DST) via
`Get-LocalDateLabel`; **timestamps** stay UTC with `Z` via `Get-UtcStamp`. Same
rule as the routine fleet's DOC-36.

## Concurrency and recovery

`cycle-lock.ps1` gives one owner at a time. A lock is stale — and reclaimable —
when its TTL expires (default 90 min), its recorded PID is gone (covers machine
restart), or the file is corrupt.

The TTL fails toward *liveness* on purpose: an indefinite lock left by a crashed
session blocks every later run and is indistinguishable from "nothing to do". A
reclaimed lock cannot cause an unsafe merge, because the gate — not the lock — is
what protects correctness. Worst case is a wasted cycle.

## Work prioritisation

`cycle-state.ps1` ranks actionable PRs: `security` → `deps` → `code` → `docs`,
oldest first within a tier.

A dependency bump carrying a CVE fix closes a *verified* security gap, which the
operator ranks above new capability; draining mechanical Dependabot backlog also
stops it hiding real CVEs behind noise. Docs rank last — cheapest to merge, but
they move no production-readiness gap on their own.

## Extending it

Adding a gate criterion:

1. Add the check, calling `Deny <CODE> <detail>` — never return early, so every
   independent failure surfaces in one pass.
2. Add a test to `Test-CycleGate.ps1` asserting `BLOCK` **and** the reason code.
3. Run the suite. 41 assertions currently pass; keep it at zero failures.

Tests inject state via `-InputObject`, so no network is needed. `Prop` handles
both `PSCustomObject` (real `gh` output) and hashtables (injected state) — a
dictionary-blind version silently read every injected field as absent, which
presented as "no files changed, no checks ran" and disabled the risk scan.

