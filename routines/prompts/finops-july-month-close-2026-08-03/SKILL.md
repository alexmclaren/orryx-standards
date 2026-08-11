---
name: finops-july-month-close-2026-08-03
description: One-time July 2026 month-close run of finops-routine, deferred from 2026-08-01 because Cost Explorer bills in UTC and Jul 31 was still open. Read-only; auto-disables after firing.
---

Run the **finops-routine** exactly per `C:\Users\alexa\.claude\scheduled-tasks\finops-routine\SKILL.md`. Read that SKILL.md in full first — it is authoritative for scope, constraints, output locations, report structure, the protected-resource list and the Machine Handoff format. Also read `C:\Users\alexa\.claude\scheduled-tasks\_shared\PRODUCER_PRECHECK.md` and apply §1–§5.

You start with NO memory of the session that scheduled you. Everything you need is below.

## Why you exist (do not skip this)

This is a **one-off, operator-requested JULY 2026 MONTH-CLOSE**, not the regular weekly drift pass. The operator asked for it explicitly on 2026-08-01.

Background: the routine fired off-cron on Saturday 2026-08-01 local and correctly emitted `SKIP: NO_CHANGE` (see its row in `D:\reports\evolution\fleet-exit-log.jsonl`, run_id `2026-07-31T21:40:30Z`). That run **deferred the July month-close with a stated reason**: the local date had rolled into August, but **Cost Explorer bills in UTC**, where 2026-07-31 was still an open day returning `"Estimated": true` and a partial `$30.05`. Computing a July total then would have been wrong. You are firing ~78h after the Jul 31 UTC day closed, so July should now be final.

The regular weekly slot (`45 14 * * 5`, Friday) is **untouched** and still set for 2026-08-07. You are additive. Do not modify the recurring `finops-routine` task in any way — in particular **never pass `fireAt` to `update_scheduled_task` on it**, which would permanently destroy its recurring schedule.

## Hard gate before you compute anything

Query Cost Explorer for July with DAILY granularity and **inspect the `Estimated` flag on every returned day**:

```
aws ce get-cost-and-usage --time-period Start=2026-07-01,End=2026-08-01 --granularity DAILY --metrics UnblendedCost
```

- If **every** July day returns `Estimated: false` → July is final. Proceed with the full month-close.
- If **any** July day still returns `Estimated: true` → say so explicitly and prominently, present the figures as **provisional**, and do NOT state a final July total as settled fact. Recommend the 2026-08-07 weekly run re-confirm. Do not silently round an estimate into a headline. Reporting "July is not yet final" is a correct and complete outcome — it is not a failure.

State the verdict of this gate in the report's §1 TL;DR either way.

## What to produce

A **full ledgered run** (the 5th), superseding `D:\reports\finops\finops-review-2026-07-31.md`:

1. **Report:** `D:\reports\finops\finops-review-2026-08-03.md`. Follow the SKILL's 6-section Report Structure plus the mandatory Machine Handoff table, ending with the `UNREALIZED-SAVINGS: $N/mo` line.
2. **Ledger UPSERT:** `D:\state\finops-ledger.json`.
3. **Exit row** appended to `D:\reports\evolution\fleet-exit-log.jsonl` as the LAST step, per §4 — with `run_id` from a **two-source clock read** (PowerShell `(Get-Date).ToUniversalTime()` AND `python -c "..."`), taken as you write the row, sanity-checked to within minutes of your report's on-disk mtime. `routine_id` must be `finops-routine` (NOT the task id). Note in the row that this was a one-off operator-requested month-close.

### Month-close specifics (this is what makes the run worth doing)

- **Full July (Jul 1–31, 31 complete days) vs full June (Jun 1–30, 30 days) vs the $1,907/mo baseline.** The 2026-07-31 run could only use Jul 1–29 normalised ×30.44; you can use the *actual* month. Say plainly where the true July total lands vs that extrapolation, and whether the extrapolation was high or low — that is a calibration data point worth recording.
- Report **both pre-tax and all-in** (tax is billed as a lump on the 1st, ~10%). The prior run gave ~$1,636/mo pre-tax / ~$1,800/mo all-in and −22.3% MoM. The 2026-06-03 baseline audit never stated its basis, so keep giving both.
- Per-service drift table with drivers, as in the prior report.
- **Watch for the August 1 tax lump** landing in the Aug 1–2 data and do not mistake it for a spend spike.

### Ledger discipline

- Advance `runs_persisted` normally — this **is** a genuine full run.
- Existing items: FO-01 (realized), FO-02 (realized), FO-03 (open, $3.65 — idle EIP `eipalloc-009bb8bebdebf98e3` / 3.218.135.56, us-east-1), FO-04 (open, $0), FO-05 (wont-do), FO-06 (open, $10 — ECR lifecycle), FO-07 (in-progress, $10 — pillarworks-prod EKS VPC missing S3 gateway endpoint), FO-08 (open, $10 — canary cadence), FO-09 (open, $4 — RDS snapshots, PHI/human-gated), FO-10 (open, $0 — cost-allocation tags not activated). Open sum carried in: **$27.65/mo**.
- As of 2026-08-01 the live inventory was: ap-southeast-2 exactly 2 NAT gateways (`nat-05bebc1d966ee985b`, `nat-096774a842068f811`) and zero unassociated EIPs; us-east-1 one NAT (`nat-08b42560a35f5eedb` / `vpc-035f4d82a6650940f`) and `eipalloc-009bb8bebdebf98e3` still the only unassociated EIP in either region. **Re-verify against live inventory — do not trust this snapshot.** Handoff-issue state is a weak signal for realization; only live inventory settles it (that lesson is recorded in the ledger under FO-02).
- **Set `_meta.month_close: "2026-07"` and record in `_meta.note` that this run served the substance of the 2026-08-07 weekly window.** The 08-07 run fires only 4 days later, so it should apply §3 NO_CHANGE discipline if nothing has moved rather than re-aging the ledger. Make that explicit for it.

## Constraints (from the SKILL — non-negotiable)

Read-only and advisory. **Never** delete, stop, scale, resize, modify or tear down any resource; never add/change a lifecycle rule; never delete a snapshot. Recommend only — teardown is human-gated.

🚨 **Protected, never flag for deletion or expiring lifecycle:** `s3://pillarworks-build-storage` (sole copy of training data — no lifecycle rule, ever), the live pillarworks-prod EKS cluster + staging DB, the WAF on the Triora/PHI ALB, and `clinical-trials-db-pilot` snapshots (FO-09 is retention-*policy* advice only, founder-gated, PHI). Re-read the protected list from the SKILL and from operator memory (`trained-models-protection-*`, `cloud-cost-teardown-plan-*`) rather than relying on this summary. Restate in §4 of the report that these were checked and NOT flagged.

Platform constraint: **AWS + Cloudflare only.** Never recommend another host as a saving; flag any non-AWS/non-Cloudflare spend as a violation.

Never print secret values or billing PII. Never fabricate a cost figure not backed by a Cost Explorer or inventory call made during this run.

## Environment

- Use the **PowerShell tool** for all `D:\` access and all `aws` / `gh` CLI invocation. Bash cannot reach `D:\`. Use Windows paths.
- AWS account `490004631560`, identity `arn:aws:iam::490004631560:user/orryx.ec2`, primary region ap-southeast-2. Verify with `aws sts get-caller-identity` first.
- `{date}` in filenames/headings = **LOCAL date, Australia/Brisbane UTC+10** (should be `2026-08-03`). Timestamps stay UTC with `Z`. Stamp `date_basis: LOCAL (UTC+10)` in the report header.
- Each Cost Explorer API call costs $0.01 — the prior report disclosed this line honestly. Be efficient; don't spray calls.

## ⚠️ Tool approvals do not transfer between scheduled tasks

You are a **freshly created task and hold none of the approvals `finops-routine` has accumulated.** `settings.json` has `defaultMode: default` and pre-allows only `aws secretsmanager get-secret-value/describe-secret` — **not** `aws ce` or `aws ec2 describe-*`. Your cost and inventory calls may therefore prompt or be denied in an unattended run.

If that happens: **do not fabricate, estimate around, or infer figures you could not read.** Produce whatever partial analysis the calls you *did* complete support, state precisely which calls were blocked and what that leaves unverified, and record it in the exit-log row so `fleet-health-routine` sees a blocked run rather than a silent no-op. A short honest report naming the gap is the correct output. Do not request broader permissions for yourself.

## Finish

Run the self-check `pwsh -NoProfile -File C:\Users\alexa\.claude\hooks\validate-handoff.ps1 -File D:\reports\finops\finops-review-2026-08-03.md`. If it prints FAIL, fix the handoff table and re-emit (max 2 re-emits per §5). `SKIP not a contracted report` is an acceptable result.

This task auto-disables after firing; no cleanup needed.