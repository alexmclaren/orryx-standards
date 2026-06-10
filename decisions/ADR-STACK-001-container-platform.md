# ADR-STACK-001 — Container platform: ECS Fargate vs EKS

**Status:** OPEN (blocks STACK.md v1.0.0)
**Date raised:** 2026-06-10

## Context

The product factory needs one canonical container platform. ECS Fargate is *proposed* canonical, but the evidence is contested:

- **For ECS:** lower ops burden at current team size; Triora + MCP gateway run it; `terraform/modules/aws-ecs-service` exists.
- **Against (the strong counter-evidence):** Pillarworks — the group's most-production product — deliberately runs **EKS** and has for 147+ days. The proposed ECS rationale ("no EKS module exists") is path dependency: the module is missing because nobody built it, which is not evidence EKS is wrong.

The adversarial review (2026-06-10) flagged this as decided-on-absence-of-evidence.

## Decision

**DEFERRED** pending investigation of the actual Pillarworks EKS driver (git-history + ops reality):

- If the driver is a real constraint (multi-tenancy, GPU scheduling, a client K8s requirement, autoscaling behaviour ECS can't match) → **EKS may be canonical**, or a two-tier canonical (ECS default, EKS blessed-with-module for qualifying workloads).
- If no real driver → **ECS canonical**; Pillarworks migrates at its next major infra change.

**No permanent two-stack middle** (that would defeat the one-shared-stack goal).

## Consequences

- STACK.md stays v0.9.0 provisional until this resolves.
- The investigation is a Workstream A task (git-history-analyzer on pillarworks-build-mvp infra + the EKS frontend-404 open ops issue).

## Open
- [ ] Run the EKS-driver investigation
- [ ] Decide: ECS-only / EKS-only / two-tier
- [ ] If two-tier: build `terraform/modules/aws-eks-cluster`
- [ ] Update STACK.md container row + Pillarworks divergence trigger
