# STACK.md — Orryx Group Canonical Technology Stack

**Version:** 1.0.0 (RATIFIED — both blocking ADRs closed)
**Drafted:** 2026-06-10 · **Ratified:** 2026-06-10
**Status:** Ratified. The Orryx product factory templates this stack; new products MUST conform or register a divergence with a convergence trigger. Both prior blockers are closed: ADR-STACK-001 (ECS Fargate canonical) and ADR-STACK-002 (engagement-delivery model).
**Authority:** Single source of truth for Orryx Group stack choices. Referenced from [CLAUDE.base.md](CLAUDE.base.md). Backed by ADRs in `decisions/`.

> **✅ ADR-STACK-001 — ECS vs EKS (RESOLVED):** **ECS Fargate canonical.** The W0.3 investigation (git + live AWS) found the Pillarworks "EKS" was an undocumented out-of-band pivot, not a decision — EKS cluster stood up 2026-04-29 with zero commits, discovered 3 weeks later via kubectl recon; no workload needs Kubernetes. Pillarworks migrates EKS→ECS. The "147-day production EKS" counter-evidence dissolved on inspection.
>
> **✅ ADR-STACK-002 — Engagement-delivery model (RESOLVED):** Orryx is **NOT** publishing a public/self-serve marketplace. The marketplace + stack are **internal engagement tooling**; Orryx operators use them to deliver client products, and the client never consumes or authenticates into a marketplace. This removes the client-fit and personal-namespace blockers. The background model (Claude tier, plugin set) is swappable as AI advances. `orryx-group` org migration is recommended for credibility/continuity before the first client engagement, but is no longer a blocker.

---

## Canonical stack

| Layer | Canonical choice | Rationale (summary) |
|---|---|---|
| **Containers** | **AWS ECS Fargate** *(SETTLED — ADR-STACK-001)* | Lower ops burden at team size; Triora + MCP gateway + orryx-prod-api all run it; ECS Terraform module exists. The Pillarworks "EKS" was an out-of-band accident (no ADR, no commits, discovered via kubectl recon), not a decision; no workload needs k8s. Pillarworks migrates back. No EKS module will be built. |
| **Frontend** | **Vite + React → S3 + CloudFront** | Deploy target is static hosting (Vercel removed 2026-06); SSR/ISR value of Next.js is largely moot without a Node edge; 2 of 3 products + orryx.dev are Vite; Magic Patterns pipeline outputs Vite |
| **Backend** | **FastAPI, Python 3.11+** | Universal across all three products; strongest convergence point |
| **Data** | **AWS RDS PostgreSQL** (+ ElastiCache Redis where caching/sessions needed) | Universal; `terraform/modules/aws-rds-postgres` exists |
| **Workflow engine** | **Temporal** for product-critical durable workflows, **above a complexity threshold**; below it, a Postgres-backed job queue | Proven in Triora; but Temporal is heavy infra for a pre-MVP or small client engagement that may have no durable workflows. Threshold: stand up Temporal only when there are ≥2 multi-step workflows that must survive process restarts. Otherwise Postgres-queue. n8n for internal automation only |
| **AI layer** | **Outcome-router abstraction** (`src/server/services/outcomeRouter.ts` / `outcomeService.js`, ADR-106). **Anthropic API primary** provider; **AWS Bedrock** for AU-data-residency workloads | Router is REAL working code (verified 2026-06-10: live `/api/outcomes/execute`, tested strategies). Default to latest Claude models (Opus/Sonnet/Haiku per outcome cost/speed/accuracy) |
| **CI/CD** | **GitHub Actions + OIDC** (no long-lived AWS keys in CI) | Pillarworks already migrated; OIDC removes the exact credential class behind the HA2 incident |
| **IaC** | **Terraform** (`orryx-standards/terraform/modules/`) | Reusable ECS / RDS / S3-CloudFront modules; state backends codified (PR #115) |
| **Agent layer** | Marketplace-consumer config (`extraKnownMarketplaces` + `enabledPlugins` in `.claude/settings.json`, sourced from `alexmclaren/orryx-knowledge`) + pointer `CLAUDE.md`/`AGENTS.md` (→ `CLAUDE.base.md`/`AGENTS.base.md`) + canonical secret `.gitignore` + `safety-hooks-base` | Single-source the agent operating system; products consume rather than copy |

### Standard service shape (what a new product gets on day one)

```
<product>/
├── backend/         FastAPI (Python 3.11+), Dockerfile → ECS Fargate
├── frontend/        Vite + React → S3 + CloudFront
├── terraform/       ECS service + RDS Postgres + S3/CloudFront (from orryx-standards modules)
├── .github/workflows/  GitHub Actions + OIDC (no static AWS keys)
├── .claude/
│   ├── settings.json    extraKnownMarketplaces(orryx-group) + enabledPlugins
│   └── (no local skill copies — consume from the marketplace)
├── CLAUDE.md        pointer → CLAUDE.base.md + product overrides
├── AGENTS.md        pointer → AGENTS.base.md + product overrides
└── .gitignore       canonical secret/PII block (orryx-standards/gitignore-snippets)
```

---

## Divergence Register

Existing products predate ratification. Each divergence has a rationale and a **convergence trigger** (not just a passive review date — see objection from adversarial review: "opportunistic + no forced change = permanent two-stack reality, which defeats the one-stack goal").

| Product | Divergence from canonical | Rationale | Review date / action |
|---|---|---|---|
| **Pillarworks** | EKS (not ECS) | Out-of-band accident (ADR-STACK-001), not a choice. EKS control-plane ~$72/mo of pure overhead. | **Convergence trigger SET: migrate EKS→ECS Fargate.** Dedicated migration (human-gated, touches prod): ALB-Ingress → listener rules + 2 target groups; IRSA → task roles; ESO → native Secrets Manager. EKS cluster `pillarworks-prod` (us-east-1) deleted on completion. |
| **Pillarworks** | Next.js (not Vite) | Mature production frontend; static-export keeps S3+CloudFront deploy | No forced change. Next.js is the blessed escape hatch for SEO-critical marketing properties. |
| **Pillarworks** | n8n / airflow (not Temporal) | BOQ orchestration built pre-ratification | Acceptable for internal automation; do not template. Re-evaluate only if it touches a product-critical path. |
| **Triora** | — (conformant: ECS Fargate, FastAPI, Postgres, Temporal) | The reference implementation | Closest to canonical; use as the worked example. |
| **Orryx Flow** | React + Vite ✓; ECS target pending MVP | Pre-MVP | Conform at deploy time. |

### Rules for new divergences
1. A divergence requires a one-line rationale + a **convergence trigger** (a concrete event that ends the divergence), not just a review date.
2. There is **no open "it's faster right now" escape hatch.** Client time pressure may justify a divergence, but it still needs a convergence trigger recorded here — otherwise consulting (inherently time-pressured) would legalize permanent divergence on every engagement.
3. n8n/airflow may NOT sit on a product's critical path. Temporal (above the complexity threshold) or Postgres-queue (below it) there.
4. Next.js requires a stated SSR/SEO need; default is Vite.

---

## Decision Records

Each canonical choice is (or will be) an ADR in `orryx-standards/decisions/` or the relevant repo's ADR folder:

- **ADR-STACK-001: ECS Fargate over EKS (RESOLVED)** — the Pillarworks "EKS" was an undocumented out-of-band accident (no ADR, no commits, discovered via kubectl recon), not a decision; no workload needs k8s. Pillarworks migrates EKS→ECS; no EKS module built.
- **ADR: Vite over Next.js (default)** — static S3+CloudFront deploy removes most SSR value; Next.js as SEO escape hatch.
- **ADR: Temporal for product-critical workflows** — durability/auditability for AI pipelines; n8n confined to internal automation.
- **ADR-106 (existing): Outcome-based provider router** — verified REAL working code; Anthropic primary, Bedrock for residency.
- **ADR: GitHub Actions + OIDC** — eliminate long-lived AWS keys (HA2 incident class).

---

## Engagement-delivery model (ADR-STACK-002)

Orryx does **not** publish a public or self-serve marketplace. The marketplace + stack are **internal engagement tooling**: Orryx operators use them to deliver a client's product. The client receives a working product; they never consume, authenticate into, or self-serve any Orryx marketplace. This is the resolved model — it removes the client-fit and personal-namespace concerns that an earlier "self-serve marketplace" framing carried.

**Two separable layers:**
1. **Agent layer** (marketplace plugins, CLAUDE/AGENTS conventions, safety hooks) — Orryx's internal delivery toolkit. Cloud-neutral; the **operator brings it** to each engagement. The background model (Claude tier, plugin set) is swappable as AI advances — STACK.md references the *capability*, not a frozen model, so upgrades need only a version bump.
2. **Infra layer** (ECS Fargate / Vite / FastAPI / Terraform / AWS) — Orryx's reference stack, **adapted to the client's cloud/constraints per engagement.**

**Client-context fit is an engagement-scoping matter, not a distribution blocker.** A non-AWS, GCP/Azure, on-prem, or data-sovereignty client changes how Orryx adapts the *infra layer* for that engagement; the agent layer travels with the operator regardless. There is no requirement for the client to host or authenticate into the marketplace.

**`orryx-group` org migration — recommended, non-blocking.** Sourcing internal tooling from a personal account (`alexmclaren/...`) carries bus-factor risk and weaker professional optics (a client glimpsing `github.com/alexmclaren/...` during a paid engagement). Migrate to `orryx-group` before the first client engagement; founder-timed, no longer gating STACK.md or the factory.

The marketplace must stay CLI-valid and installable for Orryx's own internal use (the WC.0 fix, 2026-06-10, was the precondition; live-validated in WC.3).

---

## Change control

Changes to this file require: a rationale, an updated/new ADR, and a version bump. The product template and the divergence register are updated in the same change. Material changes are `[REQUIRES HUMAN REVIEW]` per CLAUDE.md §7.
