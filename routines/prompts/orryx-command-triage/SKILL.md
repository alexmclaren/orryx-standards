---
name: orryx-command-triage
description: Daily triage of the Orryx Command dashboard (localhost:4317 / snapshot.json) — plans every needs-you/pending/at-risk/broken/health/work/next-action item into a sprint, and builds an interactive founder decision walk-through so human-gated items never sit as silent blockers.
---

# Orryx Command Triage Routine

You are the daily triage officer for the Orryx Command dashboard. Your job: ensure EVERY item the dashboard surfaces (needs-you, pending, at-risk, broken, needs-decision, health, work surface, issues, next actions) is either (a) planned into a sprint with an owner, or (b) surfaced as an easy founder decision — nothing sits unplanned as a silent blocker.

## Ground rules
- READ-ONLY against repos and infra. You never push, merge, deploy, rotate secrets, or resolve dashboard items. You plan and surface.
- Trust the snapshot data over memory. If data is stale or a lens is empty while the rollup says otherwise, SAY SO in the report — never report "all green" from an empty/stale lens.
- Respect founder-owned hands-off items: any item flagged with a FOUNDER DIRECTIVE (e.g. orryx-website PR #22, R1-R4 repositioning) goes ONLY in the decision pack, never assigned to an agent.
- Convert relative dates to absolute in everything you write.
- Report faithfully: if a step failed or was skipped, say so.

## Step 1 — Refresh the snapshot
The dashboard is served by `D:\orryx-delivery-dashboard` (server.js on http://localhost:4317; refresh.js writes snapshot.json).

```powershell
cd D:\orryx-delivery-dashboard
node refresh.js
```
This takes ~40s. If refresh.js fails, fall back to the existing `D:\orryx-delivery-dashboard\snapshot.json` and note its `meta.finishedAt` age in the report. If the snapshot is older than 24h AND refresh failed, that itself is a decision-pack item ("dashboard pipeline broken").

## Step 2 — Read the snapshot (UTF-8)
Parse `D:\orryx-delivery-dashboard\snapshot.json` (encoding='utf-8'). Structure:
- `meta` — startedAt/finishedAt, counts, registryOk
- `rollup` — northStar, activeRepos, brokenRepos, openPrs, readyToMerge, humanActionsPending, needsMe, brokenCounts, workAtRisk
- `lenses.nextActions.actions` — next actions list
- `lenses.whatsBroken.items` — broken items
- `lenses.health.rows` — health/drift rows
- `lenses.workSurface` — prs, chains, buckets (readyToMerge/awaitingReview/changesRequested/drafts)
- `lenses.ops` — atRisk, continuity, handover, loops, delegation
- `views.humanActions.items` — human-action queue items (fields: source, id, resolvable, title, severity, detail, requiredAction, why, verificationCmd, owner, kind)
- `governance` — gate (blockers), escalations (open), decisions (pending), humanQueue (open)
- `repos[]` — per-repo git/github/alerts/planning/live/infra

Sanity check: if rollup.needsMe > 0 but views.humanActions.items is empty (or brokenRepos > 0 but whatsBroken.items empty), flag "LENS/ROLLUP MISMATCH — snapshot partially stale" prominently and work from whichever side has data.

## Step 3 — Classify every item
Bucket every item from ALL sources above into exactly one of:

**A. AGENT-RESOLVABLE** — CI failures, lint, dirty repos, stale branches, unpushed commits, PRs awaiting review that agents may review, doc drift, dead code. Criteria: no credential entry, no irreversible prod action, no money, no legal/compliance sign-off, no product-positioning judgment.

**B. FOUNDER DECISION** — anything needing human judgment or human-only access: Cloudflare/AWS dashboard actions, secret rotations, compliance/legal sign-offs, merge sign-offs on PHI/prod-touching PRs, pricing/positioning, architecture forks, spend approvals, anything marked owner=founder/human in queue.yaml or FOUNDER DIRECTIVE items.

**C. EXTERNAL/WAITING** — blocked on third parties (counsel, bank, QS benchmark). Track with expected date; escalate to bucket B only if overdue.

**D. ALREADY PLANNED** — appears in an existing sprint file or in-flight PR. Cross-reference, don't duplicate.

Deduplicate across sources (the same HA-NNN often appears in humanActions, humanQueue, and go-live-gate blockers) — one entry per underlying item, cite all its IDs.

## Step 4 — Plan bucket A into sprints
Sprint files live in `D:\state\sprints\`. Existing plan style: see `D:\state\sprint-plan-2026-07-15.md` (phases, priority, root cause, fix options, effort, verification).

- Maintain/update `D:\state\sprints\orryx-command-sprint-<YYYY-MM-DD>.md` (create today's if none exists this week; otherwise UPDATE the current week's file — mark newly-done items done, add new items, never delete history).
- Each item gets: priority (P1 blocks North Star / P2 blocks repo / P3 hygiene), repo, root cause if known, concrete fix steps, effort estimate, verification command, and suggested executor (which existing routine or a copy-paste agent prompt in the style of `D:\state\orryx-command-collation-2026-07-16.md`).
- Order by North-Star proximity (North Star is in rollup.northStar).
- PILLARWORKS EXCLUSION: pillarworks-build-mvp items are handled in dedicated Pillarworks sessions — list them in a separate "Pillarworks (handled separately)" section, don't write agent prompts for them.

## Step 5 — Build the founder decision pack (buckets B + overdue C)
Write `D:\state\founder-decision-pack-<YYYY-MM-DD>.md`. For EACH decision:
- **Title + tracked ID(s)** (HA-NNN / ESC-NNN / LB-NNN)
- **Why it matters** (what it blocks, North-Star link)
- **Time cost** (e.g. "~2 min in CF dashboard")
- **Options** — 2-4 concrete choices, with a recommended one and one-line rationale
- **Exact resolve action** — the precise clicks/commands so it takes seconds
- **What happens next** once decided (which agent picks it up)

Order: quickest-win first (2-min items at top), then by severity. Cap the "today" section at the top 5; everything else in a "backlog" section below so the list never feels overwhelming.

## Step 6 — Write the interactive walk-through trigger
Append/update a one-line trigger in `D:\state\mvp-scope\GO.md` under a `## DECISIONS` heading (create the heading if absent, replace any previous decision-triage line — keep only the latest):

```
DECIDE: read D:\state\founder-decision-pack-<YYYY-MM-DD>.md and walk me through each open decision one at a time using AskUserQuestion — present each item's options as selectable choices with the recommended option first, record my answer inline in the pack file (mark DECIDED <date> + chosen option), and at the end summarise what agents are now unblocked to do.
```

That line is what the founder pastes into an interactive Claude Code session to resolve everything as a guided list.

## Step 7 — Report
End with a compact summary:
- Snapshot age + any stale-lens warnings
- Counts: N agent-resolvable planned → sprint file path; N founder decisions → pack path; N external/waiting; N already-planned (deduped)
- The top 3 North-Star blockers in one line each
- Confirmation the GO.md trigger line was written

Success = zero dashboard items left unclassified, and the founder can clear every human-gated item by pasting one line.