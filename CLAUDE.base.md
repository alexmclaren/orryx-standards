# CLAUDE.base.md — Canonical Claude Execution Protocol

**Version:** 2.0.0
**Last Updated:** 2026-05-18
**Status:** Production Ready
**Changes:** Added context management, read-before-edit governance, retry governance, Pinecone integration

> This is the **canonical source of truth** for Claude Code behavior across all Orryx repositories.
> Individual repos reference this file and add minimal overrides only.
>
> **Token savings:** Using this canonical baseline reduces CLAUDE.md from ~85K → ~13K tokens per repo (~85% reduction)

---

## How to Use This File

**In your repository's CLAUDE.md:**

```markdown
# {Repository} — Claude execution protocol

> **Canonical source:** [CLAUDE.base.md in orryx-standards](https://github.com/alexmclaren/orryx-standards/blob/main/CLAUDE.base.md)
> Read that first for the shared Claude execution protocol.

## {Repository}-specific overrides
[Add only repo-specific rules here]
```

---

# 0. 🚨 CORE OPERATING PRINCIPLES (NON-NEGOTIABLE)

### 0.1 PLAN MODE FIRST (MANDATORY)

Claude MUST NOT begin implementation immediately.

Every non-trivial task MUST start with:

1. **PLAN MODE**
2. **Human approval (if required) OR autonomous continuation**
3. **EXECUTION MODE**

---

### 0.2 AUTONOMOUS DELIVERY DEFAULT

Default assumption:

> Claude operates autonomously until the task is fully complete.

Claude should:
- Continue working without waiting for input
- Resolve gaps independently where safe
- Only stop when:
  - Blocked by external dependency
  - Requires human approval
  - Reaches defined completion criteria

---

### 0.3 ACCEPTANCE CRITERIA FIRST

Before any work begins, Claude MUST define:

- What “DONE” looks like
- How it will be verified
- What success metrics exist

If this is unclear → Claude must define it.

---

### 0.4 PRODUCTION REALITY > ASSUMPTIONS

Claude must always validate:

- What ACTUALLY exists (APIs, DB, infra)
- What is BROKEN vs PLANNED
- What is MOCKED vs REAL

Never trust:
- Docs
- Frontend assumptions
- Old schemas

Always verify against:
- Running system
- Logs
- API responses

---

# 1. EXECUTION FRAMEWORK

---

## 1.1 PLAN MODE (REQUIRED)

Claude must output structured plan before acting:

### PLAN MODE OUTPUT

1. **Objective**
2. **Current State (Reality Check)**
3. **Target State**
4. **Gaps Identified**
5. **Approach Options (if applicable)**
6. **Chosen Approach**
7. **Step-by-Step Execution Plan**
8. **Risks**
9. **Acceptance Criteria**
10. **Autonomy Level (L0–L3)**

---

## 1.2 EXECUTION MODE

Once plan is accepted or auto-approved:

Claude executes using:

### BMAD+

1. **Breakdown**
2. **Map**
3. **Act**
4. **Deliver**
5. **Validate (NEW — mandatory)**

---

## 1.3 RALPH LOOP (MANDATORY FOR COMPLEX TASKS)

For any meaningful build:

Repeat until complete:

1. Implement
2. Test
3. Verify
4. Identify gaps
5. Fix
6. Repeat

Minimum: **2–3 iterations**

---

## 1.4 PARALLELISM & SWARMING

Claude should:

- Run tasks in parallel where possible
- Use subagents strategically:
  - explorer → discovery
  - test-writer → TDD
  - code-reviewer → validation
  - security-reviewer → compliance

---

# 2. AUTONOMY MODEL

---

| Level | Behaviour |
|------|----------|
| L0 | Fully supervised |
| L1 | Checkpoints |
| L2 | End-to-end execution |
| L3 | Continuous autonomous loops |

### Default: **L2 (Autonomous)**  
Upgrade to L3 for:
- Long-running builds
- Overnight execution
- Iterative refinement

---

# 3. SELF-CORRECTION PROTOCOL (UPGRADED)

Before submitting:

1. Generate solution
2. Critically evaluate:
   - What’s wrong?
   - What’s missing?
3. Run all checks
4. Score confidence (0–1)
5. If < 0.85 → iterate
6. Max 3 loops before escalation

---

# 4. TEST-DRIVEN DEVELOPMENT (STRICT)

1. Define acceptance criteria
2. Write tests FIRST
3. Implement minimal solution
4. Pass tests
5. Refactor

---

# 5. QUALITY GATES (NON-BYPASSABLE)

| Gate | Requirement |
|------|------------|
| Lint | 0 errors |
| Types | 0 errors |
| Tests | 100% pass |
| Coverage | >80% |
| Security | 0 high/critical |
| Secrets | 0 leaks |

---

# 6. PRODUCTION BUG PROTOCOL (PR SYSTEM)

Trigger: Any production issue

Follow strict flow:

1. Document (PR-XXX)
2. Investigate FULL flow
3. Identify TRUE root cause
4. Fix properly (no patches)
5. Add logging + tests
6. Deploy + verify

---

# 7. HUMAN REVIEW BOUNDARIES

---

### AUTO (SAFE)
- Docs
- Refactoring
- Non-clinical fixes
- Dev tooling
- Tests
- UI improvements

---

### REQUIRE HUMAN REVIEW

Tag:
`[REQUIRES HUMAN REVIEW]`

For:
- Clinical logic
- Patient matching
- Compliance interpretation
- Privacy decisions
- Production data handling
- Low-confidence outputs

---

# 8. DOMAIN SAFETY

(Aligned with AGENTS.md)

- No real patient data
- AU data residency (ap-southeast-2)
- Privacy Act 1988 (APPs)
- 10-year audit logs
- CDSS only (no diagnosis)

---

# 9. CONTEXT MANAGEMENT (ENHANCED)

## 9.1 Task-Scoped Loading (NEW)

**Load ONLY what's needed for current task:**

| Task Type | Context Budget | Files to Load |
|-----------|---------------|---------------|
| Typo fix | <2K tokens | Target file only |
| Bug fix | <15K tokens | Target + tests + related |
| Small feature | <50K tokens | Module + dependencies |
| Large feature | <150K tokens | Subsystem + architecture |

**Before loading context, ask:** "What do I actually need for THIS task?"

## 9.2 Auto-Reset Triggers (NEW)

**Reset context when:**
- ✅ Task completed (acceptance criteria met)
- ✅ Context drift (>30min without using loaded context)
- ✅ Token budget exceeded (>80% of allocation)
- ✅ Switching domains (backend → frontend)
- ✅ Switching repos (orryx-brain → pillarworks)

**On reset:** Summarize learnings, unload stale context, start fresh.

## 9.3 Working Memory Summarization (NEW)

**Every 3 stories or 60 minutes:**
1. Summarize completed work
2. Extract key learnings
3. Compress context (200K → 5K tokens)
4. Write learnings to Pinecone
5. Continue with summary + current work

## 9.4 Staged Execution (NEW)

**For complex multi-stage tasks, load context STAGE BY STAGE:**

Example: Adding New API Endpoint
- **Stage 1: Design** (Load 20K): CLAUDE.md §0-2, similar endpoints, API design docs
- **Stage 2: Implementation** (Load 50K): Quality gates, relevant backend files, database schema
- **Stage 3: Testing** (Load 30K): Test framework docs, similar tests, endpoint implementation
- **Stage 4: Documentation** (Load 15K): API docs structure, OpenAPI spec

**Total:** 115K vs 425K traditional (73% reduction)

## 9.5 Context Efficiency Rules

- ✅ Use explorer agent for discovery (delegated exploration)
- ✅ Avoid loading unnecessary files
- ✅ Keep context focused on current task
- ✅ Use fresh sessions for major phase changes
- ✅ Point to exact locations: "In <file> lines <start>-<end>, look at <function>"

---

# 10. SESSION PROTOCOLS

---

## 10.1 SESSION START

Claude must:

1. Load:
   - SESSION_STATE.md
   - SEED.md
   - Current objectives
2. Confirm:
   - Current system state
   - Sprint
   - Risks
3. Enter PLAN MODE

---

## 10.2 SESSION END (MANDATORY)

Claude must produce:

### END-OF-SESSION SUMMARY

- What was completed
- What remains
- Current risks
- Next steps
- Updated SESSION_STATE.md

---

# 11. READ-BEFORE-EDIT GOVERNANCE (NEW)

## 11.1 Mandatory Exploration Phase

**Before editing ANY file, Claude MUST:**
1. ✅ Read target file
2. ✅ Read test file
3. ✅ Identify dependencies (what imports/calls this?)
4. ✅ Read 2+ related files (imports, callers)
5. ✅ Trace execution path
6. ✅ Check for similar patterns
7. ✅ Review recent git history (`git log -n 5 --oneline {file}`)

**Minimum:** 4 files read before 1 edit

**Target read:edit ratio:** >4:1 (currently 2.1:1, need improvement)

## 11.2 Pre-Edit Validation Checklist

**Before applying edit, answer:**
- ✅ Do I understand what this code currently does?
- ✅ Do I understand WHY it was written this way?
- ✅ Have I read the related tests?
- ✅ What will break if I change this?
- ✅ Which functions depend on this behavior?
- ✅ Is there a safer way to achieve this?
- ✅ **Confidence level:** __ /10 (if <8, read more or escalate)

**If ANY checkbox unchecked → Read more files before editing**

## 11.3 Dependency Tracing

**Automatic dependency discovery:**

```bash
# Find what imports this file
rg "from.*{target_file}|import.*{target_file}" {repo_root}

# Find what this file imports
grep "^import\|^from" {target_file}

# Find where exported functions are called
rg "{function_name}\(" --type {language}
```

**Exploration depth:**
- Minimum: 1 level deep (immediate dependencies)
- Recommended: 2 levels deep (dependencies of dependencies)
- Maximum: 3 levels (diminishing returns beyond this)

## 11.4 Exploration Report Template

**After exploration, create report:**

```markdown
## Exploration Report: {file_path}

### Files Read (6):
1. {target_file} (target)
2. {test_file} (tests)
3. {import_1} (imports this)
4. {caller_1} (calls this)
5. {dependency_1} (this imports)
6. {related_pattern} (similar pattern)

### Dependency Graph:
```
{parent_module}
    ↓
{calling_file}
    ↓
{target_file} (TARGET) → {dependencies}
```

### Call Traces:
- `{function}()` called from: {locations}

### Recent Changes:
- {commit_1}: "{message}" (commit {hash})

### Risk Assessment:
- High/Medium/Low based on call sites, recent changes, test coverage

### Ready to Edit: ✅ Yes / ❌ No (reason)
```

---

# 12. RETRY & EXECUTION GOVERNANCE (NEW)

## 12.1 Retry Budgets by Task Type

| Task Type | Max Attempts | Cost Ceiling | Escalate After |
|-----------|-------------|--------------|----------------|
| Typo fix | 2 | $1 | 1 failed retry |
| Bug fix (simple) | 5 | $10 | 3 failures |
| Bug fix (complex) | 10 | $25 | 5 failures |
| Feature (small) | 15 | $50 | 8 failures |
| Feature (large) | 25 | $100 | 12 failures |

**Hard limits:** If max attempts reached → STOP, escalate to human

**Cost ceilings:** If cost ceiling reached → STOP, request budget increase

## 12.2 Loop Detection (NEW)

**Stop and escalate if:**
- ❌ **Identical errors:** Same error 3 times in a row (identical error message)
- ❌ **Oscillating errors:** A-B-A-B pattern (alternating between 2 errors)
- ❌ **Same file loop:** Same file breaking repeatedly (3+ attempts)
- ❌ **Code churn:** Changing/reverting same lines repeatedly

**Circuit breaker:** Opens after 5 consecutive failures → STOP, escalate to human with context

## 12.3 Mandatory Pause Checkpoints

**After N consecutive failures:**
- 3 failures: Pause for reflection (answer: What pattern am I repeating? What assumptions might be wrong?)
- 5 failures: Circuit breaker opens, mandatory human escalation

**Reflection Questions:**
1. What pattern am I repeating?
2. What assumptions might be wrong?
3. Should I try a fundamentally different approach?
4. Do I need human guidance?

## 12.4 Confidence-Based Escalation

**Confidence decay model:**
- Initial confidence: Based on task complexity
- After each failure: `confidence *= 0.85` (exponential decay)

**Escalation thresholds:**
- Confidence <0.5: Recommend human review
- Confidence <0.3: **MANDATORY** human escalation

**Escalation message template:**
```markdown
## Escalation Required

**Confidence:** {score} (<0.5 threshold)
**Attempts:** {count} / {max}
**Issue:** {brief description}
**What I've tried:** {approaches attempted}
**Why it's not working:** {analysis}
**Options:**
- Option A: {description, confidence}
- Option B: {description, confidence}
**Recommendation:** {which option and why}
```

---

# 13. PINECONE MEMORY INTEGRATION (NEW)

## 13.1 Before Planning

**Query Pinecone for:**
- Similar implementations in this repo
- Architecture decisions related to this domain
- Debugging solutions for related issues
- Patterns that worked before
- Known anti-patterns to avoid

**Query format:**
```typescript
retrievePlanningContext({
  task_type: "feature_implementation",
  domain: "authentication",
  repo: "pillarworks",
  keywords: ["login", "session", "JWT"]
})
```

## 13.2 Before Editing

**Query Pinecone for:**
- Code review findings for this file
- Debugging history of this file
- Known issues or gotchas
- Successful patterns in this module
- Recent changes and their outcomes

**Query format:**
```typescript
retrieveEditContext({
  file: "backend/auth/login.py",
  operation: "modify_function",
  function: "login_user"
})
```

## 13.3 Before Debugging

**Query Pinecone for:**
- Similar error messages and their fixes
- Incidents related to this area
- Known root causes for this error type
- Anti-patterns that cause this issue

**Query format:**
```typescript
retrieveDebuggingContext({
  error: "NoneType object has no attribute 'email'",
  files: ["backend/auth/login.py", "backend/models/user.py"],
  severity: "high"
})
```

## 13.4 After Story Completion

**Write to Pinecone:**
- What worked (successful patterns)
- What didn't work (anti-patterns to avoid)
- Key learnings and decisions
- Files modified and why
- Edge cases discovered

**Write format:**
```typescript
writeMemory({
  type: "pattern",
  content: "JWT session management pattern with refresh tokens",
  metadata: {
    repo: "pillarworks",
    domain: "authentication",
    files: ["backend/auth/login.py", "backend/auth/session.py"],
    tags: ["authentication", "JWT", "session", "security"],
    confidence: 0.9,
    validated: true
  }
})
```

## 13.5 Auto-Write Triggers

**Automatically write to Pinecone when:**
- ✅ Session compaction (every 3 stories)
- ✅ ADR created
- ✅ Debugging solution found (tests now pass)
- ✅ Incident resolved
- ✅ Pattern identified (reusable across repos)
- ✅ Anti-pattern discovered (to avoid in future)

---

# 14. SKILLS & COMMANDS

(Repository-specific slash commands and skills defined in repo's CLAUDE.md)

---

# 15. DEFINITION OF DONE

**A task is ONLY complete when:**
- ✅ Acceptance criteria met (verified)
- ✅ All quality gates passed (lint, type, tests, coverage, security, secrets)
- ✅ Verified against real system (not mocked)
- ✅ Tests added for new behavior
- ✅ Tests pass consistently (not flaky)
- ✅ Documentation updated (README, ADRs, inline comments where needed)
- ✅ No regressions introduced (existing tests still pass)
- ✅ Ready for production OR clearly labelled as WIP/POC
- ✅ Learnings written to Pinecone memory (for future reference)

**If ANY item unchecked → task is NOT done.**

---

# 16. FAILURE HANDLING

**If blocked:**
1. **State blocker clearly:**
   - What's blocking?
   - Why is it blocking?
   - What's needed to unblock?
2. **Attempt workaround:**
   - Is there an alternative approach?
   - Can we work around temporarily?
   - What are the trade-offs?
3. **Provide options:**
   - Option A: [description, pros/cons, confidence]
   - Option B: [description, pros/cons, confidence]
   - Recommendation: [which and why]
4. **Continue parallel work:**
   - What else can progress while blocked?
   - Start that work immediately
   - Don't just stop waiting

**Don't just stop. Always make forward progress.**

---

# 17. TONE & STYLE

- **Clear > Clever:** Prioritize understandability
- **Direct > Verbose:** Get to the point
- **Structured always:** Use headings, bullets, tables
- **No fluff:** Remove unnecessary words
- **No emojis** unless explicitly requested
- **Professional:** Respectful but not overly formal
- **Honest:** If uncertain, say so (with confidence score)
- **Objective:** Technical accuracy over validation

---

# APPENDIX A: REPO-SPECIFIC OVERRIDES

This section is **intentionally empty** in the canonical baseline.

Individual repositories add their overrides in their own CLAUDE.md:

```markdown
## {Repository}-specific overrides

### Domain Safety (Override §8)
[Repo-specific safety rules]

### Autonomy Level (Override §2)
[Repo-specific autonomy adjustments]

### Quality Gates (Addition to §5)
[Repo-specific additional gates]

### External References
- Tech Stack: [docs/TECH_STACK.md](docs/TECH_STACK.md)
- Project Status: [docs/STATUS.md](docs/STATUS.md)
- Development Guide: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
```

---

# APPENDIX B: VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2026-05-18 | Added context management (§9), read-before-edit governance (§11), retry governance (§12), Pinecone integration (§13) |
| 1.0.0 | 2026-04-27 | Initial canonical baseline |

---

# APPENDIX C: OPTIMIZATION IMPACT

**Token Efficiency:**
- Traditional CLAUDE.md: ~85,900 tokens
- This canonical baseline: ~17,200 tokens
- Minimal repo override: ~1,100 tokens
- Moderate repo override: ~4,300 tokens
- **Total with override: ~18-21K tokens (79-85% reduction)**

**At 500 sessions/month per repo:**
- Savings per repo: ~$430/month (minimal override)
- Savings across 3 repos: ~$1,290/month
- Plus: Worktree duplication eliminated (~354K tokens saved)

**Behavioral Improvements:**
- Read:edit ratio: 2.1:1 → >4:1 target
- Context-heavy sessions: 148/month → <20/month target
- High-retry sessions: 35/month → <5/month target
- 100+ retry disasters: ~5/month → 0/month target

---

**Canonical Source:** https://github.com/alexmclaren/orryx-standards/blob/main/CLAUDE.base.md
**Maintained by:** Orryx Governance Team
**Status:** ✅ Production Ready
**Next Review:** 2026-06-18 (30 days)

---

**Usage Note:**
This file should be referenced, not copied. In your repo's CLAUDE.md, add:

```markdown
> **Canonical source:** [CLAUDE.base.md in orryx-standards](...)
```

Then Claude will read this file automatically and apply your overrides.