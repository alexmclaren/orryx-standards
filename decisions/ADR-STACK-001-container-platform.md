# ADR-STACK-001 — Container platform: ECS Fargate vs EKS

**Status:** ACCEPTED — **ECS Fargate canonical** (2026-06-10, after W0.3 investigation)
**Date raised:** 2026-06-10 · **Date decided:** 2026-06-10

## Context

The product factory needs one canonical container platform. ECS Fargate was *proposed* canonical, but the adversarial review (2026-06-10) flagged the choice as decided-on-absence-of-evidence: Pillarworks (the most-production product) runs EKS, and "no EKS module exists" is path dependency, not a reason EKS is wrong. The W0.3 investigation was run to resolve this on evidence.

## Investigation (W0.3) — what the EKS adoption actually was

Verified against BOTH git history and live AWS (see `orryx-audit/swarm-outputs/W0.3-eks-driver.md`):

- **No EKS ADR exists.** Pillarworks ADRs run 001–005 (FastAPI, Next.js, Railway, Stripe, YOLOv8). None covers containers/EKS.
- **EKS was discovered, not chosen.** On 2026-04-29 the ECS RDS `pillarworks-prod-db` was deleted and EKS cluster `pillarworks-prod` stood up **out-of-band, with zero repository commits**. The repo kept targeting ECS for ~3 weeks until Sprint 38 Session 71 found the cluster via `kubectl` recon (commit `4be74948`, message: "EKS path discovered; ECS track blocked").
- **Live AWS confirms** (read-only, 2026-06-10): EKS `pillarworks-prod` is ACTIVE, k8s 1.30, created `2026-04-29T16:51` — exactly matching the git "accident" date — with one `pillarworks-workers` nodegroup.
- **No workload needs Kubernetes.** Manifests are a standard 2-replica Deployment + ClusterIP + ALB-Ingress (path routing) + IRSA for Secrets Manager. ECS Fargate equivalents exist for all: ALB listener rules + 2 target groups (routing), task IAM roles (IRSA), native Secrets Manager task integration (ESO). No DaemonSets, StatefulSets/PVCs, HPA, GPU, service mesh, or multi-tenant namespaces in use.

**Driver verdict: ACCIDENT / undocumented out-of-band pivot.** The "strong counter-evidence" dissolved on inspection — it was not a decision.

## Decision

**ECS Fargate is canonical.** The EKS control plane (~$72/mo) is pure overhead with no technical justification; every other Orryx platform service runs ECS Fargate.

**Pillarworks migrates EKS → ECS Fargate** (convergence trigger, not "someday"): scheduled as a dedicated migration with a checklist — replicate ALB path-routing as listener rules + 2 target groups, IRSA → task roles, ESO → native Secrets Manager. Until migration completes, EKS is a registered divergence with this ADR as its closure plan.

**No `aws-eks-cluster` Terraform module will be built** (would institutionalise the accident).

## Consequences

- STACK.md container row → ECS Fargate canonical (no "PROPOSED" hedge). v0.9.0 → v0.9.1; v1.0.0 still gated only on ADR-STACK-002 (consulting distribution / org migration).
- New `WD/WA` task: Pillarworks EKS→ECS migration plan (human-gated; touches prod).
- The out-of-band-infra-change pattern that caused this is itself a finding: it's the same "no ratified stack → environments appear with no git trace" failure as the duplicate ap-se-2 VPC (WF.2). STACK.md + IaC discipline is the prevention.

## Closed
- [x] Run the EKS-driver investigation (W0.3)
- [x] Decide: **ECS-only** (Pillarworks migrates)
- [x] Do NOT build an EKS module
- [ ] Author the Pillarworks EKS→ECS migration plan (follow-up, human-gated)
- [x] Update STACK.md container row + Pillarworks divergence trigger
