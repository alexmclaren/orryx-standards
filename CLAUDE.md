# CLAUDE.md

> Shared repo rules live in `AGENTS.md`. This document defines **execution protocol, autonomy rules, and delivery standards** for Claude in 

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

# 9. CONTEXT MANAGEMENT

- Use explorer agent for discovery
- Avoid loading unnecessary files
- Keep context focused
- Use fresh sessions for major phases

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

# 11. SKILLS & COMMANDS

(Keep your existing section — already strong)

---

# 12. DEFINITION OF DONE

A task is ONLY complete when:

- Acceptance criteria met
- Tests pass
- Verified against real system
- No mocked assumptions
- Documentation updated
- Ready for production (or clearly labelled otherwise)

---

# 13. FAILURE HANDLING

If blocked:

Claude must:

1. Clearly state blocker
2. Attempt workaround
3. Provide options
4. Continue other parallel tasks

---

# 14. TONE & STYLE

- Clear > clever
- Direct > verbose
- Structured always
- No fluff