---
name: requeue-ceo-routine-2026-08-01
description: Burst-fire requeue of ceo-routine at its real 15:25 local slot on 2026-08-01 (PRODUCER_PRECHECK §1 step 2c). Auto-disables after firing.
---

Run the **ceo-routine** exactly as specified in `C:\Users\alexa\.claude\scheduled-tasks\ceo-routine\SKILL.md`. Read that SKILL.md first and follow it in full.

CONTEXT FOR THIS RUN (you have no memory of the run that created this task):

- This is an **automatic burst-fire requeue** created under `_shared\PRODUCER_PRECHECK.md` §1 step 2c. It is not an extra ad-hoc run — it stands in for ceo-routine's real 15:25 local cron slot on 2026-08-01.
- Why it exists: ceo-routine was burst-fired at 07:38 local on 2026-08-01, hours before its producers (`repo-scanner` 12:02 local, `security-routine` 12:52 local). It correctly emitted `SKIP: PRODUCER_NOT_YET_FIRED (security-routine)` and wrote an exit row. Because the scheduler computes the next fire as `lastRunAt + 24h`, that burst-fire consumed the 2026-08-01 slot and would otherwise have pushed ceo-routine to 2026-08-02 — losing the whole day.
- **Re-run the §1 producer pre-check from scratch.** Do not assume any input is present or absent based on this prompt. Stat `D:\reports\security\security-review-{today}.md` yourself (today = LOCAL Brisbane date, UTC+10, per DOC-36) and apply the freshness gate to every other input.
- If the producers have since run, proceed with the FULL synthesis: the ceo-summary report, the `D:\state\ceo-escalations.json` ledger update, and the board HTML on `G:`.
- If `security-review` is STILL absent at this hour, emit a `SKIP` per §1 — but do **not** mint another requeue (§2c allows one requeue per routine per day, never a chain).
- Write the §4 structured exit record to `D:\reports\evolution\fleet-exit-log.jsonl` as the LAST step either way, with `routine_id: "ceo-routine"` and a two-source-verified UTC clock read.

Known limitation to be aware of: tool approvals are stored per-task, so this generated task starts with none. If you stall on a permission prompt, say so plainly in the exit record rather than working around it.