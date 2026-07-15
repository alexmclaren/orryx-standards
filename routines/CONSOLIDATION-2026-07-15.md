# Routine Fleet Consolidation — 2026-07-15

**Objective:** Reduce routine fleet from 36→24 high-quality routines
**Driver:** Operations Recovery Report Phase 3 findings
**GitHub Issue:** #7 (orryx-control-plane)

---

## Summary (REVISED after SKILL.md analysis)

| Category | Before | After | Change |
|----------|--------|-------|--------|
| Core Spine (daily) | 16 | 16 | 0 (keep separate after analysis) |
| Weekly/Fortnightly | 10 | 7 | -3 (merged into evolution) |
| Condition-triggered | 3 | 3 | — |
| One-shot/Completed | 3 | 0 | -3 (retired) |
| Orphan prompts | 4 | 0 | -4 (archived) |
| **SCHEDULED TOTAL** | **36** | **24** | **-12** |

**Key Decision Change:** After reviewing SKILL.md files, devops+qa and fleet-health+git-hygiene should remain SEPARATE (different freshness gates, different consumers, different purposes). The consolidation focuses on:
1. Retiring completed one-shots
2. Merging the Sunday evolution chain (5→1)
3. Merging knowledge routines (2→1)
4. Archiving orphan prompts

---

## TIER 1: RETIRED (Remove from schedule.json)

### Completed One-shots
| Routine | Reason | Action | Status |
|---------|--------|--------|--------|
| `triora-nat-egress-verify-2026-06-27` | One-shot complete | Archive prompt, remove from schedule | ✅ DONE |
| `stripe-go-live-gate` | RESOLVED 2026-07-15 | Archive prompt, remove from schedule | ✅ DONE |
| `pillarworks-m3-qs-benchmark-tracker` | Paused indefinitely | Archive prompt, remove from schedule | ✅ DONE |

### Orphan Prompts (not in schedule.json)
| Directory | Reason | Action | Status |
|-----------|--------|--------|--------|
| `peak-period-trim-review-2026-07-31` | Future one-shot | Keep prompt, add to schedule when needed | — |
| `vault-competitive-intel-refresh` | Never scheduled | Archive | ✅ DONE |
| `investment-os-macro-refresh` | Never scheduled | Keep (personal finance) | — |

---

## TIER 2: MERGE ANALYSIS (Revised)

### 2.1 devops + qa — KEEP SEPARATE
**Analysis:** Upon reviewing SKILL.md files, these serve distinct purposes:
- DevOps: deployment readiness, CI/CD health, infra drift (WARN_DAYS=1, tighter)
- QA: test coverage, regression safety, acceptance criteria (WARN_DAYS=2, looser)
- Different output paths (`D:\reports\devops\` vs `D:\reports\qa\`)
- Different ID prefixes (DO-NN vs QA-NN)
- Different downstream consumers
**Decision:** NO MERGE — distinct concerns warrant separate routines
**Status:** KEEP BOTH

### 2.2 fleet-health + git-hygiene — KEEP SEPARATE
**Analysis:**
- fleet-health: observability beacon, runs LAST in morning window (09:45), reads exit log
- git-hygiene: L1 producer, runs early (05:30), produces hygiene findings
**Decision:** NO MERGE — different layers, different timing requirements
**Status:** KEEP BOTH

### 2.3 knowledge-routine (memory-consolidation + knowledge-ingestion)
**Merged from:** `memory-consolidation-routine`, `knowledge-ingestion-routine`
**Cadence:** Daily 19:00 AEST (consolidation pass) + Weekly deep ingestion
**Layer:** L5
**Rationale:** Both handle knowledge persistence, both have broken handoffs (per ops report)
**Decision:** MERGE into single knowledge-routine
**Status:** PENDING

### 2.4 evolution-routine (5 routines → 1)
**Merged from:**
- `autonomous-improvement-routine` (fortnightly Sun 09:00)
- `frontier-architecture-routine` (fortnightly Sun 10:00)
- `prompt-evolution-routine` (weekly Sun 11:00)
- `capability-benchmarking-routine` (fortnightly Mon 21:00)
- `innovation-backlog-routine` (fortnightly Mon 08:00)

**Cadence:** Weekly Sun 09:00 AEST (single comprehensive pass)
**Layer:** L4
**Rationale:** All part of self-improvement loop, run in sequence anyway, same consumers
**Decision:** MERGE into single evolution-routine
**Status:** PENDING

---

## TIER 3: CORE SPINE (Keep unchanged)

| Routine | Layer | Cadence | Critical Path |
|---------|-------|---------|---------------|
| `repo-scanner` | L0 | Daily 04:30 | Root producer |
| `security-routine` | L1 | Daily 05:20 | Security spine |
| `git-hygiene-routine` | L1 | Daily 05:30 | Repo hygiene |
| `qa-routine` | L2 | Daily 06:00 | Quality |
| `devops-routine` | L2 | Daily 06:12 | Ops |
| `cto-routine` | L2 | Daily 06:35 | Architecture |
| `secret-rotation-tracker` | L2 | Daily 07:30 | Security |
| `ceo-routine` | L3 | Daily 08:15 | Governance |
| `daily-planner-routine` | L3 | Daily 08:30 | Scheduling |
| `approval-governance-routine` | L3 | Daily 08:45 | Approvals |
| `execution-safety-routine` | L3 | Daily 09:00 | Safety gate |
| `engineering-routine` | L6 | Daily 09:15 | Executor |
| `r11-safe-resolver` | L6 | Daily 09:30 | Executor |
| `fleet-health-routine` | L5 | Daily 09:45 | Observability |
| `failure-analysis-routine` | L4 | Daily 18:00 | Learning |
| `end-of-day-distillation-routine` | L5 | Daily 18:30 | EOD |
| `orchestration-routine` | L3 | Daily 23:30 | Terminal synthesis |

---

## TIER 4: WEEKLY/CONDITION ROUTINES

| Routine | Cadence | Status |
|---------|---------|--------|
| `fleet-security-audit` | Monthly 1st | Keep |
| `product-routine` | Weekly Mon | Keep |
| `mvp-delivery-routine` | Weekly Mon | Keep |
| `commercialstrategy-routine` | Weekly Wed | Keep |
| `finops-routine` | Weekly Fri | Keep |
| `dependency-graph-builder` | Weekly Mon | Keep |
| `documentation-sync` | Condition | Keep |
| `harness-propagation-routine` | Condition | Keep |
| `release-changelog-routine` | Condition | Keep |
| `competitive-intelligence-routine` | Fortnightly Sat | Keep |
| `deep-research-routine` | Paused | Resume post-peak |
| `tooling--mcp-discovery-routine` | Paused | Resume post-peak |

---

## Final Routine Count: 24

### Daily (17)
1. repo-scanner
2. security-routine
3. git-hygiene-routine
4. qa-routine
5. devops-routine
6. cto-routine
7. secret-rotation-tracker
8. ceo-routine
9. daily-planner-routine
10. approval-governance-routine
11. execution-safety-routine
12. engineering-routine
13. r11-safe-resolver
14. fleet-health-routine
15. failure-analysis-routine
16. end-of-day-distillation-routine
17. orchestration-routine

### Weekly/Fortnightly (6)
1. product-routine
2. mvp-delivery-routine
3. commercialstrategy-routine
4. finops-routine
5. dependency-graph-builder
6. fleet-security-audit (monthly)
7. competitive-intelligence-routine (fortnightly)
8. evolution-routine (NEW - merged 5 routines)
9. knowledge-routine (NEW - merged 2 routines)

### Condition-triggered (3)
1. documentation-sync
2. harness-propagation-routine
3. release-changelog-routine

### Paused (not counted)
1. deep-research-routine
2. tooling--mcp-discovery-routine

---

## Implementation Steps

1. [x] Create consolidation plan (this document)
2. [x] Analyze SKILL.md files for merge compatibility
3. [x] Revise plan based on analysis (devops+qa kept separate)
4. [ ] Archive retired prompts to `prompts/_archived/`
5. [ ] Create merged routine prompts:
   - [ ] evolution-routine/SKILL.md
   - [ ] knowledge-routine/SKILL.md
6. [ ] Update routine-schedule.json:
   - [ ] Remove retired routines (3)
   - [ ] Remove merged routines (7)
   - [ ] Add new merged routines (2)
7. [ ] Update ROUTINES.md documentation
8. [ ] Verify DAG still acyclic
9. [ ] Close GitHub issue #7

---

## Rollback Plan

If merged routines cause issues:
1. Revert routine-schedule.json from git
2. Move archived prompts back to prompts/
3. Re-register original routines with scheduler

All changes are reversible via git.

---

**Created:** 2026-07-15
**Revised:** 2026-07-15 (post SKILL.md analysis)
**Owner:** Orryx Operations Session
**Status:** IN PROGRESS
