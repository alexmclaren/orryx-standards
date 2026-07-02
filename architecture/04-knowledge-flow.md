# 04 — Knowledge Flow & Writeback Framework

Nothing valuable should terminate inside a conversation, a report nobody re-reads, or a
worktree nobody merges. Audit of every path knowledge takes today, and the target contract.

## Current flow — with the four leaks marked

```mermaid
flowchart TD
  classDef leak fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
  classDef ok fill:#dcfce7,stroke:#16a34a,color:#14532d
  classDef partial fill:#fef9c3,stroke:#ca8a04,color:#713f12

  RUN["Routine runs (33/day-week)"]:::ok --> REP["Dated report in D:\reports"]:::ok
  REP --> SIB["Sibling routines (same-day consume, freshness-gated)"]:::ok
  REP --> EOD["eod-distillation → failure-analysis → memory-consolidation"]:::ok
  EOD --> DEC["DECISIONS.md append-only + learning section"]:::ok
  RUN --> ANCHOR["Routine memory anchors (vault 10-Operator-Memory/reference_*)"]:::ok

  REP -.->|"LEAK 1: 1,140 files, junction display only — never distilled to atomic notes"| VAULT["Vault"]:::leak
  RUN -.->|"LEAK 2: writeMemory → Pinecone (does not exist)"| PINE["Phantom vector memory"]:::leak
  KI["knowledge-ingestion (weekly)"] -.->|"LEAK 3: knowledge-index.json stale since 05-23"| KIDX["Broken index"]:::leak
  SESS["Interactive Claude sessions (the majority of real engineering)"] -.->|"LEAK 4: learnings stay in transcripts unless ce-compound manually invoked"| GONE["Lost in conversation"]:::leak

  PROMPTS["prompt-evolution edits"]:::partial -.->|"unversioned SKILL.md — history lost"| GONE
```

## State-file entity model (what exists, who writes it)

```mermaid
erDiagram
  GOVERNANCE_DECISIONS ||--o{ CEO_ESCALATIONS : "resolves/references"
  CEO_ESCALATIONS ||--o{ DECISIONS_MD : "consolidated into (nightly)"
  APPROVAL_SUMMARY ||--o{ EXECUTION_QUEUE : "posts safelist items"
  EXECUTION_QUEUE ||--o| R11 : "drained by (CURRENTLY NEVER - not scheduled)"
  HUMAN_ACTIONS_QUEUE }o--|| HUMAN : "closed only by"
  DECISIONS_MD ||--o{ VAULT_ADR : "should generate (only 1 exists)"
  GOVERNANCE_DECISIONS {
    string id "DEC-H1..H8, DEC-PRICING — CANONICAL"
    string status
    string writer "human-ratified"
  }
  DECISIONS_MD {
    string writer "memory-consolidation 19:00"
    string format "append-only + .bak"
  }
  CEO_ESCALATIONS {
    string id "ESC-CEO-001..030, 9 open"
    string writer "ceo-routine"
  }
  HUMAN_ACTIONS_QUEUE {
    string id "HA-NNN, 8 open"
    string trap "MULTI-WRITER (known)"
  }
```

**Duplicate-surface ruling:** `governance-decisions.json` stays canonical for *decisions*;
`ceo-escalations.json` canonical for *escalations*; `queue.yaml` canonical for *human actions*
with **approval-governance as sole writer**; `DECISIONS.md` and vault ADR notes become
*generated views*. Anything else is a bug.

## The writeback contract (target)

A unit of work — routine run, PR, interactive session — is not DONE until:

| Question | Written to |
|---|---|
| What was decided + rationale? | governance-decisions.json → generated ADR note in vault `40-ADRs/` |
| What durable trap/lesson was learned? | routine anchor (`reference_*`) or repo `docs/solutions/` (ce-compound) |
| What changed in project state? | repo STATUS.md + vault `30-Projects/` junction (auto-visible) |
| What future work was created? | innovation-backlog / HA queue / execution-queue (one of, never zero) |
| What prompt improved? | **versioned** `routines/prompts/` via PR (never direct SKILL.md edit) |

Enforcement is cheap: **fleet-health already validates report existence — extend it to
validate writeback existence** (e.g. memory-consolidation ran but DECISIONS.md mtime didn't
change = semantic failure; knowledge-ingestion ran but index untouched = the exact bug live
today, undetected for 40 days).

## Fix list

1. **Delete CLAUDE.base.md §13 (Pinecone)** — replace with the file-based contract above.
   A harness that mandates writes to nonexistent infra trains agents to ignore the harness.
2. **Repair or fold knowledge-ingestion** — if the index adds nothing over memory-consolidation
   + MEMORY.md, retire it (YAGNI); if it stays, fleet-health checks its index mtime.
3. **Session-end writeback hook** — the ce-compound skill exists; make it a Stop-hook nudge in
   interactive sessions ("durable learning this session? → docs/solutions") instead of relying
   on memory.
4. **Distillation, not mirroring** — don't copy 1,140 reports into the vault. The nightly
   memory-consolidation already distils; point it at generating vault ADR/lesson notes from
   its Section-0 delta (one small prompt change).

---
**Explanation/Implementation:** above. **Evolution:** revisit when Vectorize (DEC-D17) lands —
the file layer stays the source, vectors become an index over it. **Obsidian:**
`30-Projects/orryx-standards-architecture/04-knowledge-flow.md`. **GitHub:** `orryx-standards/architecture/04-knowledge-flow.md`.
**Auto-update:** fleet-health writeback checks make drift self-announcing; doc hand-edited.
