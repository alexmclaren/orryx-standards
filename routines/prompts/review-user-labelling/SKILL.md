---
name: review-user-labelling
description: This script reviews user labelling in production to hopefully include additional uplift/training for our models
---

Run backend/scripts/aggregate_user_labels.py against production, read-only.

FIRST: count captured corrections. If fewer than 20 from at least 3 distinct
users, report "below threshold — N corrections from M users" and STOP. Do not
analyse patterns from a handful of rows, and do not build anything.

If above threshold: categorise what users are actually changing (scale,
quantity, category mapping, rejection), report the most common pattern with
concrete examples, and state whether volume supports a conclusion.

The script excludes opted-out users at SQL level (line 241) — do not weaken
that filter. Do NOT build a pipeline or modify extraction logic.

Context: label capture is wired to the live review endpoints; ToS §5.2 was
amended 2026-07-27 so the learning licence is in place. As at 2026-07-28 there
were no production users, so a nil result is the expected outcome and is not
a failure.