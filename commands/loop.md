---
description: Run the standardized self-iterating Ralph loop with hard stop conditions
argument-hint: "[task description]  [--max N]"
---

# /loop — standardized self-iterating Ralph loop

You are running the **canonical Ralph loop** defined in
`CLAUDE.base.md §1.3` (anchor: `loop-stop-conditions`). This command is a thin
runner — it does **not** redefine the loop. Read that section as your contract.

## Task

$ARGUMENTS

If no task is given above, ask the user for one before looping. Do not invent a task.

## How to run it

1. **Define DONE first (§0.3).** Before any iteration, write the acceptance
   criteria and how each will be *verified against the real system* (§0.4) —
   tests run, output observed, endpoint hit. Vague criteria → no exit is provable.

2. **Iterate** per `§1.3`: Implement → Test → Verify → Identify gaps → Fix → Repeat.

3. **After every iteration, evaluate the §1.3.1 stop conditions in order.** The
   first match stops the loop:
   - DONE proven (all criteria met + verified) → **exit success**
   - Confidence ≥ 0.85 and §5 gates pass → **exit success**
   - Max iterations reached (default **5**, or the `--max N` you were given) → **exit, escalate**
   - No-progress (2 consecutive iterations with no meaningful delta) → **exit, escalate**
   - Blocked / `[REQUIRES HUMAN REVIEW]` boundary → **exit, escalate**

4. **On exit:** emit the §10.2 end-of-session summary — what's done, what remains,
   risks, next step. An escalation exit is a *correct* outcome, not a failure;
   report the stuck/blocked state plainly with the partial progress.

## Arguments

- Free text → the task to loop on.
- `--max N` → override the default iteration cap of 5 (state the override; never raise it silently).

## Guardrails (do not bypass)

- Never advance the iteration counter without a genuine attempt.
- Never declare "converged" from an iteration you did not actually verify.
- Confidence < 0.85 with iterations left → keep looping. At the cap → escalate, do **not** ship.
- Respect §7 human-review boundaries: clinical/compliance/privacy/production-data work
  exits to the human, it does not auto-loop to completion.
