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


## Producer Pre-check & Exit Record (canonical — `_shared/PRODUCER_PRECHECK.md`)

> Embedded from the canonical shared contract `_shared/PRODUCER_PRECHECK.md`.
> The Input Freshness Gate above models input *age*; this models intra-day *order*,
> *catch-up*, and *change*. Skip beats stale.

**1. Producer pre-check (run FIRST, before any work).** For each REQUIRED same-day
input this routine consumes (the dated reports named in your Inputs section), stat
the expected `*-{today}.md`. If a required input is **absent** (its producer has
not run yet today), do NOT synthesize: emit the exit record below with
`exit_status: SKIP` and `skip_reason: "required input <name> not produced today"`,
and STOP. You will be picked up next window once the producer runs. (Producers /
ground-truth scanners with no required dated inputs skip this step.)

**2. Catch-up rule.** If your newest output is dated before today, you are catching
up after a dark day: produce exactly ONE run dated today; do NOT backfill missed
dates; lead the report with `catch_up: true, missed_days: N`.

**3. NO_CHANGE skip (condition-triggered / change-driven routines only).** If your
producer's input is unchanged since your last run, emit `exit_status: SKIP`,
`skip_reason: NO_CHANGE`, reuse prior findings, and STOP. (Quiet-day-aware
governance routines emit a SHORT "quiet day" report instead of skipping outright.)

**4. Structured exit record (mandatory — every run, as the LAST step).** Append ONE
line to `D:\reports\evolution\fleet-exit-log.jsonl`:
`{"routine_id":"<this routine>","run_id":"<ISO-utc>","exit_status":"OK|SKIP|ABORT|FAIL","input_freshness":"FRESH|DEGRADE|ABORT|NA","output_produced_at":"<ISO-utc-or-null>","catch_up":false,"skip_reason":null,"consecutive_failures":0}`
The `fleet-health-routine` reads this log. An `OK` row with `input_freshness:ABORT`
is the "succeeded on stale data" case — never hide it. A SKIP for input-not-ready /
NO_CHANGE / network is NOT a failure; do not increment `consecutive_failures`.

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
