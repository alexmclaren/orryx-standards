---
description: Verify a change against the real system, not assumptions
argument-hint: "[what to verify]"
---

# /verify — production-reality verification

Prove a change actually works by exercising the **real system** (§0.4), not by
re-reading the diff. Honors `CLAUDE.base.md §12 Definition of Done`.

## What to verify

$ARGUMENTS

## Protocol

1. Restate the acceptance criteria the change was meant to satisfy (§0.3).
2. For each criterion, run the real check and **observe the output**:
   - Tests: run them, paste the result (pass/fail counts).
   - API/endpoint: hit it, show the response.
   - UI: load it, confirm the behavior (use the preview/run tooling).
   - Data/migration: query the actual table, don't trust the migration log.
3. Apply the §5 quality gates (lint, types, tests, coverage, security, secrets).
4. Report faithfully: if a check fails or was skipped, say so with the evidence.
   Do not declare DONE on assumptions.

For app-level "run it and show me it works", prefer the `verify` / `run` global
skills. This command is the repo-local guarantee that §12 is met before claiming done.
