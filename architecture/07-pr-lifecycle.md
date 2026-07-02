# 07 — PR Lifecycle: Current vs Target

## Current (the dead end)

```mermaid
sequenceDiagram
  participant P as daily-planner
  participant E as engineering-routine
  participant W as isolated worktree
  participant H as Human
  participant G as GitHub
  P->>E: highest-leverage task
  E->>W: implement + test + verify (Ralph ≤5)
  E->>E: ENG-NN handoff in report
  Note over W: STOPS HERE. Never pushed.<br/>11 stranded _*-wt dirs at D:\ root
  H-->>E: (maybe) reads report days later
  H->>W: manually inspect, push, open PR
  H->>G: review own push, merge
  Note over H: Human does 100% of PR administration
```

## Target

```mermaid
sequenceDiagram
  autonumber
  participant PL as Planner (daily-plan)
  participant E as engineering-routine
  participant G as GitHub
  participant CI as Actions CI
  participant R1 as Self-review (ce-code-review)
  participant R2 as Second model (codex / opus)
  participant S as Security scan
  participant D as Docs+writeback agent
  participant H as Human
  PL->>E: approved task (execution-safety = GO)
  E->>G: push routine/eng-{date}-{slug} + open DRAFT PR
  G->>CI: lint, types, tests, secret-scan (existing gates)
  E->>R1: self-review vs quality gates §5
  R1->>R2: independent review (different model — catches self-blindness)
  R2->>S: security pass (PHI/auth/payment paths → auto-flag)
  S->>D: CHANGELOG draft + docs delta + ADR stub if decision made
  D->>G: PR comment: verdict, risk class, breaking changes, confidence
  alt confidence ≥ 0.85 AND class ∈ {docs, test-only, deps-patch} AND CI green
    G->>G: label auto-merge-eligible (Phase 2: actually merge)
    G-->>H: FYI in daily digest
  else anything else
    G->>H: digest entry: risk, decision required, recommendation
    H->>G: merge / request-changes (30-second judgement)
  end
  G->>CI: merge → existing auto-deploy (EKS / S3+CF / ECS)
  CI->>D: post-merge retro note → failure-analysis input
```

## Branch model

```mermaid
gitGraph
  commit id: "main"
  branch routine/eng-2026-07-03-fix-x
  commit id: "impl + tests"
  commit id: "self-review fixes"
  checkout main
  merge routine/eng-2026-07-03-fix-x id: "human or auto-merge"
  branch routine/deps-patch
  commit id: "dependabot patch"
  checkout main
  merge routine/deps-patch id: "auto-merge (green CI)"
```

`routine/*` namespace = agent-created, branch protection unchanged on `main`, worktrees
deleted after PR opens (kills the D:\ root litter class at the source).

## Auto-merge decision tree (Phase 2 — after ≥4 weeks of verdict data)

```mermaid
flowchart TD
  A[PR ready] --> B{CI green + secret scan clean?}
  B -->|no| H[Human, RED]
  B -->|yes| C{Touches PHI / auth / payment / infra / pricing?}
  C -->|yes| H2[Human, ORANGE - always]
  C -->|no| D{Class: docs / test-only / deps-patch?}
  D -->|no| E{Both AI reviews approve, confidence ≥ 0.85?}
  D -->|yes| E
  E -->|no| H3[Human, YELLOW - with recommendation]
  E -->|yes| F{Class allows?}
  F -->|docs/test/deps-patch| M[AUTO-MERGE + digest FYI]
  F -->|code| H4[Human, GREEN one-click - recommend merge]
```

**Threshold policy:** start with auto-merge OFF; the chain only *labels*. After a month,
measure agreement rate between AI verdict and human decision per class; enable auto-merge for
any class ≥ 98% agreement. Confidence numbers are self-reported and gameable — **the gate is
the measured agreement rate, not the model's own confidence.**

## CI/CD gate inventory (existing, reused as-is)

```mermaid
flowchart LR
  PR[PR] --> L[lint/types] --> T[tests] --> SS[secret-scan-fulltree] --> CQ[CodeQL where enabled] --> M{merge}
  M -->|pillarworks main| EKS[EKS auto-deploy]
  M -->|frontends| S3[S3+CloudFront]
  M -->|triora| ECS[ECS task-def]
```

Known trap carried forward: pre-deploy tests that run without db/redis (Triora #114 class —
unit-green ≠ gate-green). The PR chain's security/review stages must check *which* gates ran,
not just that they're green.

---
**Explanation/Implementation:** Phase 1 (draft PRs + chain, no auto-merge) = ~2 sessions of
work: extend engineering-routine SKILL.md (push+PR), one reusable `pr-review-chain` workflow
(ce-code-review mode:agent + codex rescue as second model). **Evolution:** Phase 2 auto-merge
per measured agreement. **Obsidian:** `30-Projects/orryx-standards-architecture/07-pr-lifecycle.md`.
**GitHub:** `orryx-standards/architecture/07-pr-lifecycle.md`. **Auto-update:** hand-edit;
agreement-rate table appended monthly by capability-benchmarking.
