---
name: pillarworks-m3-qs-benchmark-tracker
description: Weekly tracker for the M3 QS ground-truth accuracy benchmark — the long-pole external dependency for any Pillarworks accuracy claim
---

You are tracking the status of the **M3 QS Ground-Truth Accuracy Benchmark** for the Pillarworks BOQ-automation product (repo: D:\pillarworks-build-mvp). This is the critical-path EXTERNAL dependency that lets the product make a defensible measurement-accuracy claim. Your job each week is to check whether it has progressed and surface the next concrete action — NOT to do the QS work yourself (that requires a credentialed human quantity surveyor).

## Background (self-contained — you have no memory of prior sessions)
The measurement-precision program built a scale-calibrated geometric measurement engine (M1/M2, live on prod EKS) that cross-checks vision-extracted quantities. But there is NO defensible accuracy statement yet: per-quantity confidence is partly model self-report, and the existing corpus fixtures are PyMuPDF geometry, not QS ground truth. The ONLY way to claim an honest accuracy tolerance (target framing: "±5–8% of manual takeoff on clean CAD-exported sheets," aligned with AIQS Stage C/D) is to have a registered AIQS quantity surveyor do a manual takeoff (ANZSMM rules) on 10–15 stratified sheets, then compare element-level MAPE by category and drawing type. Full engagement brief: docs/strategy/M3_QS_BENCHMARK_BRIEF.md.

## What to do each run
1. Read docs/strategy/M3_QS_BENCHMARK_BRIEF.md and docs/strategy/PRECISION_PROGRAM_BACKLOG.md (the M3 entry) and docs/STATUS.md to refresh current state.
2. Check whether M3 has progressed: has a QS been engaged? Does docs/strategy/M3_QS_BENCHMARK_RESULTS.md exist yet? Has the benchmark harness (candidate backend/scripts/bench_qs_accuracy.py) been built? Run `gh pr list --search M3` and `git log --oneline -15` to detect any related work.
3. Produce a SHORT status note (5–8 lines) stating: (a) current M3 state, (b) the single most important blocking action — which is almost certainly the OPERATOR action "engage a registered AIQS quantity surveyor (2–4 days of their time, blind to pipeline output)", until that is done, and (c) any autonomously-codeable prep that could be done now without the QS (e.g. building the deterministic scoring/matching harness `bench_qs_accuracy.py` mirroring backend/scripts/bench_bbox_localization.py, and selecting the stratified sheet set from backend/scripts/corpus_geometry_results.json per the brief §4).
4. If — and only if — the QS labels (qs_ground_truth/*.json) now exist and the harness is missing, offer to build the harness this run.
5. Surface the note to the user as the run output. Keep it crisp; this is a nudge, not a report. Do not perform irreversible or outward-facing actions.

Success = the user gets a one-glance answer to "is M3 moving, and what's the next action?" so the long-pole dependency does not silently stall.