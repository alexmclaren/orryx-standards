# 01 — Current-State System Map

As-built on 2026-07-02. Sources: live scheduler (30 fleet routines), `routines/routine-schedule.json`
(36 canonical), `D:\state`, `D:\reports` (1,140 files), `D:\Vault\main`, 24 repos.

```mermaid
flowchart TD
  classDef gap fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
  classDef human fill:#ffedd5,stroke:#ea580c,color:#7c2d12
  classDef auto fill:#dcfce7,stroke:#16a34a,color:#14532d
  classDef dead fill:#fee2e2,stroke:#dc2626,stroke-dasharray: 5 5,color:#7f1d1d

  GT["Ground truth: 24 repos · AWS 490004631560 · Cloudflare · GitHub"]:::auto

  subgraph FLEET["Scheduled fleet — 04:30→23:30 AEST daily spine"]
    L0["L0 scanners: repo-scanner · fleet-security-audit · deep-research · competitive-intel"]:::auto
    L1["L1 producers: security · git-hygiene · doc-sync · dep-graph · harness-propagation"]:::auto
    L2["L2 consumers: qa · devops · cto · product · finops · secret-rotation · release · mvp"]:::auto
    L3["L3 governance: ceo → daily-planner → approval-governance → execution-safety"]:::auto
    ORCH["orchestration 23:30 → master-operating-plan(N) → seeds planner(N+1)"]:::auto
    EVO["L4/L5 evolution: failure-analysis · eod · memory-consolidation · prompt-evolution · capability-benchmark"]:::auto
  end

  REPORTS[("D:\reports — 1,140 dated md files")]:::auto
  STATE[("D:\state — DECISIONS.md · governance-decisions.json · ceo-escalations.json · execution-queue · sqlite")]:::auto
  QUEUE["human-actions queue.yaml (orryx-control-plane) — 8 open HA items"]:::human

  ENG["engineering-routine 09:15 — ONE change/day, isolated worktree"]:::auto
  WT["work stranded in _*-wt worktrees — never pushed, no PR"]:::dead
  R11["r11-safe-resolver — in canonical DAG, ABSENT from live scheduler"]:::gap

  HUMAN["Human (Alex) — reads reports · closes HA queue · merges PRs · rotates secrets · deploys"]:::human
  GH["GitHub PRs + Actions (per-repo CI: ci-cd, secret-scan, mcp-validation-gate, proof-gate)"]:::auto
  DEPLOY["Deploys: EKS (pillarworks) · S3/CF (frontends) · ECS (triora)"]:::human

  VAULT["Obsidian vault: 00-Personal · 10-Operator-Memory · 20-Fleet(junction→reports)"]:::auto
  V30["30-Projects layer — EMPTY (repo docs never junctioned in)"]:::dead
  PINE["CLAUDE.base.md §13 writeMemory → Pinecone — DOES NOT EXIST (DEC-D17 deferred Vectorize)"]:::dead
  KIDX["knowledge-index.json — STALE since 2026-05-23 (40 days) while routine keeps running"]:::gap
  PROMPTS["48 routine prompts in C:\Users\alexa\.claude\scheduled-tasks — NOT version controlled"]:::gap

  GT --> L0 --> L1 --> L2 --> L3
  L3 --> REPORTS
  L0 & L1 & L2 --> REPORTS
  L3 --> QUEUE
  L3 --> ENG --> WT
  L3 -.->|gate exists, executor missing| R11
  EVO --> REPORTS
  EVO --> STATE
  ORCH --> REPORTS
  REPORTS --> ORCH
  REPORTS -->|junction, display only| VAULT
  QUEUE --> HUMAN
  REPORTS -->|"daily reading (manual pull)"| HUMAN
  HUMAN --> GH --> DEPLOY
  WT -.->|"only if human notices report"| GH
  EVO -.-> PINE
  EVO -.-> KIDX
  EVO -->|edits unversioned| PROMPTS
  VAULT -.-> V30
```

## What the map says

**The observation half of the loop is excellent; the action half is throttled to near-zero.**
33 routines produce intelligence daily with a real dependency DAG, freshness gates
(PRODUCER_PRECHECK), circuit breakers, and an observability beacon (fleet-health). That is
genuinely ahead of most internal agent platforms. But everything converges on one human:
reports → HA queue → Alex → manual PR/merge/deploy/rotation. The fleet is ~90% sensing,
~10% acting.

### Missing links (red)
1. **r11-safe-resolver is not in the live scheduler.** The whole L3 governance spine
   (approval-governance posts `execution-queue/pending/*.json`, execution-safety gates it)
   terminates in an executor that never fires. The safelist pipeline is a bridge to nowhere.
2. **knowledge-index.json stale 40 days** while knowledge-ingestion-routine runs weekly —
   the routine writes its report but no longer maintains its index. Silent semantic failure
   (exactly the class fleet-health was built to catch, but it checks report *existence*, not
   index writeback).
3. **Prompts unversioned.** prompt-evolution-routine mutates 48 SKILL.md files with no git
   history, no diff review, no rollback. The fleet's actual behaviour is config that can drift
   invisibly.

### Dead ends (dashed red)
4. **Pinecone memory (CLAUDE.base.md §13).** Every `writeMemory` the harness mandates goes
   nowhere — DEC-D17 deferred the vector store. The harness commands agents to write to
   infrastructure that doesn't exist.
5. **engineering-routine worktrees.** Its one-change-per-day lands in an isolated worktree,
   never pushed, never PR'd. 11 `_*-wt` directories at D:\ root are stranded work products.
6. **Vault 30-Projects layer empty** — repo docs were meant to junction in; never wired.

### Duplicate paths / unnecessary complexity
7. **Five decision surfaces:** `DECISIONS.md`, `governance-decisions.json`,
   `ceo-escalations.json`, `queue.yaml`, vault DEC-* notes. Multi-writer trap already bitten
   (queue.yaml). One should be canonical (governance-decisions.json), the rest generated.
8. **Schedule drift:** live scheduler ≠ routine-schedule.json (see 03-fleet-dag.md drift
   table). Phase F re-timing pending; qa/devops/cto currently fire *before* their canonical
   slots, increasing SKIP/stale-input risk.

### Manual choke points (orange) — detailed in 06-human-intervention-heatmap.md
Report consumption, HA queue closure, all PR review/merge, all deploys, all secret rotations,
release tagging, pricing, vault schema ratification.

---
**Explanation:** above. **Implementation:** gaps 1–6 are the roadmap's quick wins (10-roadmap.md).
**Evolution:** regenerate when routine-schedule.json or the executor model changes.
**Obsidian:** `30-Projects/orryx-standards-architecture/01-system-map-current.md` (junction).
**GitHub:** `orryx-standards/architecture/01-system-map-current.md`.
**Auto-update:** documentation-sync flags drift when named paths/routines disappear; hand-edit on architecture change.
