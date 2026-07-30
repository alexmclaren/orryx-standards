---
name: peak-period-trim-review-2026-07-31
description: Reminder: peak-shipping token trims expire — re-enable deep-research + tooling-mcp-discovery and decide whether competitive-intelligence returns to weekly.
---

The 4-week peak-shipping token trim (applied 2026-07-03) expires today. Remind Alex and present the decision:

1. Re-enable `deep-research-routine` and `tooling--mcp-discovery-routine` in the scheduler (they were disabled, not deleted — use update_scheduled_task with enabled: true).
2. Ask whether `competitive-intelligence-routine` should return to weekly — if yes, remove the "Fortnightly gate" section from the top of its SKILL.md at C:\Users\alexa\.claude\scheduled-tasks\competitive-intelligence-routine\SKILL.md AND from the versioned copy in D:\orryx-standards\routines\prompts\ (commit via PR).
3. Update D:\orryx-standards\routines\routine-schedule.json: remove the `paused_until` fields from deep-research-routine and tooling--mcp-discovery-routine (and competitive-intelligence cadence if reverted), regenerate the DAG via D:\orryx-standards\scripts\generate-fleet-dag.ps1, and update the weekly section of C:\Users\alexa\.claude\scheduled-tasks\_shared\fleet-expectations.json to match.
4. If the peak period is still running, offer to extend the trim another 2-4 weeks instead — in that case update this task's fireAt rather than re-enabling.
5. CONTEXT (added 2026-07-17): CI's producer pre-check was deadlocked all July — it required SAME-DAY product-review/commercial-review/deep-research, but those run Mon/Wed/never(disabled), so CI structurally skipped every Saturday (e.g. 2026-07-11). A routine-specific override (accept inputs ≤7d old; exclude disabled producers) was added to its SKILL.md §Producer Pre-check on 2026-07-17. When re-enabling deep-research / reverting cadence, keep that override — same-day inputs will STILL never exist on a Saturday. Propagate the override to the D:\orryx-standards\routines\prompts\ copy if not already done.

Surface the decision as the run output; take no action without Alex's answer beyond presenting current state (check whether the routines are in fact still disabled first — Alex may have re-enabled them manually).