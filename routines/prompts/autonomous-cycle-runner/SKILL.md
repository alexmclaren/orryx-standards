---
name: autonomous-cycle-runner
description: State-based continuous autonomous engineering — loops inspect/select/review/gate/merge for up to 90 min per fire, draining the mergeable-PR queue through a tested fail-closed gate. Disarmed by default.
---

Run the Autonomous Cycle Runner. This is a state-based continuous loop, NOT a once-daily batch job: after each unit of work, re-inspect and start the next cycle until a halt condition, the 90-minute window, or the 6-cycle budget is reached.

The operator is not present. Execute autonomously.

FIRST: read D:\orryx-standards\scripts\cycle\README.md (design rationale and the timestamp trap), then C:\Users\alexa\.claude\scheduled-tasks\_shared\PRODUCER_PRECHECK.md sections 1-5.

ARMING (fail-closed): read D:\state\cycles\ARMED.json. If absent or armed=false, run the FULL cycle but call cycle-merge.ps1 WITHOUT -Execute, and report which PRs WOULD have merged. Only if armed=true pass -Execute. Never create or edit that file.

TOOLING under D:\orryx-standards\scripts\cycle\ — do not reimplement:
  cycle-lock.ps1 -Acquire   (release at exit; stale locks self-recover)
  cycle-state.ps1 -OutFile D:\state\cycles\state-latest.json   (the ONE world snapshot + ranked queue)
  cycle-gate.ps1            (the ONLY merge-authority decision; never bypass)
  cycle-merge.ps1           (merges only on gate ALLOW; dry-run unless -Execute)
  cycle-metrics.ps1         (append every event; -Summary for the daily table)

LOOP: acquire lock -> cycle-state -> evaluate the SAFETY BOUNDARY (below) -> select the top actionable queue item not yet attempted this run (order: security, deps, code, docs; oldest first) -> INDEPENDENT REVIEW -> gate+merge -> follow-on -> re-inspect -> next cycle.

SAFETY BOUNDARY — and note the deliberate ordering. This routine fires at 07:40 local, which is BEFORE execution-safety-routine's 16:33 slot, so today's report will normally NOT exist yet. That is intentional: this routine reads live git/gh state rather than the report fleet, so running early avoids the serial dispatcher's never-drained tail (FH-79). It does mean the safety input is usually yesterday's, so degrade explicitly rather than either failing closed forever or proceeding ungated:

  - Glob D:\reports\daily\execution-safety-*.md and take the NEWEST (check both {LOCAL-date} and {LOCAL-date - 1}, per the DOC-36 transition rule).
  - RED HALT in the newest report, at any age -> stop everything. A stale halt still halts.
  - AMBER RESTRICT -> honour the named restricted scopes.
  - GREEN GO, age <= 1 day -> full scope.
  - GREEN GO, age > 1 day, OR no execution-safety report found at all -> DEGRADED SCOPE: a stale clean report cannot license full autonomy. Restrict this run to work_class 'deps' and 'docs' only; do NOT merge 'code' or 'security' class changes. Say so explicitly in the report and in the exit-row note.

This mirrors execution-safety's own DEGRADE tier: a stale-but-clean input may only RAISE a halt, never CLEAR a dimension.

INDEPENDENT REVIEW IS MANDATORY. The reviewer must not be the author. Spawn a separate review agent (tiered-agents:code-reviewer, or security-reviewer for auth/secrets/PHI/migrations/infra) given only the diff and acceptance criteria. It judges: task interpreted correctly; acceptance criteria actually met; code quality; hidden regressions; test adequacy; security/privacy; operational impact; merge/revise/halt. Then write D:\state\cycles\reviews\<owner>__<repo>__<pr>.json with keys reviewed_sha (MUST equal the PR's current head SHA), verdict (APPROVE or REJECT), reviewer (must differ from authored_by), authored_by, criteria, at (ISO-8601 UTC). The gate rejects a stale review and rejects self-approval. Green CI alone is NOT sufficient. For a genuinely trivial diff (lockfile-only patch bump, green CI, no risk flag) you may review inline but must still write the artifact with a distinct reviewer and record trivial_exception plus a one-line justification.

ON GATE BLOCK: CI_INCOMPLETE means re-check next cycle (not a failure). HUMAN_ONLY_SURFACE / SCOPE_TOO_* / CHANGES_REQUESTED are human decisions - emit a decision brief and move on. BEHIND may be updated from base if in scope and conflict-free; DIRTY conflicts are human-gated. Never pass -AllowNoCI on your own initiative. Never pass --admin. Never bypass branch protection.

HALT CONDITIONS (first match stops the loop): empty queue; execution-safety RED HALT; 90-minute window exhausted; 6 cycles done; 2 consecutive cycles with no state change; 3 consecutive gate BLOCKs of the same reason class; human-only boundary on the only remaining work; breaker tripped in D:\state\fleet-breakers.json. An escalation exit is a SUCCESS of the harness - do not spin.

HUMAN-ONLY BOUNDARIES, never crossed regardless of CI: destructive production DB operations; irreversible data loss; secrets handling or exposure; billing/payments/pricing/legal/financial commitments; major production infrastructure change; external communications in the operator's name; customer-data or privacy-sensitive access; security findings of uncertain impact; architectural lock-in; ambiguous product decisions; scope materially beyond the approved task; failing or inconsistent CI that cannot be confidently resolved; anything repository policy forbids. Fail closed on uncertainty.

ON EVERY HALT emit a decision brief: HALT (one-line issue) / Evidence (paths, PR and check names, exact reason codes) / Options / Recommendation / Smallest human action.

RESILIENCE: never select the same repo#pr twice in one run; re-read live state before acting (another session may have resolved it); an 'attempt' evidence file with no 'merged'/'failed' sibling means a merge outcome is UNKNOWN - re-read live PR state, never blind-retry; max 2 remediation attempts per item per run; treat rate limits and CI delay as CI_INCOMPLETE and move on.

IDLE IS A FAILURE TO REPORT: if the actionable queue was non-empty and you merged nothing, log an idle metric row with queue_depth=N and say so plainly in the report.

OUTPUT: D:\reports\evolution\cycle-runner-{LOCAL-date}.md, leading with a section 0 delta. Include cycles run; tasks selected; merges with PR links (or would-have-merged when disarmed); gate blocks with reason codes; reviews and verdicts; halt cause; the cycle-metrics.ps1 -Summary table; and the recommended next task. Date LABELS are LOCAL (Australia/Brisbane UTC+10, no DST); timestamps stay UTC with Z.

LAST STEP: append the structured exit row via pwsh -NoProfile -File C:\Users\alexa\.claude\scheduled-tasks\_shared\append-exit-row.ps1 -RoutineId autonomous-cycle-runner -ExitStatus OK|SKIP|ABORT|FAIL -InputFreshness NA -OutputFile <report path> -Note '<summary>'. Then release the lock.
---

## Why you exist (context, not instructions — read before changing any rule above)

Measured 2026-08-07, this is the problem you were built to fix:

| Observation | Value |
|---|---|
| `engineering-routine` exit rows, all time | **15 SKIP / 1 OK** |
| Dominant skip reason | `NO_CHANGE — AI-executable queue empty` (15th consecutive) |
| Open PRs fleet-wide | **52** |
| Non-draft, `CLEAN`, mergeable right now | **43** |
| PRs ever reviewed (`reviewDecision`) | **0** |
| Median age of a mergeable PR | **7 days** (max 21) |

The fleet was never slow because cycles ran once a day. It was slow because the
pipeline **had no exit** — correct, green, mergeable work accumulated for weeks
because merge authority did not exist and nothing ever reviewed a diff.

Two consequences that bind you:

1. **More cron fires would not have helped.** The dispatcher runs strictly serial at
   roughly one routine per hour (FH-77), so a ~7h window drains ~7 of 24 registered
   routines — it is already over-subscribed ~3.4x. That is why you get ONE cron fire
   and loop internally: intra-day throughput comes from your own loop, not from
   more scheduled entries. Do not "fix" low throughput by asking for more fires.

2. **Your job is to drain the queue, not to grow it.** Generating another unmerged
   branch is not progress. If the actionable queue was non-empty and you merged
   nothing, that is a failure to report, not a quiet success.

## Never do these

- Never relax a `cycle-gate.ps1` criterion at runtime to get something merged. The
  gate is human-authored and test-covered (41 assertions); changing it goes through
  a reviewed PR.
- Never pass `-AllowNoCI` on your own initiative. Absent CI is not green.
- Never pass `--admin`, and never bypass branch protection.
- Never approve your own work. `reviewer` must differ from `authored_by`; the gate
  enforces it, and defeating that check defeats the entire design.
- Never edit `D:\state\cycles\ARMED.json`.

## Timestamps

`ConvertFrom-Json` silently coerces ISO-8601 to a local `[datetime]` with the `Z`
stripped. It caused three defects while this harness was being built, including a
lock that read every lock as stale and therefore never locked. Use
`Get-IsoUtcField` / `Read-IsoUtc` from `cycle-time.ps1`; never read a timestamp
through `ConvertFrom-Json`. Date **labels** are LOCAL (UTC+10); **timestamps** are
UTC with `Z`.
