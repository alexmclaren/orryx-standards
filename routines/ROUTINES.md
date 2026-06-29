# Orryx Routine Fleet — Schedule & Dependency Map

**Version:** 1.0 · **Created:** 2026-06-28 · **Timezone:** AEST (UTC+10)
**Machine source of truth:** [`routine-schedule.json`](routine-schedule.json) — the live scheduler is aligned to that file, not the reverse.

> This document is the canonical human-readable map of the scheduled-routine fleet:
> the producer→consumer DAG, the daily timeline, cadence rationale, and the
> architectural decisions behind them. It was produced from external research on
> autonomous-agent-harness best practice + a full handoff audit + a reconciled
> three-persona review (dependency architect / SRE reliability / cost skeptic).

---

## 1. The ordering model (read this first)

Wall-clock cron staggers give the *correct order on a normal day*. **Correctness does
not rely on the clock.** Every consumer runs a **producer pre-check** as its first
step (see [`_shared/PRODUCER_PRECHECK.md`](../../../scheduled-tasks/_shared/PRODUCER_PRECHECK.md)):
if its required same-day input is absent, it **SKIPs** rather than consuming stale or
older data. This closes the gap the freshness gate can't see (the gate models *days*;
the pre-check models *intra-day order*) and makes a closed-laptop catch-up launch
drain producer→consumer instead of thundering.

Three disciplines back this (all in the shared gate):
- **Producer pre-check** — skip if required same-day input missing.
- **Catch-up rule** — after a dark day, run ONCE dated today; never backfill missed dates.
- **NO_CHANGE pre-check** — skip if the producer's output is unchanged since last run (halves spend on quiet days).

---

## 2. Dependency DAG (producer → consumer)

```
L0 root producers (scan ground truth):
  repo-scanner ── portfolio-summary ──┐
  fleet-security-audit (monthly) ──────┤
  deep-research (weekly) ──┐           │
  competitive-intelligence (weekly) ─┐ │
                                     │ │
L1 synthesis producers:             │ │
  dependency-graph-builder (wk) ◄────┼─┤
  documentation-sync (cond) ◄────────┼─┤
  security-routine ◄──────────────────┘ │  ── security-review ──┐
  git-hygiene-routine ◄─────────────────┘                       │
  harness-propagation (cond, independent)                       │
                                                                │
L2 specialised consumers:                                       │
  qa ◄── security-review, dep-analysis ◄──────────────────────┤
  devops ◄── security-review ◄─────────────────────────────────┤
  cto ◄── security, qa, devops, dep-analysis                    │
  product (wk) ◄── cto                                          │
  commercialstrategy (wk) ◄── product                          │
  secret-rotation-tracker ◄── security-review ◄────────────────┘
  finops (wk), release-changelog (cond), mvp-delivery (wk)

L3 governance synthesizers:
  ceo ◄── full L2 cohort
  daily-planner ◄── master-operating-plan(N-1)   [see ADR §5]
  approval-governance ◄── ceo, daily-planner  ── posts execution-queue ──► r11
  execution-safety ◄── ceo, approval, security

L6 executors (gated):
  engineering ◄── execution-safety, daily-plan
  r11-safe-resolver ◄── execution-safety (non-HALT) + execution-queue non-empty

L4/L5 evening + meta:
  failure-analysis ──► (MUST precede) ──► memory-consolidation
  end-of-day-distillation ◄── ceo
  orchestration (23:30) ◄── full same-day cohort ──► seeds daily-planner(N+1)

L5 observability:
  fleet-health (09:45, runs LAST) ◄── fleet-exit-log + fleet-expectations
```

---

## 3. Daily timeline (AEST)

| Time | Routine | Layer | Depends on (must be same-day fresh) |
|---|---|---|---|
| 04:30 | repo-scanner | L0 | — |
| 05:20 | security-routine | L1 | portfolio-summary |
| 05:30 | git-hygiene-routine | L1 | — |
| 05:45 | harness-propagation (cond) | L1 | — (NO_CHANGE skip) |
| 05:00 | documentation-sync (cond) | L1 | portfolio-summary (NO_CHANGE skip) |
| 06:00 | qa-routine | L2 | security-review |
| 06:12 | devops-routine | L2 | security-review |
| 06:35 | cto-routine | L2 | security, qa, devops |
| 07:20 | release-changelog (cond) | L2 | — (NO_CHANGE skip) |
| 07:30 | secret-rotation-tracker | L2 | security-review |
| 08:15 | ceo-routine | L3 | full L2 cohort |
| 08:30 | daily-planner | L3 | master-operating-plan(**N-1**) |
| 08:45 | approval-governance | L3 | ceo, daily-planner → posts execution-queue |
| 09:00 | execution-safety | L3 | ceo, approval, security |
| 09:15 | engineering | L6 | execution-safety, daily-plan (NO_CHANGE skip) |
| 09:30 | r11-safe-resolver | L6 | execution-safety = non-HALT + queue non-empty (else SKIP) |
| 09:45 | **fleet-health** | L5 | exit-log (runs LAST) |
| 18:00 | failure-analysis | L4 | eod-summary(N-1) — **before memory-consolidation** |
| 18:30 | end-of-day-distillation | L5 | ceo-summary |
| 19:00 | memory-consolidation | L5 | failure-analysis, eod-summary |
| 23:30 | orchestration | L3 | full same-day cohort → seeds N+1 planner |

**Critical path (bounds the morning):** repo-scanner → security → qa → cto → ceo → approval → execution-safety.
**Parallel-safe:** the L0 producers; git-hygiene ∥ security (both only need repo-scanner); secret-rotation ∥ finops ∥ release-changelog after the spine.

---

## 4. Weekly / fortnightly / monthly placement

| Routine | Cadence | When | Why not daily |
|---|---|---|---|
| product-routine | weekly | Mon 06:50 | feature state moves at sprint cadence |
| mvp-delivery-routine | weekly | Mon 06:30 | MVP scope doesn't shift daily |
| dependency-graph-builder | weekly | Mon 05:00 | graph changes only on package bumps |
| innovation-backlog | fortnightly | Mon 08:00 | idea gen outpaces solo execution capacity |
| commercialstrategy | weekly | Wed 07:00 | strategy isn't a daily signal |
| finops | weekly | Fri 07:00 | cost deltas are weekly; runaway caught by devops/billing alert |
| competitive-intelligence | weekly | Sat 08:00 | external scan |
| deep-research | weekly | Sun 07:00 | research has a multi-week half-life |
| knowledge-ingestion | weekly | Sun 08:00 | only meaningful when new docs arrive |
| **Sun evolution chain** | — | — | hard order: AI 09:00 → frontier 10:00 → prompt-evolution 11:00 |
| autonomous-improvement | fortnightly | Sun (wk B) 09:00 | needs ≥2wk of failure data |
| frontier-architecture | fortnightly | Sun (wk B) 10:00 | landscape doesn't shift weekly |
| prompt-evolution | weekly | Sun 11:00 | after the chain |
| capability-benchmarking | fortnightly | Mon 21:00 | scorecard is a fortnightly trend |
| tooling-mcp-discovery | weekly | Tue 21:00 | operationalises frontier patterns |
| fleet-security-audit | monthly | 1st 03:00 | org-wide sweep; leads the day it runs |

**Condition-triggered (cheap daily poll, NO_CHANGE skip):** documentation-sync, harness-propagation, release-changelog.
**Retired:** deep-research daily-lightweight (Sun deep + Sat competitive-intel cover it).

---

## 5. ADR: the daily-planner ↔ orchestration cycle

**Problem:** daily-planner consumed orchestration's `master-operating-plan` AND orchestration consumed the `daily-plan` — a cycle; and the spec called planner "layered below orchestration."

**Decision: temporal split.** orchestration runs **night-of (N, 23:30)** over the full same-day cohort and is the terminal synthesis; it **seeds the next morning**. daily-planner (**N+1, 08:30**) consumes the **prior-night** `master-operating-plan(N)` — a finished, stable artifact never written while read. The edge is one-directional across days:

```
producers(N) → orchestration(N, 23:30) → daily-planner(N+1, 08:30) → executors(N+1)
```

**Rejected:** moving orchestration to morning — it would run before its same-day inputs exist, re-introducing the historical "spine-gap" race. The ~9h overnight synthesis lag is negligible for a fleet whose binding constraint is human-closure latency measured in days.

**Cost:** daily-planner must assert `master-operating-plan` age ≤ 1 day in its pre-check and escalate a cadence-gap if orchestration missed a night.

---

## 6. Persona reconciliation (how this schedule was decided)

- **Dependency architect:** resolved the cycle (temporal split); insisted correctness rest on start-after/pre-checks not minutes; flagged failure-analysis-before-memory and r11-behind-execution-safety.
- **SRE reliability:** catch-up rule, producer pre-check (skip-not-stale), fleet-health beacon + structured exit records, circuit-breaker convention, SKILL.md-clobber-safe re-register.
- **Cost skeptic:** cut ~26 daily → right-sized; downgrade strategic/evolution routines; condition-trigger the change-driven ones.
- **Reconciled disagreement:** skeptic wanted to retire ceo + approval-governance as daily; architect/reliability wanted the governance spine daily. **Verdict:** keep daily but **quiet-day-aware** (short output when producers skipped). Net daily = **18** (from ~26), reversible per-routine by editing the cron.

---

## 7. Changing the schedule

1. Edit [`routine-schedule.json`](routine-schedule.json) (source of truth) + this doc.
2. Re-validate it's an acyclic DAG (no cycles, deps resolve, inputs have producers).
3. Re-register affected routines with the scheduler **using the clobber-safe procedure** (back up `scheduled-tasks/` first; ideally register a thin pointer prompt so the spec SKILL.md is never overwritten).
4. The `fleet-health-routine` reads [`_shared/fleet-expectations.json`](../../../scheduled-tasks/_shared/fleet-expectations.json) to know what *should* run — keep it in sync with this file.
