# ADR-STACK-002 — Engagement-delivery model (supersedes "consulting distribution")

**Status:** ACCEPTED (2026-06-10)
**Date raised:** 2026-06-10 · **Date decided:** 2026-06-10

## Context

The strategic goal includes serving consulting clients on their AI journey. An earlier draft framed this as "the factory and the consulting deliverable are the same artifact" and implied a **publishable/self-serve marketplace**. The adversarial review (2026-06-10) surfaced real failure modes in that framing (client-cloud fit, personal-namespace access-control, bus factor).

The founder resolved the framing directly (2026-06-10): **Orryx is NOT publishing a public or self-serve marketplace.** The skills/stack/templates are **internal engagement tooling**. The client receives a *delivered product*; they do not consume, authenticate into, or self-serve any Orryx marketplace. The background model (Claude tier, plugin set, conventions) is swappable infrastructure that evolves as AI advances — not a product surface.

This collapses most of the originally-open problem.

## Decision — Engagement-delivery model

1. **No public marketplace. Ever (under current strategy).** `orryx-knowledge` and the plugin set are **Orryx-internal tooling**, used by Orryx operators to deliver engagements. They are not marketed, published, or handed to clients to self-serve.

2. **Orryx-operated delivery.** In a client engagement, Orryx operators (not the client) use the marketplace + stack to build/deliver the client's product. The client gets a working product on an appropriate stack; the tooling that produced it stays Orryx's. This removes the client-auth / personal-namespace blocker entirely — the client never touches `extraKnownMarketplaces`.

3. **Two-layer model (retained, clarified):**
   - **Agent layer** (marketplace plugins, CLAUDE/AGENTS conventions, safety hooks) — Orryx's internal delivery toolkit; cloud-neutral; the operator brings it.
   - **Infra layer** (ECS Fargate / Vite / FastAPI / Terraform / AWS) — Orryx's reference stack; adapted to the client's cloud/constraints per engagement.
   - The earlier "out-of-scope client contexts" concern (no-AWS / GCP-Azure / on-prem / sovereignty) is now an **engagement-scoping** matter, not a distribution blocker: Orryx adapts the infra layer per client; the agent layer travels with the operator regardless of client cloud.

4. **`orryx-group` org migration — recommended, NOT a blocker.** Even as internal tooling, sourcing from a personal account (`alexmclaren/...`) has two real costs: (a) **bus factor** — everything keys off one personal account; (b) **professional optics** — a client glimpsing `github.com/alexmclaren/...` during a paid engagement reads as less established than `github.com/orryx-group/...`. **Recommendation: migrate to an `orryx-group` org before the first client engagement** — a credibility/continuity move, sequenced at the founder's discretion, no longer gating STACK.md or the factory.

5. **Background model is swappable by design.** Plugin set, Claude tier, and conventions are expected to change as AI progresses. STACK.md's agent layer references the *capability* (marketplace-consumer config, pointer CLAUDE/AGENTS, safety hooks), not a frozen model — so model upgrades don't require an ADR, only a version bump.

## Consequences

- **STACK.md → v1.0.0** (both blocking ADRs now closed: 001 ECS, 002 engagement model).
- The factory build (WD) is unblocked on strategy; remaining gates are operational (org-migration timing, repo-creation sign-offs), not decisional.
- "Marketplace self-hosting for air-gapped clients" is dropped — irrelevant under the Orryx-operated model (the operator brings the tooling; the client's environment doesn't host it).
- The `orryx-product-template` (WD.1) targets Orryx-internal use first; client engagements fork/adapt it per cloud.

## Closed
- [x] Framing resolved: internal engagement tooling, not a published marketplace (Model A)
- [x] Two-layer model clarified (agent layer travels; infra layer adapts per engagement)
- [x] Promote STACK.md to v1.0.0
- [ ] `orryx-group` org migration — recommended before first client engagement (founder-timed, non-blocking)
