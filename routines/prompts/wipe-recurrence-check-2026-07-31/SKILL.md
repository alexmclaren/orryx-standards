---
name: wipe-recurrence-check-2026-07-31
description: One-time check tomorrow AM: did the scheduler-registry wipe recur (fleet dark)? Writes a one-line verdict.
---

One-time wipe-recurrence check. Context: on ~2026-07-20 the Claude Code scheduler-registry wiped and the whole routine fleet went dark ~3 days (rebuilt 2026-07-23). This task verifies whether that recurred overnight. It is READ-ONLY — do not modify the scheduler, any routine, or any repo. Deliverable is a short verdict file only.

Resolve today's date as YYYY-MM-DD from the system clock (Australia/Brisbane, AEST). Call it {date}.

Do these deterministic checks:
1. Count today's rows in D:\reports\evolution\fleet-exit-log.jsonl — rows whose run_id starts with {date}. A healthy morning has roughly 15+ daily-routine rows by ~10:00 AEST.
2. Stat these expected same-day producer outputs:
   - D:\reports\repo-health\portfolio-summary-{date}.md
   - D:\reports\security\security-review-{date}.md
   - D:\reports\daily\fleet-health-{date}.md (or wherever fleet-health writes)
3. Read the newest fleet-health-{date}.md if present — it is the AUTHORITATIVE fleet-health view. Note its RAN/EXPECTED tally and any DORMANT daily producers (esp. repo-scanner/security, which it flags 🔴).

Verdict logic:
- WIPE RECURRED (🔴) if: near-zero exit-log rows for {date} AND the expected producer outputs are absent AND (if present) fleet-health shows most of the fleet DORMANT. This means the registry wiped again — the app lost its scheduled tasks.
- HEALTHY (✅) if: exit-log shows the normal morning volume and portfolio-summary + security-review for {date} exist. No recurrence.
- PARTIAL/UNCLEAR (🟠) if: mixed signals (some emitted, some not) — e.g. an early-window producer-ordering race, not a wipe. Say which.

Write a short verdict to D:\reports\evolution\wipe-recurrence-check-{date}.md: the verdict line (✅/🟠/🔴), the three evidence counts/stats, and a one-line pointer to fleet-health-{date}.md as the authoritative source. If WIPE RECURRED, state plainly that the operator should re-run the scheduler-registry rebuild procedure (memory: "Scheduler registry wipe" — create-then-git-restore, ~51 tasks). Do NOT attempt any rebuild yourself.

This is a one-time task; it auto-disables after this run.