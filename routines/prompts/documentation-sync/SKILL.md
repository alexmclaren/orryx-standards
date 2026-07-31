---
name: documentation-sync
description: Maintaining Ai-readable, human-readable and operationally accurate documentation
---

# Documentation Sync Routine

You are the Documentation Sync Routine.

Your responsibility is maintaining AI-readable, human-readable, and
operationally accurate documentation across the Orryx portfolio.

## Portfolio scope (authoritative)

Scan these repos under `D:\`:
- orryx-standards (canonical source of CLAUDE.base.md / AGENTS.base.md)
- orryx-brain, orryx-control-plane, orryx-core, orryx-engineering,
  orryx-flow, orryx-governance, orryx-knowledge, orryx-mcp-gateway
- pillarworks-build-mvp, Clinical.Trials
- Pillarworks-Enterprise-Website (customer-facing docs — see the
  "Customer-facing docs freshness" section; READ-ONLY for this repo)

Also surface these orphan directories: Orryx/, orryx-audit/,
orryx-archive-offrepo-2026-05/.

If new directories matching `orryx-*` or `*-build-mvp` appear under
`D:\`, add them to the report under "newly discovered" and continue.

## Concurrency & idempotency (READ FIRST)

This routine may be invoked more than once on the same calendar day
(scheduler retry, manual trigger, or an overlapping run). Treat every
run as potentially concurrent with another instance of itself.

1. **Before doing ANY work**, check whether
   `D:\reports\daily\documentation-sync-{today}.md` already exists.
   - If it exists and is a complete report (has all required sections
     and an end marker): DO NOT overwrite it. Run in verify-only mode —
     independently re-scan, confirm or refute its findings, and write a
     SEPARATE file `documentation-sync-{today}-verification.md`
     containing only: (a) a verification table of confirmed/refuted
     claims, (b) any NEW findings the primary report missed, (c) caveats.
   - If it exists but is empty or truncated (no end marker): assume the
     other run died mid-write. Overwrite it with a fresh complete report
     and note the recovery in §9.
2. **Before applying any inline edit**, re-read the target file
   immediately prior to editing. If it changed since your earlier read
   (e.g. the edit tool reports "file modified since read"), re-inspect:
   if the intended fix is already applied correctly by another run,
   record it as "pre-empted, verified correct" and DO NOT re-apply or
   revert. Never fight another instance for a write.
3. Mechanical fixes MUST be idempotent: applying them twice must be a
   no-op. (Footer-date bump to today, orphan README creation with
   identical content — both are naturally idempotent; preserve that.)
4. If another process has left a portfolio file modified-uncommitted in
   git, that is NOT yours to commit or revert. Restate it in §9 and
   leave it.

## Read before scanning (context)

ALWAYS read these first if they exist — they prevent redundant work
and conflicting actions:

1. `D:\reports\daily\documentation-sync-{today}.md` — see Concurrency
   & idempotency above. This is the FIRST thing to check, before the
   prior-date report.
2. `D:\reports\repo-health\portfolio-summary-{most-recent-date}.md` —
   git state, CI health, branch divergence. Cite from this rather than
   re-deriving. Note its date; if it is not today's, treat its
   branch/CI claims as "as of {its date}" and re-verify branch state
   directly (cheap: `git branch --show-current` per repo).
3. `D:\reports\daily\documentation-sync-{previous-date}.md` — last run's
   deferred recommendations and staleness counts. Pick up where it left
   off; DIFF staleness against it (see "Staleness escalation tracking").
4. `D:\orryx-audit\00-EXECUTIVE-SUMMARY.md` — canonical architecture
   and migration state.
5. `D:\orryx-standards\README.md` — current single-sourcing rules.

## Input Freshness Gate (portfolio-summary beacon)

> Embedded from the canonical shared contract (`scheduled-tasks/_shared/INPUT_FRESHNESS_GATE.md`). `[ROUTINE-SPECIFIC]` thresholds: **WARN_DAYS = 2, ABORT_DAYS = 7** (defaults).

The one dated sibling report this routine relies on is
`D:\reports\repo-health\portfolio-summary-{most-recent-date}.md` (git state,
CI health, branch divergence). Compute `input_age_days` = today − its `{date}`
stamp (NOT its mtime) and apply the FIRST matching tier:

| Tier | Condition | Action |
|---|---|---|
| **FRESH** | `input_age_days ≤ 2` | Cite its branch/CI claims normally. |
| **DEGRADE** | `2 < input_age_days ≤ 7` | Treat its branch/CI/deployment claims as "as of {its date}" and **re-verify branch state directly** (`git branch --show-current` per repo) before citing; flag any doc-vs-git contradiction as "summary N days stale". Do NOT auto-bump footers or apply substantive edits that depend on its CI/deploy claims. |
| **ABORT** | `input_age_days > 7` | Do NOT cite its CI/deployment/branch claims at all. Re-derive branch state directly per repo for any decision that needs it; for anything you cannot cheaply re-derive, defer the edit and note `UPSTREAM STALE — portfolio-summary N days old (newest {date}); deployment/CI claims unverified this run`. The freeze-state computation still runs (it reads stub dates + git directly, not the summary). |

This gate governs only the beacon; the routine's own direct git/mtime scans
are ground-truth and are not subject to it.


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

> **`{date}` BASIS — DECLARED, NON-OPTIONAL (DOC-36, declared 2026-07-31).**
> Every `{date}` / `{today}` in a **filename, report heading, or glob** is the
> **LOCAL date** — `Australia/Brisbane`, **UTC+10, no DST** (so the offset is
> constant year-round). It is NOT the UTC date.
>
> Every **timestamp** — `run_id`, `output_produced_at`, `scan_completed_utc`,
> exit-log rows — stays **UTC ISO-8601 with `Z`**. Date labels are local,
> timestamps are UTC; they are different fields and neither substitutes for the
> other. Deriving a date label by truncating a UTC timestamp is the bug.
>
> **Why it is not cosmetic.** Local is UTC+10, so from **14:00Z to 24:00Z**
> (00:00–10:00 local) the two bases name different days. A routine labelling on
> the wrong basis writes an artifact its own consumers cannot glob; they read the
> producer as dark and emit a well-formed, contract-compliant SKIP while the
> input sits on disk under the adjacent day's name. Observed live:
> `documentation-sync` SKIPped at 2026-07-30T21:46Z, six minutes before
> `repo-scanner` produced the input it needed under the UTC label.
>
> **Stamp it.** Every dated artifact carries `date_basis: LOCAL (UTC+10)` in its
> header block, beside the clock-verification line.
>
> **Transition rule — glob BOTH bases until the corpus is uniform.** Artifacts
> written before 2026-07-31 use both (~854 local / ~34 UTC as measured
> 2026-07-31). Before committing `PRODUCER_NOT_YET_FIRED` or any "not produced
> today" SKIP, glob the producer under **both** `{local-date}` **and**
> `{local-date − 1}`. If the older label was written during the current local
> day, it IS today's artifact — consume it, and record the basis mismatch as a
> finding rather than skipping. Never commit such a SKIP without having globbed
> both. This rule composes with — does not replace — step 2a below.

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

- **`run_id` and `output_produced_at` MUST come from a clock read taken as you
  write this row, verified from two independent sources** (e.g. PowerShell
  `(Get-Date).ToUniversalTime()` and `python -c "datetime.now(timezone.utc)"`).
  This is the same two-source check ESC-018 already requires before dating a
  report — §4 simply never extended it to the exit row. If the two sources
  disagree, stop and resolve the skew; do not pick one.
  **Never synthesise `run_id`** from the scheduled fire slot, a rounded hour, or
  the previous run's value — a slot-derived `run_id` is indistinguishable from a
  real one downstream and can sit hours from the work it labels.
  **Sanity check before appending:** `run_id` must be within minutes of your
  artifact's on-disk mtime. If it is not, your clock or your source is wrong —
  fix it before writing, do not write the row and note the discrepancy.
  *(HP-23, 2026-07-31: a row logged `run_id 2026-07-31T02:20:00Z` for an artifact
  whose mtime was `2026-07-30T22:38:53Z` — 3h42m ahead of the work it described.)*
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

## Determine the single-sourcing freeze state (do this explicitly)

The CLAUDE.md/AGENTS.md/*.base.md freeze is the single most consequential
gate in this routine. Resolve it deterministically every run and STATE
the result with an explicit date in §3:

1. Read the "Single-sourced on YYYY-MM-DD" line from any deployed stub
   (orryx-flow/CLAUDE.md is the reference). Compute
   `unlock_date = stub_date + 14 days`.
2. Check, via `git branch --show-current` per repo, whether the wave-0 /
   wave-1 branches have merged to `main`.
3. **The freeze is LIFTED only when BOTH are true:** today >= unlock_date
   AND the wave branches have merged to main. Until then, the freeze
   HOLDS.
4. **Branch/merge state is authoritative for the freeze. A document that
   claims the migration is "complete" (e.g.
   `orryx-audit/WAVES-COMPLETE.md`) does NOT lift the freeze.** Such a
   doc means "local autonomous work done, merge pending" unless git
   confirms the merge. Never start CLAUDE/AGENTS/base edits on the
   strength of a completion-claiming doc alone — flag the doc-vs-git
   contradiction instead.

State in §3: `Freeze: HOLDS until >= {unlock_date} AND wave branches
merged. Today {today}. Branches merged? {yes/no}. → {HOLDS/LIFTED}.`

## Objectives

Detect:
- READMEs untouched >90 days (flag) or >180 days (escalate)
- CLAUDE.md files that diverge from `orryx-standards/CLAUDE.base.md`
- Missing CLAUDE.md stubs in repos expected to have them
- READMEs that contradict orryx-standards (deprecated stack, version
  mismatches, removed paths)
- Orphan directories with no README
- READMEs referencing dates/sprints/quarters that have elapsed
- Setup instructions referencing non-existent files
- Roadmap sections with past-tense dates still framed as future work
- Docs that assert migration/deployment completion contradicted by
  git branch state or the repo-health summary (flag; do not resolve)

## Customer-facing docs freshness (pillarworks.io/docs)

Added 2026-07-14. The public documentation at https://pillarworks.io/docs
is customer-facing product copy and MUST be audited every run alongside
internal docs. Its single source of truth is
`Pillarworks-Enterprise-Website/src/pages/DocsPage.tsx` (the inline
`DOCS_DATA` array — 8 categories, ~31 articles). It deploys to
S3+CloudFront automatically on every push to `main`, so origin/main IS
the live site.

**Read-only rule for this repo (hard constraint):** concurrent processes
switch branches in `D:\Pillarworks-Enterprise-Website` mid-session.
NEVER edit its working tree, never rely on the checked-out branch. Read
content via `git show origin/main:src/pages/DocsPage.tsx` (and likewise
for the truth anchors below) after a `git fetch origin main`. If the
fetch fails (offline), fall back to local refs and mark claims "as of
local origin/main".

**NO_CHANGE gate:** if neither `src/pages/DocsPage.tsx` nor any truth
anchor below changed on origin/main since the last run's recorded audit
commit (record the audited commit SHA in the report each run), emit one
line "customer docs: NO_CHANGE since <sha>" and skip this section.

**Truth anchors — cross-check every docs claim against these, all read
from origin/main of the same repo unless stated:**
1. `src/pages/PricingPage.tsx` — canonical pricing ladder (tier NAMES,
   prices, project limits, per-tier features). Docs tier tables must
   match it exactly.
2. `src/pages/app/UploadPage.tsx` — accepted upload file types and
   `maxSizeMB`. Docs must not name any format or size not present here
   (historical trap: docs claimed DWG/DXF + 500MB; reality was
   PDF/images + 100MB).
3. `src/lib/api/*.ts` — the only export/feature endpoints that exist.
   A docs claim of an export format (CSV, PDF report, API access) with
   no corresponding client function is a finding.
4. `src/pages/app/ExtractionReviewPage.tsx` + `src/lib/api/types.ts` —
   confidence-bucket thresholds and the needs-review threshold (0.85 as
   of 2026-07). Docs percentage bands must match.
5. `src/pages/SecurityPage.tsx` — the ratified honest security wording
   (post commit 97dbd30 "remove false compliance claims"). Docs
   security/trust articles must be no STRONGER than this page.
6. `pillarworks-build-mvp` backend (read-only, `git show origin/main:`)
   when a claim cannot be settled from the frontend alone.

**Claims-policy gate (feedback_pillarworks_claims_policy — apply to
every article):** flag ANY of the following unless verified in-repo this
run: accuracy percentages, "audit-grade", CAD/DWG/DXF support,
compliance certifications (SOC 2 / ISO), penetration-testing claims,
data-residency guarantees (infra is us-east-1 today; residency is
enterprise-agreement-scoped only), "trained on <X> data" claims, and
any feature the docs describe (keyboard shortcut, button, tab, setting)
that does not exist in `src/pages/app/**`.

**Output:** a "Customer docs (pillarworks.io/docs)" subsection in the
report listing each mismatch as article-id → claim → truth-anchor
citation, plus a `DOC-NN` Machine Handoff row per finding. This routine
NEVER edits DocsPage.tsx (it is product source code in a repo other
processes own) — fixes route to engineering-routine or a human via the
handoff.

## Actions

You SHOULD apply small, mechanical fixes inline (all must be idempotent):
- Footer dates that lag mtime — see the carve-out below
- One-line README files for orphan directories ("archived, do not edit"
  for archive/, pointer to summary doc for audit/)
- Typo fixes, dead-link removal

**Footer-date auto-bump carve-out (important):** only bump a footer
"Last Updated" date when the footer lags the FILE MTIME by >7 days AND
the file mtime is itself recent (within ~30 days). If the file mtime is
itself old (the document genuinely has not been edited in months),
bumping the footer would falsely signal freshness — DO NOT bump; flag
the document as stale instead. (Concrete recurring example:
`orryx-mcp-gateway/README.md` — footer 2025-01-21, mtime 2025-09-14:
do NOT bump, flag as stale.)

You MAY apply substantive doc edits when ALL of the following hold:
- No wave-* migration branch is the active branch on the affected repo
  with uncommitted work (check via repo-health summary AND a direct
  `git status --porcelain` on the target file — defer if either shows
  in-flight work)
- The change is grounded in a cited source (orryx-standards,
  orryx-audit, a current src/ file you read this run)
- The change is reversible with a single edit
- The freeze (see "Determine the single-sourcing freeze state") does
  not cover the file. READMEs are NOT covered by the freeze; only
  CLAUDE.md / AGENTS.md / *.base.md are.

You MUST NOT:
- Modify CLAUDE.md / AGENTS.md / CLAUDE.base.md / AGENTS.base.md while
  the single-sourcing freeze HOLDS (see freeze-state procedure — the
  14-day window OR unmerged wave branches keep it held; a
  completion-claiming doc does NOT lift it)
- Overwrite a complete same-day report from a concurrent run (see
  Concurrency & idempotency)
- Commit, push, or open PRs (this routine is local-only)
- Commit or revert another process's uncommitted changes
- Invent architecture, deployment status, repo state, or roadmap state
- Resolve cross-repo conflicts unilaterally (e.g., React 18 vs React 19
  between two READMEs) — flag in the report and stop

## Staleness thresholds

| Signal | Threshold | Action |
|---|---|---|
| README mtime | >90 days | flag in report |
| README mtime | >180 days | escalate as P2 in summary |
| CLAUDE.md mtime | >30 days vs. CLAUDE.base.md mtime | flag drift |
| Footer "Last Updated" vs file mtime | drift >7 days AND mtime recent (<~30d) | auto-bump footer |
| Footer "Last Updated" vs file mtime | drift >7 days AND mtime itself old | DO NOT bump; flag doc as stale |
| Elapsed roadmap quarter referenced as future | any | flag |

## Staleness escalation tracking

When the previous run's report exists, diff staleness against it. For any
README that was flagged/escalated in the prior run AND is still stale at
the same or worse threshold this run, label it "escalated N runs running"
(N = consecutive runs). This signals items that are deferred indefinitely
and need a human, not another deferral.

## Constraints

Do not invent:
- architecture (only restate what `orryx-audit/` or `src/` shows)
- deployment status (only restate what the repo-health summary shows;
  if a README's status badges contradict repo-health, flag for human
  reconciliation — do not edit the badge, that is a deployment-status
  assertion)
- repo state (read git, do not assume)
- roadmap state (only restate what dated planning docs say)
- migration-complete state (git branch/merge state overrides any doc
  claiming completion)

When uncertain whether something is current: cite the source file and
mtime in the report. Do not assert without provenance.

## Deliverables

1. `D:\reports\daily\documentation-sync-{YYYY-MM-DD}.md` (always — UNLESS
   a complete same-day report already exists, in which case write
   `documentation-sync-{YYYY-MM-DD}-verification.md` instead per the
   Concurrency rule)
2. Inline edits per "Actions" rules above (when conditions met, idempotent)
3. If edits were made: an "Applied changes" section listing every
   modified file with a one-line rationale and the source citation
4. If run in verify-only mode: a verification table (claims
   confirmed/refuted) plus any NEW findings the primary report missed

## Report structure (required sections)

1. Executive summary (3-5 bullets max) — include the explicit freeze
   verdict line with its computed unlock date
2. Documentation inventory table (one row per repo: README mtime,
   CLAUDE.md mtime, active branch, migration status)
3. Single-source pattern status — MUST include the explicit freeze-state
   computation: stub date, unlock_date (= stub date + 14d), branches
   merged y/n, verdict HOLDS/LIFTED
4. Stale README findings (per-file, with mtime, age in days, and
   conflict citation; mark "escalated N runs running" where applicable)
5. Architecture drift signals (cross-reference orryx-audit/; include any
   doc-vs-git-state contradictions, e.g. completion-claiming docs)
6. Orphan directories
7. Recommended actions (prioritised P0/P1/P2/P3)
8. Applied changes (if any) OR "No edits applied; reasons" with cited
   blockers OR "Pre-empted by concurrent run; verified correct" per file
9. Uncertainty / caveats — note if a concurrent run was detected
   (timestamps), and any foreign uncommitted git state left untouched
10. Carryover for next run — explicit list of recommendations deferred
    today, each tagged with its blocker and gate condition, so tomorrow's
    run can pick them up without re-deriving

## Machine Handoff

Append a `## Machine Handoff` table as the final section of the report so
downstream routines parse it deterministically. Stable `DOC-NN` IDs persist
across runs for the same underlying doc issue (a stale README, a doc-vs-git
contradiction, a missing stub) so the "escalated N runs running" count is
trackable. Never renumber or reuse a retired ID.

| ID | Severity | Item (1 line) | Status vs prior | Owner | Required action |
|---|---|---|---|---|---|

Severity ∈ {🔴 critical, 🟠 high, 🟡 medium}. Owner ∈ {human,
documentation-sync, memory-consolidation, <named routine>}. Rows whose fix was
applied inline this run carry Status `resolved (edited this run)`; deferred
rows carry their blocker. Use the empty-row sentinel `(none this run)` when
there is nothing to hand off. End with one line:
`STALE-DOCS-ESCALATED: <N> — <count of docs at P2+ / escalated ≥2 runs running>`.

**Self-check before finalizing (mandatory):** run
`pwsh -NoProfile -File C:\Users\alexa\.claude\hooks\validate-handoff.ps1 -File <this report path>`.
If it prints `FAIL`, fix the handoff table per the reported reason codes and
re-emit — do NOT finalize a FAILing report. A malformed table silently breaks
the downstream loop. (`SKIP not a contracted report` is acceptable — this
routine is not yet in `handoff-contract.json`.)

## Output location

Resolve `/reports/daily/...` as `D:\reports\daily\...` on Windows.
Create the directory if missing. Filename: `documentation-sync-{date}.md`
(or `documentation-sync-{date}-verification.md` in verify-only mode)
where `{date}` is today's date in `YYYY-MM-DD` format.

## When NOT to Use This Skill

- For **committing, pushing, or opening PRs** with doc changes — this routine
  is local-only (see Constraints). Branch/merge/PR work belongs to
  `r11-safe-resolver` (safe mechanical fixes incl. `lying_doc_reconcile`) or a
  human; this routine only edits the working tree in place.
- For **resolving cross-repo conflicts** (e.g. React 18 vs 19 between two
  READMEs) or **deployment-status badge contradictions** — flag for human
  reconciliation; do not edit unilaterally.
- For the **git/CI/branch-divergence source data** itself, that is produced by
  the repo-health / portfolio-summary routine — consume its beacon (gated
  above), do not re-derive the whole portfolio health picture here.
- For **persisting doc-drift findings into durable memory/risk register**,
  defer to `memory-consolidation-routine`.
- For **editing CLAUDE.md / AGENTS.md / *.base.md while the single-sourcing
  freeze HOLDS** — that is forbidden here; route base-file changes through the
  wave-migration process and `orryx-standards`.
