---
description: Enter the canonical PLAN MODE before implementation
argument-hint: "[what you want to build]"
---

# /plan — canonical plan mode

Produce a structured plan per `CLAUDE.base.md §1.1 PLAN MODE` **before** writing
any code. Do not begin implementation in this turn.

## Task

$ARGUMENTS

## Output the §1.1 PLAN MODE structure

1. **Objective**
2. **Current State (Reality Check)** — verify against the running system, not docs (§0.4)
3. **Target State**
4. **Gaps Identified**
5. **Approach Options** (if more than one is viable)
6. **Chosen Approach**
7. **Step-by-Step Execution Plan**
8. **Risks**
9. **Acceptance Criteria** — how DONE is proven and verified (§0.3)
10. **Autonomy Level (L0–L3)** — default L2 (§2)

If a richer planning pass is warranted (multi-step feature, architectural
choice), prefer the `ce-plan` skill or in-harness plan mode. This command is the
lightweight, always-available entry point that guarantees §1.1 is honored.
