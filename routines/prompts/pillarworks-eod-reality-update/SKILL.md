---
name: pillarworks-eod-reality-update
description: Daily EOD Pillarworks reality reconciliation — closes shipped issues with evidence, truth-ups STATUS/SESSION_STATE/audit docs via a self-merged docs-only PR (green-CI gated), so every next session starts from truth. Repo-scoped writer; complements (does not replace) the read-only fleet reporters and 18:34 distillation.
---

You are running the Pillarworks END-OF-DAY REALITY UPDATE. Purpose: eliminate drift between documented plans and reality so every next session starts from truth. This is a hygiene job — docs and issue-queue only. Write NO application code, touch NO workflows, secrets, or infra in this task.

Repos:
- Backend: D:\pillarworks-build-mvp (github alexmclaren/pillarworks-build-mvp). main is protected — NEVER push to it directly; all doc changes go via a PR. Work in a git worktree under .claude/worktrees/ (create your own; other sessions may hold existing ones).
- Frontend: D:\Pillarworks-Enterprise-Website (github alexmclaren/Pillarworks-Enterprise-Website).

STEP 1 — GATHER TRUTH
- git fetch both repos; list main commits from the last 24h (merged PR subjects).
- gh pr list and gh issue list (open) for both repos.
- Probe production: curl https://build.orryx.dev/health (expect {"status":"healthy"}); curl -sI https://pillarworks.io (expect 200). Note anomalies.

STEP 2 — RECONCILE THE ISSUE QUEUE
For each open issue in both repos, check whether last-24h merges resolve it (read merge subjects/PR bodies; where needed `gh pr view` and grep main's code).
- CLOSE issues that are clearly shipped AND deployed, with an evidence comment: commit SHA + PR number + probe evidence where applicable.
- If resolution is plausible but unverified (e.g. needs an authenticated browser check only Alex can do), do NOT close — comment the evidence and state exactly what verification is missing.
- Flag open PRs that are superseded/obsolete with a comment (do not close another author's PR without obvious grounds like its target directory being deleted).

STEP 3 — DOC TRUTH-UP (backend repo, docs-only PR)
- Update docs/STATUS.md (Known Gaps / Open PRs / phase lines) and SESSION_STATE.md to match reality.
- Write docs/audits/REALITY_UPDATE_<YYYY-MM-DD>.md: shipped-last-24h (PR list), still-open by priority, drift corrected (what docs claimed vs what is true), prod health snapshot.
- Branch docs/reality-update-<YYYY-MM-DD>, conventional commit (docs(reality): ...), open a PR.
- STANDING AUTHORIZATION (Alex, 2026-07-24): you may merge this docs-only PR yourself once ALL CI checks are green. If any check is red: investigate; fix only if this PR's docs caused it; otherwise leave the PR open and report why. Never use --no-verify or bypass any hook/check. Note: a merge to main triggers a backend redeploy of the same code via deploy-backend-eks — expected pipeline behavior; after merge confirm https://build.orryx.dev/health still returns healthy.

STEP 4 — FINAL REPORT (your last message)
Merged-last-24h summary; issues closed (numbers); issues flagged-not-closed and why; docs corrected; prod health; anything alarming (red CI on main, unhealthy endpoint, stuck PR train) flagged prominently at the top.

Constraints: backend tests are NOT runnable locally (no Postgres) — CI is the verifier. detect-secrets baseline: hand-edit line_numbers only, never regenerate from Windows. Trust git/gh over what docs claim. If gh is rate-limited or the network is down, report and stop gracefully.