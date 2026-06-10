# ADR-STACK-002 — Consulting distribution model & marketplace ownership

**Status:** OPEN (blocks STACK.md v1.0.0)
**Date raised:** 2026-06-10

## Context

The strategic goal includes delivering the stack to consulting clients on their AI journey. The draft STACK.md asserted "the factory and the consulting deliverable are the same artifact." The adversarial review (2026-06-10) showed this is an unexamined assumption with real failure modes and an access-control liability.

Problems:
1. The full stack (AWS + ECS/Fargate + Terraform) does not fit no-AWS, GCP/Azure, on-prem/air-gapped, or data-sovereignty clients.
2. The agent layer (marketplace) is sourced from a **personal** GitHub namespace `alexmclaren/orryx-knowledge` — a bus-factor and access-control problem for paid external delivery, and a hard blocker for clients who can't auth into it.

## Decision

**DEFERRED** pending two resolutions:

1. **De-personalize the marketplace** — move `orryx-knowledge` (and the canonical repos) to an `orryx-group` GitHub org before any client engagement consumes the marketplace. (Ties to audit decision Q-F.) Do this *before* the marketplace baked into any client repo's `extraKnownMarketplaces`, since the `source` is hard to change later.
2. **Two-layer consulting model** — separate the portable **agent layer** (marketplace + CLAUDE/AGENTS conventions + safety hooks; cloud-neutral) from the **infra layer** (ECS/Vite/Terraform/AWS; Orryx's reference stack, adapted per client cloud). State in-scope vs out-of-scope client contexts.

## Consequences

- STACK.md "Consulting application" section rewritten to "fit and limits" with explicit out-of-scope contexts (done in v0.9.0).
- Marketplace must be self-hostable for on-prem clients (future work).

## Open
- [ ] Create `orryx-group` GitHub org; migrate canonical repos (Q-F)
- [ ] Re-point any marketplace `source` references to the org
- [ ] Decide marketplace self-hosting story for air-gapped clients
- [ ] Promote STACK.md to v1.0.0 once ADR-STACK-001 + this are closed
