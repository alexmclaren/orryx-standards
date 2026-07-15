---
name: triora-nat-egress-verify-2026-06-27
description: One-time check that the Triora ap-se-2 NAT-egress fix held — compares post-fix bytes to baseline and reports.
---

Verify that the Triora clinical-trials NAT-egress fix deployed on 2026-06-26 actually returned data-egress to baseline. This is a one-time verification run — be concise and report a clear PASS/FAIL.

CONTEXT (what happened):
- AWS account 490004631560, region ap-southeast-2 (Sydney). The ECS service `clinical-trials-api-pilot` (cluster `clinical-trials-pilot`) had a bug that drove NAT-Gateway egress from a ~30 GB/day baseline up to ~880 GB/day starting 2026-06-21 (cost ~$52/day). Root cause: a UUID-seeding crash-loop (admin/service accounts seeded with non-UUID ids) that defeated a Pinecone auto-indexer's "already indexed" guard, so every task boot re-ran a full re-embed/re-upsert out the NAT gateway.
- Fixed in PR #104 (repo alexmclaren/Clinical_trials), merged + deployed 2026-06-26 (task-def rev 441, image tag prefix 63f34bde). The fix: valid UUID constants for seeding + auto-index gated behind AUTO_INDEX_TRIALS=true only.

STEPS (use the AWS MCP tool `mcp__AWS_API_MCP_Server__call_aws`; the Cost Explorer `ce` API must be called with --region us-east-1 even though the resources are in ap-southeast-2):

1. Run a fresh anomaly check:
   `aws ce get-anomalies --date-interval StartDate=2026-06-24,EndDate=2026-06-28 --region us-east-1`
   Look for any NEW EBS/NAT-Gateway anomaly in ap-southeast-2 with a start date of 2026-06-26 or later. A new high-impact one = FAIL signal.

2. Pull daily NAT-Gateway + regional-transfer usage to see the trend. Write this filter JSON to the AWS MCP working dir as `natfilter.json`:
   {"Dimensions":{"Key":"USAGE_TYPE","Values":["APS2-NatGateway-Bytes","APS2-DataTransfer-Regional-Bytes"]}}
   Then run:
   `aws ce get-cost-and-usage --time-period Start=2026-06-20,End=2026-06-28 --granularity DAILY --metrics UnblendedCost UsageQuantity --filter file://natfilter.json --group-by Type=DIMENSION,Key=USAGE_TYPE --region us-east-1`

3. Compare the per-day `APS2-NatGateway-Bytes` UsageQuantity (GB):
   - Incident days 2026-06-21..06-25 were ~840-890 GB/day.
   - Baseline (pre-incident) was ~10-30 GB/day.
   - The fix deployed late 2026-06-26 UTC, so 2026-06-27 is the first FULL clean day — focus there.
   - PASS if 2026-06-27 NAT-Gateway GB is back near baseline (roughly < ~150 GB/day, ideally ~30). FAIL if it's still in the hundreds.

4. (Optional sanity) Confirm the service is on the fixed image and healthy:
   `aws ecs describe-services --cluster clinical-trials-pilot --services clinical-trials-api-pilot --region ap-southeast-2 --query "services[0].{running:runningCount,desired:desiredCount,taskDef:taskDefinition}"`
   The taskDefinition revision should be >= 441.

REPORT (concise):
- A one-line verdict: ✅ PASS (egress returned to baseline) or ❌ FAIL (still elevated — escalate).
- A small table of the last ~7 days NAT-Gateway GB/day so the drop (or lack of it) is visible.
- The 2026-06-27 figure vs baseline, and whether any new anomaly appeared.
- If FAIL: note that the running tasks may still be crash-looping or a different egress source emerged, and recommend re-checking task logs in /ecs/clinical-trials-api-pilot for `database_user_init_failed` or repeated Pinecone "Index client created" lines.

Do NOT mutate anything — this is a read-only verification.