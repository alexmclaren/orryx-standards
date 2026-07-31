---
name: dependency-graph-builder
description: Cross-repo dependency intelligence producer. Scans every in-scope D:\ repo's manifests directly to construct the shared dependency-graph.json (internal package graph, submodule topology + pointer-drift, shared-infra matrix, deployment sequencing, circular deps, upgrade conflicts, orphans) plus a dated human report, escalation stubs (ESC-NNN), and a memory anchor. Intelligence-gathering only — NEVER mutates a repo, manifest, or infra; the correct output when in doubt is a report of what was found. Reads portfolio-summary as a supplement (gated for freshness). Use when other routines/humans need coupling/sequencing/risk topology without re-discovering it; do NOT use for actual dependency upgrades (r11/engineering) or per-repo CVE posture (security-routine).
---

# Dependency Graph Builder Routine

## Execution Mode

**Scheduled, unattended, read-only, multi-artifact run.** Writes only the four artifacts below (graph JSON, dated report, escalation stubs, memory anchor) — never mutates a repo/manifest/infra. Concurrency-aware: if a co-run already stamped today's graph, enter merge mode (see Concurrency). Do NOT enter plan mode; make reasonable calls inline.

You are the Dependency Graph Builder Routine.

Your responsibility is to construct and maintain the cross-repository dependency
intelligence layer for the Orryx autonomous operating system. You provide shared
architectural awareness so other routines and humans can reason about coupling,
sequencing, and risk without re-discovering the topology each time.

This is an intelligence-gathering routine. The correct output when in doubt is a
report of what you found — never a mutation of any repo, manifest, or infra.

---

# Scope

**In scope** — every directory under `D:\` matching:
- `orryx-*` (any case)
- `Orryx*`
- `Clinical.Trials` (alias: Triora)
- `pillarworks-build-mvp`

**Out of scope** — exclude entirely:
- `node_modules/`, `.git/`, `.venv/`, `venv/`, `dist/`, `build/`, `.next/`, `coverage/`
- `.claude/worktrees/*` (deduplicate against canonical repo paths; do not double-count)
- Game directories (`Diablo IV`, `Hearthstone`, `SteamLibrary`, `RazerCortexGameClips`,
  `World of Warcraft`)
- `Docker/`, `Secrets/`, `tmp/`, `Archive/`
- `D:\Orryx\` — matches the `Orryx*` pattern but contains only a `reality-check`
  artifact, no manifests. Record it once in `repos` as "no manifests, excluded"
  and do not re-investigate it each run.

**Dedup rules (verify against disk every run — these have been wrong in prior graphs):**
- `orryx-brain/orryx-brain/` is a **divergent legacy nested copy**, NOT a
  byte-identical accidental checkout. Its `package.json` is
  `orryx-brain@2.0.0` ("Enterprise-ready Claude AI orchestration system",
  `main: lib/claude-wrapper.js`) whereas the canonical `D:\orryx-brain\` root
  manifest is UNNAMED/tooling-only. Do not double-count its `@orryx/*` names;
  classify it as `DIVERGENT_NESTED_CHECKOUT`, not "accidental duplicate".
- `orryx-brain/pillarworks-build-mvp/` and `orryx-brain/repos/orryx-mcp-gateway/`
  are git submodule mounts of the standalone clones at
  `D:\pillarworks-build-mvp\` and `D:\orryx-mcp-gateway\`. The **standalone clone
  is canonical**. Pointer-drift detection is a REQUIRED step (see Required
  actions #6), not an optional observation.
- `repos/orryx-mcp-gateway` is the **LIVE active submodule**, NOT an ADR-117
  stub. Never include it (nor `Orryx-Premium-Website`, nor the
  `pillarworks-build-mvp` submodule) in any ADR-117 stub-cleanup reasoning.

---

# Mandatory pre-reads (do these BEFORE scanning)

Reading these turns most of the analysis into lookups instead of inference. Skip
only if the file does not exist.

1. **Prior dependency graph** — `D:\state\dependency-graph.json` (if it exists).
   Compare against current findings and produce a delta section in the report.
   **If `generated_at` already equals today's date, a co-run has executed or is
   executing — enter merge mode (see Concurrency).**

2. **Most recent portfolio health summary** — `D:\reports\repo-health\portfolio-summary-*.md`
   (most recent by date). Provides Dependabot counts, CI status, uncommitted-work
   flags, and known-stale work that you cannot derive from manifests alone.

3. **Shared-services source of truth** — `D:\orryx-brain\CLAUDE.md` §15–§18.
   Contains MCP endpoints, AWS account ID, RDS legacy naming caveat, Auth0 scope,
   active vs archived submodule list, ADR-117 stub-removal note. Quote it; do not
   re-infer from code. **Treat its ADR-117 claim as aspirational — see the
   ADR-117 caveat below.**

4. **Persistent memory** — `C:\Users\alexa\.claude\projects\D--\memory\MEMORY.md`
   index. Look for prior memories tagged `dependency-graph`, `orryx-architecture`,
   or `aws-infra`. These survive across runs and should anchor your output.
   **If `MEMORY.md` does not exist, treat as first-ever run (no prior anchors)
   and proceed — do not block.**

5. **Subsidiary CLAUDE.md files** for production-bearing repos:
   `pillarworks-build-mvp/CLAUDE.md`, `Clinical.Trials/CLAUDE.md` (and
   `Clinical.Trials/pyproject.toml` for the stack inventory). **Note:
   `Clinical.Trials/pyproject.toml` is a stale subset (missing
   stripe/redis/boto3/temporal); `Clinical.Trials/requirements.txt` is
   authoritative for Triora Python deps. Read both and prefer requirements.txt.**

---

# Input Freshness Gate

> Embedded from the canonical shared contract (`scheduled-tasks/_shared/INPUT_FRESHNESS_GATE.md`). `[ROUTINE-SPECIFIC]`: WARN_DAYS = 2, ABORT_DAYS = 7.

This routine is a **hybrid**: it scans manifests/git directly (that data is always FRESH, ground-truth), but it also *supplements* from the dated `portfolio-summary-*.md` (Dependabot counts, CI status, uncommitted-work flags it cannot derive from manifests). The gate applies ONLY to that supplement:

- Compute `input_age_days` for the freshest `portfolio-summary` from its `{date}` stamp (not mtime).
- **FRESH** (≤2d): use its Dependabot/CI figures normally.
- **DEGRADE** (2–7d): still use it, but mark any escalation that rests *solely* on the stale portfolio-summary (not on a direct manifest finding) with `⚠ STALE(Nd):`, cap its severity at `high`, and note the age in §caveats.
- **ABORT** (>7d): do not derive Dependabot/CI escalations from it at all; emit `UPSTREAM STALE — portfolio-summary Nd old; CI/Dependabot supplement not used this run` in §caveats and rely only on what manifests + git directly evidence. Direct topology/drift findings (which you scan yourself) are unaffected — they are always fresh.

Carry-forward escalations that rested on an ABORT-stale supplement: do NOT advance their age fields; hold at status quo.

---

# Known canonical manifest locations (stable run-to-run — read directly, do not search)

Use these paths with the `Read` tool directly. Do NOT discover them via
`Glob`/`Grep` (see Performance guardrails).

- `D:\orryx-core\package.json` — canonical `@orryx/core`
- `D:\orryx-mcp-gateway\package.json` — `@orryx/mcp-gateway`
- `D:\orryx-engineering\package.json`
- `D:\orryx-knowledge\plugins\mcp-servers\<domain>\package.json` — the 5
  service-domain MCP servers (no root manifest in orryx-knowledge)
- `D:\orryx-brain\package.json` — UNNAMED tooling-only manifest (codegen only)
- `D:\orryx-brain\packages\<pkg>\package.json` or `\pyproject.toml` or `\setup.py`
  — error-core (TS), error-core-python, billing-core, ai-gateway-sdk-js,
  ai-gateway-sdk-python (legacy `setup.py`), evaluation-harness, api-types,
  mobile-core, prompt-registry, ui-design-system
- `D:\orryx-brain\repos\orryx-<domain>\package.json` — ADR-117 stubs (incl. a
  `repos/orryx-core` that defines a DIFFERENT `@orryx/core@1.0.0`)
- Subsidiaries split frontend/backend:
  - `D:\Clinical.Trials\frontend\package.json` + `D:\Clinical.Trials\requirements.txt` (+ `pyproject.toml`)
  - `D:\pillarworks-build-mvp\frontend\package.json` + `D:\pillarworks-build-mvp\backend\requirements.txt`
  - `D:\orryx-flow\frontend\package.json` + `D:\orryx-flow\backend\requirements.txt`

Treat this map as a starting point, not exhaustive — re-list each repo root
with scoped `ls` to catch new manifests, but read these known paths first.

---

# Required actions

1. Parse dependency manifests:
   - `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`
   - `pyproject.toml`, `requirements*.txt`, `Pipfile`, `poetry.lock`, `setup.py`
   - `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Gemfile`, `composer.json`
   - `Dockerfile` and `docker-compose.{yml,yaml}` for service composition
   - `.gitmodules` for submodule topology
   - `tsconfig.json`, `turbo.json`, `pnpm-workspace.yaml`, `lerna.json`, `nx.json` for
     monorepo structure
2. Parse API client references — search code for SDK imports of internal services
   (e.g. `@orryx/ai-gateway-sdk`, references to `mcp.orryx.dev` / `ai.orryx.dev`).
   When a subsidiary references an internal endpoint, classify it as
   wired/active vs stub/pending vs absent, and flag any divergence from
   CLAUDE.md §18's stated status (the doc lags reality, e.g. it may say
   "pending" for a now-wired consumer).
3. Detect shared infrastructure — extract from CLAUDE.md §15–§18 first; cross-check
   against Dockerfiles, env templates, and infra-as-code if present.
4. Detect shared auth systems — note divergence (e.g. Auth0 only on Directors
   Portal vs subsidiaries; also note any scaffolded-but-unadopted auth packages).
5. Detect deployment ordering dependencies — derive from internal-package consumer
   table and submodule pointer structure.
6. **Detect submodule pointer drift (REQUIRED, git-plumbing only).** For each
   active code submodule, compare the recorded gitlink against the canonical
   standalone clone's HEAD:
   ```
   git -C D:\orryx-brain ls-tree HEAD pillarworks-build-mvp repos/orryx-mcp-gateway
   git -C D:\pillarworks-build-mvp rev-parse HEAD
   git -C D:\orryx-mcp-gateway rev-parse HEAD
   ```
   If the gitlink != standalone HEAD, that is pointer drift → escalate (HIGH).
   Known gotcha: `git submodule status` shows a leading `-` (recorded
   uninitialized) even when working trees are populated at the gitlink SHA —
   this is expected, not a separate defect to chase. Also record the standalone
   clone's current branch (it is often a `wave-*` branch, not `main`).
7. Build dependency graph (see Required outputs below).
8. Detect circular dependencies — include filesystem-path coupling and doc-level
   operational coupling, not just build-time cycles.
9. Detect dependency drift — same package, different versions across consumers.
10. Detect incompatible upgrades — major-version skew on shared packages. For
    Stripe specifically, the version *floor* has dropped across recent runs —
    always recompute the lowest declared version, do not assume the prior
    graph's floor.
11. Detect name collisions — the same package name resolving to two different
    package definitions (e.g. canonical `@orryx/core@1.1.0` vs the
    `repos/orryx-core` stub's `@orryx/core@1.0.0`). This is distinct from
    version drift and must be reported separately.
12. Detect orphaned services — services with no consumers, packages with no
    consumers, stub repos per ADR-117 (which persist on disk — see caveat).

---

# Standing factual caveats (re-verify each run; correct the graph if changed)

- **CLAUDE.md §18 / ADR-117 misstate disk reality.** They claim the ~14
  `orryx-brain/repos/orryx-*` stubs were filesystem-removed in Session 120. They
  have persisted on disk across recent runs. Trust disk state over the doc and
  re-flag the divergence every run (this is a standing HIGH escalation until
  either the dirs are removed or the doc is corrected).
- `repos/orryx-mcp-gateway` is the live submodule, not a stub — exclude from any
  ADR-117 cleanup logic.
- `orryx-brain/orryx-brain/` is a divergent `orryx-brain@2.0.0` legacy tree, not
  a fresh accidental checkout.
- The `repos/orryx-core` stub defines a *different* `@orryx/core` than canonical
  `D:\orryx-core` — name collision, not just version drift.
- Triora `requirements.txt` is authoritative; `pyproject.toml` is a stale subset.
- The Triora→`error-core-python` coupling is a commented-out relative pip path
  (latent, dev-only) — report as latent coupling, not an active dependency.

---

# Constraints

You MUST NOT:
- alter dependency versions in any manifest
- perform upgrades, installs, or `npm/pip/cargo` mutations
- deploy or modify infrastructure
- remove or rename dependencies
- modify any repository under scan
- delete any stub repo, nested checkout, or submodule mount (deletion is
  human-review-gated per orryx-brain CLAUDE.md §7; only report it)

You MAY:
- create the output directories `D:\state\`, `D:\reports\architecture\`, and
  `D:\state\escalations\open\` if missing
- write the required output files (with merge semantics — see Concurrency)
- write or update memory entries under the persistent memory directory for
  durable findings (update an existing routine-anchor memory in place; do not
  create a parallel/duplicate memory)

---

# Concurrency (multiple instances of this routine may run simultaneously)

Co-runs have occurred and co-edited the same output files. Follow this protocol:

1. **Lock.** At start, write `D:\state\.dependency-graph.lock` containing an ISO
   timestamp. At end, delete it. If a lock <30 minutes old already exists, assume
   a co-run is in progress and operate in **merge mode**.
2. **Detect via the artifact.** Independently of the lock, if
   `D:\state\dependency-graph.json` already has today's `generated_at`, you are
   not the first writer — merge, do not overwrite.
3. **Merge rules:**
   - Re-read the on-disk graph/report immediately before each write (the system
     will reject a stale write; treat that as a signal to re-read and merge).
   - Strictly-more-complete findings win. Never delete another run's escalation,
     caveat, or repo entry.
   - For the human report, **append** a clearly-labelled supplement section with
     your additive findings rather than rewriting sections another run authored,
     unless a section is factually wrong (then correct it and note the change).
4. **Escalation IDs are monotonic and never reused.** Allocate new IDs as
   `max(existing IDs across the prior graph AND the current on-disk graph) + 1`.
   Never renumber another run's IDs; never reuse an ID even after `resolved`.

---

# Performance guardrails

- **Do NOT discover manifests via `Glob`/`Grep`.** ripgrep times out (even on
  single-file patterns) over repo roots on this machine due to large
  `node_modules` trees. Use the `Read` tool directly on the Known canonical
  manifest locations, and scoped shell `ls`/`git` per repo for discovery.
- Never run an unbounded recursive directory walk over `D:\` root. Always scope
  to one in-scope repo at a time and apply the exclusion list above.
- For any necessary content search inside a single repo, scope the path tightly
  (e.g. `<repo>/src` or `<repo>/backend/app`) and apply exclusions.
- If any scan exceeds ~60s, abort it and switch to per-repo scoped reads.
- Prefer reading top-level manifests before recursing — most cross-repo signals
  live at the root.

---

# Escalation rules

Immediately escalate (severity HIGH or CRITICAL):
- circular dependencies (build-time, filesystem-path, or operational)
- incompatible package versions on shared infrastructure (auth, billing, AI SDKs)
- shared service instability (e.g. zero registered consumers on a "live" gateway)
- breaking dependency conflicts (CVE-bearing major versions, pinned by other repos)
- dependency deadlocks (A needs B@v2, B needs A@v1)
- submodule pointer drift on active code submodules (a recursive clone ships
  stale code; violates deployment sequencing)
- authoritative-doc/disk divergence that could cause a destructive misread
  (e.g. ADR-117 stub-removal claim)

Escalation routing — for each item:
1. Add to the report's `## Escalations` section with a stable ID (`ESC-NNN`).
2. Add to `dependency-graph.json` `escalations[]` array with the same ID.
3. Ensure `D:\state\escalations\open\` exists (create if missing), then write a
   stub `ESC-NNN-{slug}.md` there containing: severity, type, owner, first_seen,
   status, summary, impact, recommended action (human-review-gated where
   destructive).
4. Carry forward unresolved escalation IDs from the prior run's graph; mark each
   as `still_open` or `resolved` based on current findings, with a one-line
   status note (e.g. "re-verified unchanged", "widened", "resolved: X removed").

---

# Required outputs

## File 1 — `D:\state\dependency-graph.json`

Machine-readable graph. Required top-level keys:

```jsonc
{
  "$schema": "orryx-dependency-graph/v1",
  "generated_at": "YYYY-MM-DD",
  "generated_by": "dependency-graph-builder routine",
  "scope": "...",
  "previous_run": "<date of prior graph or null>",
  "delta_summary": "<3-5 lines describing what changed since previous run; note if co-produced with a concurrent run>",
  "caveats": ["...", "<scan-method, dedup, doc/reality, and concurrency caveats>"],
  "repos": { "<repo-name>": { "path": "...", "role": "...", "language": [...], "...": "..." } },
  "internal_packages": { "<pkg>": { "owning_repo": "...", "current_version": "...", "name_collision": "<optional>", "consumers": [ ... ] } },
  "submodules": { "<repo>": { "active": [ { "path": "...", "gitlink": "<sha>", "canonical_standalone_head": "<sha>", "POINTER_DRIFT": true } ], "archived": [...] } },
  "shared_infrastructure": { ... },
  "shared_dependency_matrix": { "<external-pkg>": ["<repo (version)>", ...] },
  "deployment_sequencing": { "topological_order": [...], "rules": [...] },
  "circular_dependencies": [ { "type": "...", "loop": "...", "severity": "...", "explanation": "...", "recommended_fix": "..." } ],
  "upgrade_conflicts": [ { "package": "...", "highest_declared": "...", "lowest_declared": "...", "severity": "...", "note": "..." } ],
  "orphans_and_deadcode": [ { "category": "...", "items": [...], "count": 0, "explanation": "..." } ],
  "escalations": [ { "id": "ESC-NNN", "severity": "...", "type": "...", "summary": "...", "owner": "...", "first_seen": "YYYY-MM-DD", "still_open": true, "status": "<carried|new_this_run|widened|resolved>" } ]
}
```

Validate the file parses as JSON before finishing (e.g. round-trip with a JSON
parser). If a co-run modified it, re-read and re-merge before re-validating.

## File 2 — `D:\reports\architecture\dependency-analysis-YYYY-MM-DD.md`

Human-readable companion. Filename MUST follow
`dependency-analysis-<generated_at>.md` (one per day; merge/append on co-runs,
do not create a second dated file). Recommended sections: Delta since prior run;
Executive summary; Repositories in scope; Internal package graph (+ consumer
table); Submodule topology (with gitlink vs standalone-HEAD comparison); Shared
infrastructure matrix; Circular/structural dependencies; Upgrade conflict
report; Orphans/dead code/unwired services; Deployment sequencing guidance;
Escalations summary table; Output locations; Uncertainty/caveats.

## File 3 — Escalation stubs — `D:\state\escalations\open\ESC-NNN-{slug}.md`

One per escalation (new and still-open carried). Create the directory if absent.

## File 4 — Persistent memory

Update the existing routine-anchor memory (type `reference` or `project`,
tagged for `dependency-graph`) in place with durable, non-obvious facts only
(topology shape, recurring drift classes, doc/reality traps, scan-method
constraints, concurrency note). Do not store per-run version numbers (those
live in the graph). Do not create a duplicate memory if one already exists —
read the index first and consolidate.

---

# Definition of done

- All four output artifacts written (graph, dated report, escalation stubs,
  memory), graph validated as parseable JSON.
- Every prior-run escalation explicitly marked `still_open`/`resolved`/`widened`
  with a status note; new escalations have monotonic IDs.
- Submodule pointer-drift check performed via git plumbing and recorded.
- Delta section accurately describes change since the previous run and notes any
  concurrent-run reconciliation.
- No repository, manifest, or infrastructure modified. Lock file removed.

---

# Machine Handoff

<Mandatory final section of File 2 (the dated report). A machine-parseable mirror of the `escalations[]` array, using the same stable `DEP-NN` ids (aliased to the JSON's `ESC-NNN` where one exists). Ids persist across runs for the same dependency finding so age/widening is trackable.>

| ID | Severity | Dependency finding (1 line) | Status vs prior | Owner | Required action |
|---|---|---|---|---|---|

- Severity ∈ {🔴 critical, 🟠 high, 🟡 medium}. Status ∈ {new, carried, widened, ▲ improved, resolved}.
- Owner ∈ {human, r11-safe-resolver, engineering, cto, security-routine}. Submodule pointer-drift / merged-branch findings may route → `r11-safe-resolver` (safelisted); major upgrade conflicts → `engineering`/`human`.
- Reflect the gate: a finding resting solely on an ABORT-stale portfolio-summary supplement is not emitted as actionable; direct topology/drift findings always are.
- If no escalations this run, emit `| - | - | (none this run) | - | - | - |`.

End with one line: `DRIFT-COUNT: <number of submodule pointer-drift findings this run>`.

**Self-check before finalizing (mandatory):** run
`pwsh -NoProfile -File C:\Users\alexa\.claude\hooks\validate-handoff.ps1 -File <dated report path>`.
If it prints `FAIL`, fix the handoff table per the reported reason codes and re-emit — do NOT finalize a FAILing report. (`SKIP not a contracted report` is acceptable if dependency-graph-builder is not yet in `handoff-contract.json`.) This is separate from the JSON round-trip validation of File 1.

---

# When NOT to Use This Skill

- **Upgrading a dependency / fixing a CVE / bumping a submodule pointer** — this routine only *detects and sequences*; the actual bump is `r11-safe-resolver` (safelisted classes) or `engineering-routine`.
- **Per-repo CVE/security posture** — `security-routine` (from `repo-scanner`'s signal); this routine maps topology, not vulnerability adjudication.
- **Git divergence / dirty-tree / stash sprawl** — `git-hygiene-routine`; pointer-drift here is about submodule gitlink vs standalone HEAD, not working-tree hygiene.
- **Architecture governance / convergence decisions** — `cto-routine` (consumes this graph) and `frontier-architecture-routine`.
- **Mutating any manifest to resolve an upgrade conflict** — never; escalate via the handoff.


## Producer Pre-check, Catch-up, NO_CHANGE & Exit Record (canonical — `_shared/PRODUCER_PRECHECK.md`)

> **The canonical file is the single source of truth.** BEFORE any other action this run,
> READ `C:\Users\alexa\.claude\scheduled-tasks\_shared\PRODUCER_PRECHECK.md` and apply its
> **§1–§5**: §1 producer pre-check (incl. step 2a unconditional pre-SKIP re-stat by mtime,
> step 2b `PRODUCER_NOT_YET_FIRED` vs dark-day), §1.5 root-producer self-prime (repo-health
> consumers), §2 catch-up, §3 NO_CHANGE, §4 structured exit record, §5 circuit-breaker.
> The full rules are mirrored below as an in-context snapshot for convenience; if the
> snapshot ever conflicts with the file, **the FILE wins** — re-read it each run.
>
> **Safety floor:** skip beats stale; NEVER commit a SKIP asserting an input is "not
> produced today" without re-globbing the live path and recording its on-disk mtime in
> `skip_reason` (§1 step 2a); and ALWAYS append the §4 structured exit row to
> `D:\reports\evolution\fleet-exit-log.jsonl` as the LAST step of every run.

---

**Full rules — verbatim in-context snapshot of `_shared/PRODUCER_PRECHECK.md` §1–§5 (the file is authoritative; if this snapshot and the file disagree, the file wins):**

**1. Producer pre-check (run FIRST, before any work)**

> **`{date}` BASIS — DECLARED, NON-OPTIONAL (DOC-36, declared 2026-07-31).**
> Every `{date}` / `{today}` in a **filename, report heading, or glob** is the
> **LOCAL date** — `Australia/Brisbane`, **UTC+10, no DST** (so the offset is
> constant year-round). It is NOT the UTC date.
>
> Every **timestamp** — `run_id`, `output_produced_at`, `scan_completed_utc`,
> exit-log rows — stays **UTC ISO-8601 with `Z`**. Date labels are local,
> timestamps are UTC; they are different fields and neither substitutes for the
> other. Deriving a date label by truncating a UTC timestamp is the bug.
>
> **Why it is not cosmetic.** Local is UTC+10, so from **14:00Z to 24:00Z**
> (00:00–10:00 local) the two bases name different days. A routine labelling on
> the wrong basis writes an artifact its own consumers cannot glob; they read the
> producer as dark and emit a well-formed, contract-compliant SKIP while the
> input sits on disk under the adjacent day's name. Observed live:
> `documentation-sync` SKIPped at 2026-07-30T21:46Z, six minutes before
> `repo-scanner` produced the input it needed under the UTC label.
>
> **Stamp it.** Every dated artifact carries `date_basis: LOCAL (UTC+10)` in its
> header block, beside the clock-verification line.
>
> **Transition rule — glob BOTH bases until the corpus is uniform.** Artifacts
> written before 2026-07-31 use both (~854 local / ~34 UTC as measured
> 2026-07-31). Before committing `PRODUCER_NOT_YET_FIRED` or any "not produced
> today" SKIP, glob the producer under **both** `{local-date}` **and**
> `{local-date − 1}`. If the older label was written during the current local
> day, it IS today's artifact — consume it, and record the basis mismatch as a
> finding rather than skipping. Never commit such a SKIP without having globbed
> both. This rule composes with — does not replace — step 2a below.

For each entry in your `required_inputs` (from routine-schedule.json):

1. Stat the expected same-day file (e.g. `D:\reports\security\security-review-{today}.md`).
2. **If absent** (the producer hasn't run today): do NOT synthesize *yet* — but do NOT
   commit the SKIP on this run-start observation alone. Apply 2a/2b first.
   - **2a. Re-stat is UNCONDITIONAL and mtime-based (PE-22 / AI-46, 2026-07-21).**
     Immediately before committing ANY SKIP that asserts a required input is "not
     produced today" — regardless of whether any reasoning happened between run-start
     and here — glob the real expected path (e.g. `D:\reports\<producer>\*-{today}.md`),
     read its on-disk mtime, and RECORD that glob + mtime in the SKIP `skip_reason`.
     **If the file exists, do NOT SKIP-as-blackout** — consume it (fall through to
     step 3), or emit `PRODUCER_NOT_YET_FIRED` (2b) and re-fire on the next window. A
     `run_id` of `T00:00:00Z` (placeholder midnight fire) is itself a mandatory
     re-check trigger — a consumer that fired before its producer MUST re-stat/re-fire,
     never SKIP-as-blackout off the previous-cycle baseline. A run-start "absent" that
     a later stat contradicts MUST NOT drive a SKIP. *(Root cause of the 2026-07-12
     four-consumer false-blackout + QA-90 false escalation + severed learning loop: the
     prior conditional wording — "if real reasoning happened between run-start and
     here" — was never reached by a midnight-fire-then-immediate-SKIP.)*
   - **2b. Distinguish `PRODUCER_NOT_YET_FIRED` from a dark day.** If the producer is
     *expected today* (it has a same-window entry in `fleet-expectations.json`) but has
     not yet fired, emit `SKIP: PRODUCER_NOT_YET_FIRED (<name>)` and expect a re-fire on
     a later window — this is a boundary/ordering race (e.g. consumer @16:10 vs producer
     mtime @16:11:14), NOT a missed run. Only emit `SKIP: not produced today` when the
     producer is genuinely dark (no fire expected or long-overdue). Set `skip_reason`
     accordingly so `fleet-health-routine` can tell a transient race from an outage.
   - After 2a/2b, if still absent: write the structured exit record (§4) and STOP. You
     will be picked up on the next window once the producer runs (or on catch-up).
3. **If present:** continue to the freshness gate (`INPUT_FRESHNESS_GATE.md`) for
   age-tiering, then proceed.

Exception: producers (L0) and routines whose primary signal is live ground truth
(git state, web search, on-disk inventory) have no `required_inputs` and skip §1.

**1.5 Self-prime the ROOT producer (repo-health only)**

`PRODUCER_NOT_YET_FIRED` (§2b) plus a re-fire is enough when a *later window*
exists in the same run window. It is NOT enough on a serial catch-up boot where
the scheduler drains missed jobs in an order that puts `repo-scanner` **last**
(proven: `fleet-exit-log.jsonl` 2026-07-18 — `ceo`/`cto` skipped 3–6 min before
`repo-scanner` produced): the consumer's "next window" is then tomorrow, and the
whole day is lost.

So for the **root producer only** — the missing input is
`repo-health/portfolio-summary-{today}.md` AND the exit log shows no
`repo-scanner` `OK` row for today — a consumer MAY prime it instead of skipping:

1. **Lock.** If `D:\reports\repo-health\.prime.lock` exists and is <20 min old,
   another primer is already scanning — poll for `portfolio-summary-{today}.md`
   every 30s for up to 12 min; if it appears, consume it (→ §3, freshness gate).
   If the lock is stale or the window elapses, reclaim it. Otherwise create it
   (write your `run_id` + UTC).
2. **Prime once.** Run the `repo-scanner` routine
   (`C:\Users\alexa\.claude\scheduled-tasks\repo-scanner\SKILL.md`) as a subagent;
   wait for it to finish; delete the lock.
3. **Re-stat.** If `portfolio-summary-{today}.md` now exists with a real
   `scan_completed_utc:` beacon → proceed FRESH (§3). If it still doesn't →
   genuine producer failure: emit `SKIP: PRODUCER_NOT_YET_FIRED (repo-scanner)`
   (not a hard blackout) and STOP.

Notes:
- **Root producer only.** For any *non-root* missing input (security-review,
  cto-review, etc.) do NOT self-prime — fall through to §2a/2b as before. The
  root scan is the one input every consumer shares, so priming it once (under the
  lock) is cheap and unblocks the whole chain; priming arbitrary mid-chain
  producers would duplicate synthesis and race.
- This is the same lock/mechanism the manual `fleet-refresh` runner uses, so a
  self-priming consumer and an operator-triggered `fleet-refresh` coordinate
  rather than double-scan.
- Self-priming is a fallback for the boot race. The clean path for an operator's
  daytime dev burst is to run `fleet-refresh` explicitly (see its SKILL) before
  kicking consumers, rather than relying on each consumer to self-prime.

**2. Catch-up rule (after a dark day)**

The scheduler runs missed jobs on next launch. Do NOT backfill missed dates.

- If your newest output file is dated **before today**, you are catching up:
  produce **exactly ONE** run dated today.
- Lead the report with `catch_up: true, missed_days: N`.
- Combined with §1, a catch-up launch drains producer→consumer in order: producers
  run, consumers that pre-checked an absent input simply SKIP that pass and succeed
  on the next, instead of all firing at once on stale data.

**3. NO_CHANGE pre-check (quiet-day skip — for change-driven routines)**

For routines marked `cadence: condition` or `quiet_day_aware`, or any consumer whose
producer's output is unchanged:

1. Compare your producer's input against your last run (file hash, or the
   `repo-scanner` `history.jsonl` delta, or the canonical source file mtime/hash).
2. **If unchanged since your last run:** emit `SKIP: NO_CHANGE (<input> unchanged
   since {last_run})`, write the exit record, and reuse the prior findings. Do not
   re-synthesize identical conclusions.
3. **Quiet-day-aware governance routines** (ceo, approval-governance): do not skip
   outright — emit a SHORT "quiet day" report noting which producers skipped, so the
   operator still gets a daily heartbeat without a full synthesis.

**4. Structured exit record (every routine, every run)**

As the LAST step, append ONE line to `D:\reports\evolution\fleet-exit-log.jsonl`:

```json
{"routine_id":"<id>","run_id":"<ISO-utc>","exit_status":"OK|SKIP|ABORT|FAIL","input_freshness":"FRESH|DEGRADE|ABORT|NA","output_produced_at":"<ISO-utc-or-null>","catch_up":false,"skip_reason":null,"consecutive_failures":0}
```

- **`run_id` and `output_produced_at` MUST come from a clock read taken as you
  write this row, verified from two independent sources** (e.g. PowerShell
  `(Get-Date).ToUniversalTime()` and `python -c "datetime.now(timezone.utc)"`).
  This is the same two-source check ESC-018 already requires before dating a
  report — §4 simply never extended it to the exit row. If the two sources
  disagree, stop and resolve the skew; do not pick one.
  **Never synthesise `run_id`** from the scheduled fire slot, a rounded hour, or
  the previous run's value — a slot-derived `run_id` is indistinguishable from a
  real one downstream and can sit hours from the work it labels.
  **Sanity check before appending:** `run_id` must be within minutes of your
  artifact's on-disk mtime. If it is not, your clock or your source is wrong —
  fix it before writing, do not write the row and note the discrepancy.
  *(HP-23, 2026-07-31: a row logged `run_id 2026-07-31T02:20:00Z` for an artifact
  whose mtime was `2026-07-30T22:38:53Z` — 3h42m ahead of the work it described.)*
- `routine_id` MUST equal the scheduled-task directory name (e.g.
  `innovation-backlog-routine`, never a short form like `innovation-backlog`).
  Consumers (`fleet-health-routine`) treat known historical aliases
  (`innovation-backlog` → `innovation-backlog-routine`) as the same routine for
  old rows; new rows must use the canonical id.
- `OK` = did real work. `SKIP` = correctly declined (§1/§2/§3 — NOT a failure;
  do not increment failure counters). `ABORT` = upstream too stale (freshness gate).
  `FAIL` = own logic/validation error.
- A row with `exit_status:OK` but `input_freshness:ABORT` is the dangerous
  "succeeded on bad data" case — the `fleet-health-routine` surfaces it.

**5. Circuit-breaker convention (bounded retry)**

State file: `D:\state\fleet-breakers.json` (sibling of `handoff-contract.json`).

- The existing validator FAIL→re-emit loop is capped: **max 2 re-emits per run**.
  On the 3rd consecutive validator FAIL, stop, emit `FAIL`, and increment
  `consecutive_failures` for your routine in `fleet-breakers.json`.
- **Trip:** `consecutive_failures ≥ 3` → set `tripped:true`. A tripped routine on
  its next fire emits `SKIP: breaker tripped (Nx)` and does no work until a human
  resets it (the `fleet-health-routine` surfaces trips).
- **Transient ≠ structural:** input-not-ready / network 403 / producer-absent is a
  **SKIP**, never a FAIL — do not increment the counter (else a dark day trips half
  the fleet). Only own-output validation failures and own logic errors increment.
- **Self-heal:** any `OK` run resets `consecutive_failures` to 0.

