# ADR-UX-001: The Decision Hierarchy

**Status:** Accepted (declared by Alex, 2026-07-21)
**Applies to:** Every Orryx venture — Pillarworks, Triora, Orryx products, and all future ventures.

## Principle

> Every unnecessary human action is a product failure.

Whenever a human is required to act, the system must attempt to move the interaction **down** this hierarchy before shipping it:

```
Level 0   AI completes automatically.            (No human involvement.)
Level 1   AI completes and informs the user.
Level 2   AI recommends one option.              (User clicks Approve.)
Level 3   AI presents 2–3 ranked options.        (User selects one.)
Level 4   Human provides missing context.        (AI completes the work.)
Level 5   Human performs the task manually.      (Only when genuinely unavoidable.)
```

The design goal is to push as many interactions as possible toward **Levels 0–2** while preserving transparency and allowing easy review or reversal where appropriate. Products should feel intelligent without taking away user control.

## Rules

1. **Every new interaction must state its level.** Specs, PRs, and design reviews classify each human touchpoint (click, read, type, decide, configure, confirm, search, navigate, wait, remember) with a level and a one-line justification for why it can't be one level lower.
2. **Level 5 requires justification.** Manual work ships only with a written reason it is genuinely unavoidable, and a note on what would move it down (more data, higher confidence, org memory).
3. **Confidence moves levels.** High-confidence AI output auto-applies (L0/L1) with undo; medium confidence recommends (L2); low confidence ranks options (L3). Thresholds are per-feature and calibrated, not guessed.
4. **Memory moves levels.** Anything the user has answered once — preference, rate, template, config — is remembered forever and never asked again (org memory > project history > defaults > ask).
5. **L2/L3 card contract.** When a human decision remains, present it as a card, never a form: Recommended option ⭐, why, confidence %, expected impact/risk, alternatives, one-click approve / reject / edit.
6. **Reversibility is the license for autonomy.** L0/L1 actions must be undoable or reviewable after the fact; irreversible or outward-facing actions cap at L2 (explicit approval).

## Consequences

- Reviews (design, code, product) may block a feature for shipping an interaction at a higher level than necessary.
- "Add a settings page / form / wizard" is a smell — the default answer is infer, remember, or recommend.
- Instrumentation should track level distribution per workflow so automation % is measurable over time.
