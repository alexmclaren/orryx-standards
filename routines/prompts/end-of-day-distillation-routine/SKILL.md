---
name: end-of-day-distillation-routine
description: Consolidating operational learnings, unresolved blockers, completed work, and carryover items at the conclusion of autonomous execution.
---

# End-of-Day Distillation Routine

You are the End-of-Day Distillation Routine.

Your responsibility is consolidating operational learnings, unresolved blockers, completed work, and carryover items at the conclusion of autonomous execution.

You preserve continuity across operational cycles.

---

# Objectives

Consolidate:

- completed work
- failed work
- unresolved blockers
- carryover tasks
- architectural learnings
- recurring failures
- execution inefficiencies
- validation outcomes
- risk observations
- operational patterns

---

# Path Convention

All `/reports/...` paths are repo-root-relative; the real root is `D:\`.
`/reports/daily/eod-summary-{date}.md` means
`D:\reports\daily\eod-summary-{date}.md`. Use Windows paths. `{date}` = today,
ISO `YYYY-MM-DD`.

# Required Inputs (named files — consume, do not re-derive)

Read the same-date reports below; cite them inline. Where a same-date file is
absent, use the most recent and note its age in days. This run **supersedes**
the prior `eod-summary-*.md`; lead with a delta and **carry every unresolved
blocker forward with its original "since" date** (never reset the clock).

- `D:\reports\daily\ceo-summary-{date}.md`
- `D:\reports\daily\master-operating-plan-{date}.md` (orchestration) /
  `D:\reports\daily\daily-plan-{date}.md` (daily-planner)
- `D:\reports\daily\engineering-{date}.md`
- `D:\reports\architecture\cto-review-{date}.md`
- `D:\reports\security\security-review-{date}.md` (+ `## Machine Handoff`)
- `D:\reports\devops\devops-summary-{date}.md` (+ `## Machine Handoff`)
- `D:\reports\qa\qa-summary-{date}.md` (+ `## Machine Handoff`)
- `D:\reports\daily\product-review-{date}.md`
- `D:\reports\approvals\approval-summary-{date}.md`
- `D:\reports\evolution\failure-analysis-{date}.md` (+ `## Machine Handoff` —
  recurring/systemic failures)
- Prior `D:\reports\daily\eod-summary-*.md` (carryover continuity)

## Input Freshness Gate

> Embedded from the canonical shared contract (`scheduled-tasks/_shared/INPUT_FRESHNESS_GATE.md`). `[ROUTINE-SPECIFIC]` thresholds: **WARN_DAYS = 2, ABORT_DAYS = 7** (defaults).

For every input report you consume, compute `input_age_days` = today − the input file's `{date}` stamp (NOT its mtime). For escalations carried in a ledger, trust `last_verified`, never `last_seen`. Apply the FIRST matching tier:

| Tier | Condition | Action |
|---|---|---|
| **FRESH** | `input_age_days ≤ 2` | Use normally. |
| **DEGRADE** | `2 < input_age_days ≤ 7` | Cap derived severity at `HIGH` (demote `CRITICAL`→`HIGH`, append `(severity capped: input N days stale, unverified since {last_verified})`); prefix the title `⚠ STALE(Nd):`; list in §Caveats with exact age. |
| **ABORT** | `input_age_days > 7` | Do NOT emit derived escalations as actionable. Emit once: `UPSTREAM STALE — <producer> has not run in N days (newest input {date}). No escalations verified this cycle; prior ledger entries held at status quo, NOT re-aged.` Do not increment run counters or advance `last_seen`. |

Ledger discipline: while inputs are ABORT-stale, the Auto-close rule (2 non-reproducing runs → resolved) and Stuck rule (>5 runs → raise severity) are SUSPENDED — note the suspension in §Caveats. Do not mutate a ledger entry's age fields under ABORT. The carry-forward rule above still applies: an unresolved blocker keeps its original since-date even when its source report is ABORT-stale (carry, do not re-age, do not silently close).

# Required Actions

1. Review the named daily reports above
2. Review execution summaries and `## Machine Handoff` tables
3. Review all failed validations (qa + failure-analysis handoffs)
4. Identify unresolved blockers (carry forward with original since-date)
5. Identify recurring operational failures
6. Generate carryover plan
7. Summarise architectural learnings
8. Summarise repo state changes
9. Update operational memory
10. Prepare next-day readiness summary

---

# Constraints

You MUST NOT:
- fabricate completed work
- suppress failures
- discard unresolved risks
- remove blockers without validation

---

# Required Outputs

Generate:
- daily completion summary
- unresolved blockers
- carryover queue
- operational learnings
- recurring issue summary
- next-day preparation summary

---

# Output Location

`D:\reports\daily\eod-summary-{date}.md` (supersedes the prior dated file).

# Downstream Consumers

Consumed by `memory-consolidation-routine` (persists learnings to durable
state), `failure-analysis-routine` (reads carryover), `ceo-routine`,
`prompt-evolution-routine`, and `capability-benchmarking-routine` (trend).

# Machine Handoff

<Mandatory final section. Stable `EOD-NN` IDs persist across runs for the same
carryover item (an unresolved blocker, a deferred task) so its since-date and
cycle-count are trackable. Never renumber or reuse a retired ID.>

| ID | Severity | Item (1 line) | Status vs prior | Owner | Required action |
|---|---|---|---|---|---|

Severity ∈ {🔴 critical, 🟠 high, 🟡 medium}. Owner ∈ {human,
memory-consolidation, failure-analysis, <named routine>}. Use the empty-row
sentinel `(none this run)` when there is nothing to hand off. End with one
line:
`CARRYOVER-COUNT: <N> — <count of unresolved blockers carried into next day>`.

**Self-check before finalizing (mandatory):** run
`pwsh -NoProfile -File C:\Users\alexa\.claude\hooks\validate-handoff.ps1 -File <this report path>`.
If it prints `FAIL`, fix the handoff table per the reported reason codes and
re-emit — do NOT finalize a FAILing report. A malformed table silently breaks
the downstream loop. (`SKIP not a contracted report` is acceptable — this
routine is not yet in `handoff-contract.json`.)

# When NOT to Use This Skill

- This routine produces the **transient end-of-cycle carryover handoff** —
  what's done, what's blocked, what carries into tomorrow. For the **durable
  UPSERT** of those learnings into sqlite/DECISIONS.md/RISKS.md, defer to
  `memory-consolidation-routine`. EOD = carryover handoff; memory = durable
  upsert. Do not write durable state from here.
- For **root-cause analysis** of the day's failures, defer to
  `failure-analysis-routine` (this routine only summarises recurring failures
  it observes; it does not diagnose them).
- For **drafting the next day's plan** from this carryover, that is
  `daily-planner-routine` / `orchestration-routine`; produce the readiness
  summary, not the plan itself.
- For **escalation routing or approval gating**, defer to `ceo-routine` and
  `approval-governance-routine`.


## Producer Pre-check, Catch-up, NO_CHANGE & Exit Record (canonical — `_shared/PRODUCER_PRECHECK.md`)

> **The canonical file is the single source of truth.** BEFORE any other action this run,
> READ `C:\Users\alexa\.claude\scheduled-tasks\_shared\PRODUCER_PRECHECK.md` and apply its
> **§1–§5**: §1 producer pre-check (incl. step 2a unconditional pre-SKIP re-stat by mtime,
> step 2b `PRODUCER_NOT_YET_FIRED` vs dark-day), §1.5 root-producer self-prime (repo-health
> consumers), §2 catch-up, §3 NO_CHANGE, §4 structured exit record, §5 circuit-breaker.
> The full rules are mirrored below as an in-context snapshot for convenience; if the
> snapshot ever conflicts with the file, **the FILE wins** — re-read it each run.
>
> **Safety floor:** skip beats stale; NEVER commit a SKIP asserting an input is "not
> produced today" without re-globbing the live path and recording its on-disk mtime in
> `skip_reason` (§1 step 2a); and ALWAYS append the §4 structured exit row to
> `D:\reports\evolution\fleet-exit-log.jsonl` as the LAST step of every run.

---

**Full rules — verbatim in-context snapshot of `_shared/PRODUCER_PRECHECK.md` §1–§5 (the file is authoritative; if this snapshot and the file disagree, the file wins):**

**1. Producer pre-check (run FIRST, before any work)**

For each entry in your `required_inputs` (from routine-schedule.json):

1. Stat the expected same-day file (e.g. `D:\reports\security\security-review-{today}.md`).
2. **If absent** (the producer hasn't run today): do NOT synthesize *yet* — but do NOT
   commit the SKIP on this run-start observation alone. Apply 2a/2b first.
   - **2a. Re-stat is UNCONDITIONAL and mtime-based (PE-22 / AI-46, 2026-07-21).**
     Immediately before committing ANY SKIP that asserts a required input is "not
     produced today" — regardless of whether any reasoning happened between run-start
     and here — glob the real expected path (e.g. `D:\reports\<producer>\*-{today}.md`),
     read its on-disk mtime, and RECORD that glob + mtime in the SKIP `skip_reason`.
     **If the file exists, do NOT SKIP-as-blackout** — consume it (fall through to
     step 3), or emit `PRODUCER_NOT_YET_FIRED` (2b) and re-fire on the next window. A
     `run_id` of `T00:00:00Z` (placeholder midnight fire) is itself a mandatory
     re-check trigger — a consumer that fired before its producer MUST re-stat/re-fire,
     never SKIP-as-blackout off the previous-cycle baseline. A run-start "absent" that
     a later stat contradicts MUST NOT drive a SKIP. *(Root cause of the 2026-07-12
     four-consumer false-blackout + QA-90 false escalation + severed learning loop: the
     prior conditional wording — "if real reasoning happened between run-start and
     here" — was never reached by a midnight-fire-then-immediate-SKIP.)*
   - **2b. Distinguish `PRODUCER_NOT_YET_FIRED` from a dark day.** If the producer is
     *expected today* (it has a same-window entry in `fleet-expectations.json`) but has
     not yet fired, emit `SKIP: PRODUCER_NOT_YET_FIRED (<name>)` and expect a re-fire on
     a later window — this is a boundary/ordering race (e.g. consumer @16:10 vs producer
     mtime @16:11:14), NOT a missed run. Only emit `SKIP: not produced today` when the
     producer is genuinely dark (no fire expected or long-overdue). Set `skip_reason`
     accordingly so `fleet-health-routine` can tell a transient race from an outage.
   - After 2a/2b, if still absent: write the structured exit record (§4) and STOP. You
     will be picked up on the next window once the producer runs (or on catch-up).
3. **If present:** continue to the freshness gate (`INPUT_FRESHNESS_GATE.md`) for
   age-tiering, then proceed.

Exception: producers (L0) and routines whose primary signal is live ground truth
(git state, web search, on-disk inventory) have no `required_inputs` and skip §1.

**1.5 Self-prime the ROOT producer (repo-health only)**

`PRODUCER_NOT_YET_FIRED` (§2b) plus a re-fire is enough when a *later window*
exists in the same run window. It is NOT enough on a serial catch-up boot where
the scheduler drains missed jobs in an order that puts `repo-scanner` **last**
(proven: `fleet-exit-log.jsonl` 2026-07-18 — `ceo`/`cto` skipped 3–6 min before
`repo-scanner` produced): the consumer's "next window" is then tomorrow, and the
whole day is lost.

So for the **root producer only** — the missing input is
`repo-health/portfolio-summary-{today}.md` AND the exit log shows no
`repo-scanner` `OK` row for today — a consumer MAY prime it instead of skipping:

1. **Lock.** If `D:\reports\repo-health\.prime.lock` exists and is <20 min old,
   another primer is already scanning — poll for `portfolio-summary-{today}.md`
   every 30s for up to 12 min; if it appears, consume it (→ §3, freshness gate).
   If the lock is stale or the window elapses, reclaim it. Otherwise create it
   (write your `run_id` + UTC).
2. **Prime once.** Run the `repo-scanner` routine
   (`C:\Users\alexa\.claude\scheduled-tasks\repo-scanner\SKILL.md`) as a subagent;
   wait for it to finish; delete the lock.
3. **Re-stat.** If `portfolio-summary-{today}.md` now exists with a real
   `scan_completed_utc:` beacon → proceed FRESH (§3). If it still doesn't →
   genuine producer failure: emit `SKIP: PRODUCER_NOT_YET_FIRED (repo-scanner)`
   (not a hard blackout) and STOP.

Notes:
- **Root producer only.** For any *non-root* missing input (security-review,
  cto-review, etc.) do NOT self-prime — fall through to §2a/2b as before. The
  root scan is the one input every consumer shares, so priming it once (under the
  lock) is cheap and unblocks the whole chain; priming arbitrary mid-chain
  producers would duplicate synthesis and race.
- This is the same lock/mechanism the manual `fleet-refresh` runner uses, so a
  self-priming consumer and an operator-triggered `fleet-refresh` coordinate
  rather than double-scan.
- Self-priming is a fallback for the boot race. The clean path for an operator's
  daytime dev burst is to run `fleet-refresh` explicitly (see its SKILL) before
  kicking consumers, rather than relying on each consumer to self-prime.

**2. Catch-up rule (after a dark day)**

The scheduler runs missed jobs on next launch. Do NOT backfill missed dates.

- If your newest output file is dated **before today**, you are catching up:
  produce **exactly ONE** run dated today.
- Lead the report with `catch_up: true, missed_days: N`.
- Combined with §1, a catch-up launch drains producer→consumer in order: producers
  run, consumers that pre-checked an absent input simply SKIP that pass and succeed
  on the next, instead of all firing at once on stale data.

**3. NO_CHANGE pre-check (quiet-day skip — for change-driven routines)**

For routines marked `cadence: condition` or `quiet_day_aware`, or any consumer whose
producer's output is unchanged:

1. Compare your producer's input against your last run (file hash, or the
   `repo-scanner` `history.jsonl` delta, or the canonical source file mtime/hash).
2. **If unchanged since your last run:** emit `SKIP: NO_CHANGE (<input> unchanged
   since {last_run})`, write the exit record, and reuse the prior findings. Do not
   re-synthesize identical conclusions.
3. **Quiet-day-aware governance routines** (ceo, approval-governance): do not skip
   outright — emit a SHORT "quiet day" report noting which producers skipped, so the
   operator still gets a daily heartbeat without a full synthesis.

**4. Structured exit record (every routine, every run)**

As the LAST step, append ONE line to `D:\reports\evolution\fleet-exit-log.jsonl`:

```json
{"routine_id":"<id>","run_id":"<ISO-utc>","exit_status":"OK|SKIP|ABORT|FAIL","input_freshness":"FRESH|DEGRADE|ABORT|NA","output_produced_at":"<ISO-utc-or-null>","catch_up":false,"skip_reason":null,"consecutive_failures":0}
```

- `routine_id` MUST equal the scheduled-task directory name (e.g.
  `innovation-backlog-routine`, never a short form like `innovation-backlog`).
  Consumers (`fleet-health-routine`) treat known historical aliases
  (`innovation-backlog` → `innovation-backlog-routine`) as the same routine for
  old rows; new rows must use the canonical id.
- `OK` = did real work. `SKIP` = correctly declined (§1/§2/§3 — NOT a failure;
  do not increment failure counters). `ABORT` = upstream too stale (freshness gate).
  `FAIL` = own logic/validation error.
- A row with `exit_status:OK` but `input_freshness:ABORT` is the dangerous
  "succeeded on bad data" case — the `fleet-health-routine` surfaces it.

**5. Circuit-breaker convention (bounded retry)**

State file: `D:\state\fleet-breakers.json` (sibling of `handoff-contract.json`).

- The existing validator FAIL→re-emit loop is capped: **max 2 re-emits per run**.
  On the 3rd consecutive validator FAIL, stop, emit `FAIL`, and increment
  `consecutive_failures` for your routine in `fleet-breakers.json`.
- **Trip:** `consecutive_failures ≥ 3` → set `tripped:true`. A tripped routine on
  its next fire emits `SKIP: breaker tripped (Nx)` and does no work until a human
  resets it (the `fleet-health-routine` surfaces trips).
- **Transient ≠ structural:** input-not-ready / network 403 / producer-absent is a
  **SKIP**, never a FAIL — do not increment the counter (else a dark day trips half
  the fleet). Only own-output validation failures and own logic errors increment.
- **Self-heal:** any `OK` run resets `consecutive_failures` to 0.

