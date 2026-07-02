# 02 — Target-State Architecture

The same fleet, with the action half unthrottled and every loop closed. Design principle:
**human judgement only, never human administration** — the human touches decisions, not
mechanics.

## C4 context

```mermaid
C4Context
  title Orryx Autonomous Development OS — target state
  Person(alex, "Alex", "Judgement: merge risk, spend, strategy. ~30 min/day")
  System(fleet, "Routine Fleet", "33 scheduled agents, L0-L6 DAG, PRODUCER_PRECHECK")
  System(exec, "Execution Layer", "engineering-routine + r11 + PR pipeline: branch, draft PR, AI review chain")
  System(know, "Knowledge Layer", "reports -> distilled atomic notes -> vault; versioned prompts; DECISIONS/ADRs")
  System(dash, "Mission Control", "orryx-mission-control: one pane — fleet health, PRs, HA queue, costs")
  System_Ext(gh, "GitHub", "PRs, Actions CI, branch protection")
  System_Ext(cloud, "AWS + Cloudflare", "EKS, ECS, S3/CF, Workers")
  Rel(fleet, exec, "approved work items (execution-queue)")
  Rel(exec, gh, "draft PRs + AI review verdicts")
  Rel(gh, cloud, "merge -> auto-deploy")
  Rel(fleet, know, "every routine ends with writeback")
  Rel(know, fleet, "next-day context (memory, traps, ADRs)")
  Rel(dash, alex, "one daily digest: risk-ranked decisions only")
  Rel(alex, gh, "merge/deploy approvals (bundled)")
```

## Target flow

```mermaid
flowchart TD
  classDef new fill:#dbeafe,stroke:#2563eb,color:#1e3a8a
  classDef auto fill:#dcfce7,stroke:#16a34a,color:#14532d
  classDef human fill:#ffedd5,stroke:#ea580c,color:#7c2d12

  SENSE["Sensing fleet (L0-L2) — unchanged, model-tiered (cheap models)"]:::auto
  GOV["Governance spine (L3) — unchanged"]:::auto
  PLAN["daily-plan + execution-queue"]:::auto
  ENG["engineering-routine: N changes/day, pushes routine/eng-* branches, opens DRAFT PRs"]:::new
  R11["r11-safe-resolver LIVE in scheduler — burns safelist queue"]:::new
  PRCHAIN["AI PR chain: self-review → second-model review → security scan → docs update → risk summary"]:::new
  DIGEST["Single daily decision digest: risk-ranked, confidence-scored, one-click actions"]:::new
  HUMAN["Alex — judgement only"]:::human
  MERGE["Merge (auto-merge for low-risk classes: docs, deps-patch, test-only)"]:::new
  DEPLOY["Existing CI/CD auto-deploy"]:::auto
  RETRO["Post-merge retro → failure-analysis input"]:::new
  WRITEBACK["Writeback distiller: every report/PR/session → atomic vault notes + ADRs + prompt-library"]:::new
  VAULT["Vault: 30-Projects wired, ADR log, prompt library, lessons DB"]:::new
  MEM["File-based memory (replaces phantom Pinecone): docs/solutions + operator-memory + DECISIONS"]:::new

  SENSE --> GOV --> PLAN --> ENG --> PRCHAIN --> DIGEST --> HUMAN --> MERGE --> DEPLOY --> RETRO
  PLAN --> R11
  PRCHAIN -->|"confidence ≥ threshold + low-risk class"| MERGE
  RETRO --> WRITEBACK --> VAULT --> MEM --> SENSE
  GOV --> DIGEST
```

## The five structural changes vs current state

1. **Executor unthrottling** — engineering-routine pushes branches and opens *draft* PRs
   (reversible, reviewable; strictly safer than today's stranded worktrees because work
   becomes visible and CI-tested). r11 restored to the scheduler. Merge stays human until
   confidence data justifies auto-merge classes (07-pr-lifecycle.md).
2. **AI PR chain** — nothing reaches the human without self-review, second-model review,
   security scan, and a risk-ranked summary. Human reads verdicts, not diffs (unless RED).
3. **One decision surface** — governance-decisions.json canonical; DECISIONS.md, vault ADRs,
   dashboard views all *generated* from it + ceo-escalations. queue.yaml becomes single-writer
   (approval-governance owns it; humans resolve via dashboard, not hand-edits).
4. **Writeback everywhere** — a routine's run isn't DONE until its knowledge writeback exists
   (04-knowledge-flow.md contract). Phantom Pinecone section deleted from CLAUDE.base.md,
   replaced with the file-based contract that already half-exists.
5. **Model tiering** — L0/L1 mechanical scans on cheap models, L2 on mid, L3/L4 synthesis on
   frontier. (03-fleet-dag.md audit table has per-routine assignments.)

---
**Explanation:** above. **Implementation:** sequenced in 10-roadmap.md (changes 1–2 are weeks 1–4).
**Evolution:** revisit when auto-merge classes go live and when Vectorize (DEC-D17) is un-deferred.
**Obsidian:** `30-Projects/orryx-standards-architecture/02-system-map-future.md`.
**GitHub:** `orryx-standards/architecture/02-system-map-future.md`.
**Auto-update:** hand-maintained; capability-benchmarking-routine reviews it fortnightly against reality and proposes diffs.
