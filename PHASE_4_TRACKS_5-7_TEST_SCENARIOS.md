# Phase 4 Tracks 5-7: Test Scenarios for Manual Validation

**Date:** May 19, 2026
**Session:** 64+ (Continued) - Pinecone Memory Integration
**Purpose:** Document test scenarios for Phase B real-world validation
**Status:** 🟢 Ready for Execution

---

## Executive Summary

This document defines specific test scenarios for validating memory integration across skills (Track 5), agents (Track 6), and end-to-end workflows (Track 7). Each scenario includes expected behavior, validation criteria, and success metrics.

**Testing Approach:** Real implementation work serves as test vehicles. Skills and agents are tested through actual tasks, not synthetic test cases.

---

## Track 5: Skill Integration Test Scenarios

### Scenario 5.1: ce-brainstorm with Memory

**Objective:** Validate memory retrieval before brainstorming and write-back after decision

**Task:** Brainstorm memory system optimization ideas (next-phase improvements)

**Invocation:**
```bash
# User invokes brainstorm skill
/ce-brainstorm
# Topic: "Memory system optimization ideas for Phase 5"
```

**Expected Flow:**

1. **Phase -1: Memory Retrieval (Pre-Brainstorm)**
   - Query: `product.decisions` namespace for past memory improvement ideas
   - Query: `sessions` namespace for recent memory-related work
   - Query: `customer.insights` if feedback exists on memory system
   - Query: `${repo}.patterns` for similar optimization patterns
   - **Expected:** Retrieved memories displayed in brainstorm context
   - **Success:** ≥3 relevant memories retrieved with score >0.6

2. **Phase 1-4: Brainstorming**
   - Use retrieved context to inform ideation
   - Avoid re-discussing ideas from past decisions
   - Generate new optimization recommendations

3. **Phase 5: Write Back Learnings (Post-Brainstorm)**
   - Write product-decision to `product.decisions` namespace
   - Include: decision summary, options considered, chosen approach
   - Tags: `product`, `memory-optimization`, `phase-5`
   - **Expected:** Memory write succeeds with ID returned

**Validation Checklist:**
- [ ] Phase -1 queries executed before brainstorm starts
- [ ] Retrieved memories displayed to user in formatted output
- [ ] Brainstorm incorporates past context (no duplicate ideas)
- [ ] Phase 5 writes product-decision to Pinecone
- [ ] Written decision is retrievable via query (relevance >0.7)
- [ ] No PII or secrets in written memory

**Success Criteria:**
- Memory retrieval occurs automatically ✅
- Retrieved memories inform brainstorm ✅
- Decision written to correct namespace ✅
- Decision retrievable and properly formatted ✅

**Deliverable:** `MEMORY_OPTIMIZATION_IDEAS.md` + Pinecone product-decision memory

---

### Scenario 5.2: ce-debug with Memory

**Objective:** Validate memory retrieval before debugging and solution write-back after fix

**Task:** Debug any errors discovered during Phase A validation (conditional)

**Invocation:**
```bash
# If errors occur during Phase A
/ce-debug
# Error: [specific error message]
```

**Expected Flow:**

1. **Phase -1: Memory Retrieval (Pre-Debug)**
   - Query: Similar errors in `${repo}.debugging` namespace
   - Query: Error patterns in `${repo}.patterns` namespace
   - Query: Incidents in `incidents.postmortems` namespace
   - Query: Code smells in `codeburn.findings` namespace
   - **Expected:** Retrieved debugging solutions displayed with relevance scores
   - **Success:** If similar error exists, retrieve solution with score >0.75

2. **Phase 1-4: Debugging**
   - Use retrieved solutions to guide investigation
   - Apply known fixes if applicable
   - Document root cause if novel error

3. **Phase 5: Write Solution (Post-Debug)**
   - Write debugging-solution to `${repo}.debugging` namespace
   - Include: error message, root cause, fix applied, verification
   - Tags: `debugging`, `error-type`, `file-path`
   - **Expected:** Solution write succeeds with ID returned

**Validation Checklist:**
- [ ] Phase -1 queries executed before debugging starts
- [ ] Similar errors retrieved and displayed (if exist)
- [ ] Debugging incorporates past solutions
- [ ] Phase 5 writes debugging-solution to Pinecone
- [ ] Written solution is retrievable via error query (relevance >0.8)
- [ ] Solution includes: error, root cause, fix, verification

**Success Criteria:**
- Memory retrieval occurs automatically ✅
- Past solutions guide debugging ✅
- Solution written to correct namespace ✅
- Solution prevents future recurrence ✅

**Deliverable:** Fixed code + debugging-solution memory (if debugging occurs)

---

### Scenario 5.3: ce-work with Auto-Compaction

**Objective:** Validate memory retrieval before implementation and auto-compaction after 3 stories

**Task:** Implement Memory Health Dashboard (3 stories)

**Stories:**
1. **Story 1:** Create `memory-health-check.ts` - Query index stats, check namespace health
2. **Story 2:** Create `memory-usage-report.ts` - Vector counts, growth trends, namespace analysis
3. **Story 3:** Create `memory-quality-audit.ts` - Confidence scores, validated %, PII scan

**Invocation:**
```bash
# User invokes work skill with plan
/ce-work
# Plan: Implement Memory Health Dashboard (3 stories)
```

**Expected Flow:**

1. **Phase -1: Memory Retrieval (Pre-Implementation)**
   - Query: `${repo}.patterns` for similar monitoring implementations
   - Query: `${repo}.architecture` for architectural patterns
   - Query: `${repo}.debugging` for past implementation issues
   - Query: `standards.global` for coding standards
   - **Expected:** Retrieved patterns displayed before implementation
   - **Success:** ≥2 relevant patterns retrieved with score >0.6

2. **Phase 1-4: Implementation**
   - **Story 1:** Implement health check script (1.5 hours)
     - Commit: "feat(memory): add health check script"
   - **Story 2:** Implement usage report script (1.5 hours)
     - Commit: "feat(memory): add usage report script"
   - **Story 3:** Implement quality audit script (1.5-2 hours)
     - Commit: "feat(memory): add quality audit script"
     - **Trigger:** After 3rd story, auto-compaction should trigger

3. **Phase 5: Write Learnings (Post-Implementation)**
   - **Auto-Compaction Trigger:** After Story 3 completion
   - Write session-learning to `${repo}.sessions` namespace
   - Include: implementation patterns discovered, gotchas, decisions
   - Tags: `monitoring`, `dashboard`, `memory-health`
   - **Expected:** Auto-compaction writes session learnings

**Validation Checklist:**
- [ ] Phase -1 queries executed before Story 1
- [ ] Retrieved patterns inform implementation approach
- [ ] Story 1 completed and committed
- [ ] Story 2 completed and committed
- [ ] Story 3 completed and committed
- [ ] Auto-compaction triggers after Story 3
- [ ] Phase 5 writes session-learning to sessions namespace
- [ ] Written learnings retrievable via query (relevance >0.6)
- [ ] All 3 scripts functional and tested

**Success Criteria:**
- Memory retrieval occurs before implementation ✅
- Patterns guide implementation ✅
- Auto-compaction triggers correctly ✅
- Session learnings written to correct namespace ✅
- Learnings retrievable for future similar work ✅

**Deliverable:** 3 monitoring scripts + session-learning memory

---

## Track 6: Agent Configuration Validation

### Scenario 6.1: Engineer Agent Memory Usage

**Objective:** Validate engineer agent uses memory_query and memory_write tools

**Context:** Agent-mode execution cannot be triggered directly in this session. Skills implicitly use agent configurations when invoked. Engineer agent patterns are demonstrated through ce-work skill execution.

**Validation Approach:**

1. **Indirect Testing via ce-work Skill**
   - When ce-work executes, it demonstrates same memory patterns engineer agent would use
   - memory_query fires before planning (pre-implementation)
   - memory_write fires after story completion (post-implementation)
   - Auto-triggers match engineer agent configuration

2. **Direct Testing (Future Session)**
   - User launches engineer agent in agent-mode
   - Agent executes feature implementation task
   - Observe memory tool invocations in agent logs
   - Verify auto-triggers fire at correct points

**Expected Engineer Agent Memory Usage:**
- **before_planning:** Query patterns, architecture, debugging memories
- **before_editing_file:** Query file-specific code review, debugging history
- **after_debugging_success:** Write debugging-solution to memory
- **session_compaction:** Write session learnings after 3 stories
- **pattern_identified:** Write pattern to patterns namespace

**Validation Checklist:**
- [x] Engineer agent YAML config syntactically valid (Phase A)
- [x] memory_query and memory_write tools defined (Phase A)
- [x] Auto-triggers configured (Phase A)
- [ ] Skills demonstrate same patterns agent would use (Track 5)
- [ ] Future agent-mode testing confirms tool invocations

**Success Criteria:**
- Agent configuration valid ✅
- Memory tools defined ✅
- Auto-triggers configured ✅
- Skills replicate agent patterns ✅

**Deliverable:** AGENT_TESTING_GUIDE.md for future manual validation

---

### Scenario 6.2: Architect Agent Memory Usage

**Objective:** Validate architect agent uses memory for architecture decisions and ADRs

**Context:** Same indirect testing approach as engineer agent

**Validation Approach:**

1. **Indirect Testing via ce-brainstorm Skill**
   - When ce-brainstorm executes for architecture decisions, demonstrates architect agent patterns
   - memory_query fires before architecture decision
   - memory_write fires after ADR creation

2. **Direct Testing (Future Session)**
   - User launches architect agent for ADR creation
   - Agent queries existing ADRs from `${repo}.architecture` namespace
   - Agent writes new ADR to memory after decision

**Expected Architect Agent Memory Usage:**
- **before_planning:** Query ADRs, architecture patterns, cross-subsidiary patterns
- **before_architecture_decision:** Query similar decisions from past
- **before_adr_creation:** Query related ADRs to ensure consistency
- **adr_created:** Write ADR to architecture namespace
- **design_pattern_identified:** Write pattern to patterns namespace

**Validation Checklist:**
- [x] Architect agent YAML config syntactically valid (Phase A)
- [x] memory_query and memory_write tools defined (Phase A)
- [x] Auto-triggers configured (Phase A)
- [ ] Skills demonstrate same patterns agent would use (Track 5)
- [ ] Future agent-mode testing confirms tool invocations

**Success Criteria:**
- Agent configuration valid ✅
- Memory tools defined ✅
- Auto-triggers configured ✅
- Skills replicate agent patterns ✅

**Deliverable:** AGENT_TESTING_GUIDE.md section for architect agent

---

### Scenario 6.3: Reviewer Agent Memory Usage

**Objective:** Validate reviewer agent uses memory for code review patterns and recurring issues

**Context:** Same indirect testing approach as other agents

**Validation Approach:**

1. **Indirect Testing via Code Review**
   - If code review occurs during implementation, demonstrates reviewer agent patterns
   - memory_query fires before code review
   - memory_write fires after review if patterns identified

2. **Direct Testing (Future Session)**
   - User launches reviewer agent for PR review
   - Agent queries code review patterns, recurring issues
   - Agent writes patterns to memory if identified

**Expected Reviewer Agent Memory Usage:**
- **before_code_review:** Query code review patterns, file-specific issues
- **before_security_review:** Query security vulnerabilities, past incidents
- **after_code_review_complete:** Query for recurring issues across reviews
- **code_review_pattern_identified:** Write pattern to patterns namespace
- **security_vulnerability_found:** Write finding to security namespace
- **recurring_issue_detected:** Write pattern to patterns namespace

**Validation Checklist:**
- [x] Reviewer agent YAML config syntactically valid (Phase A)
- [x] memory_query and memory_write tools defined (Phase A)
- [x] Auto-triggers configured (Phase A)
- [ ] Code review demonstrates same patterns agent would use
- [ ] Future agent-mode testing confirms tool invocations

**Success Criteria:**
- Agent configuration valid ✅
- Memory tools defined ✅
- Auto-triggers configured ✅
- Review patterns replicated ✅

**Deliverable:** AGENT_TESTING_GUIDE.md section for reviewer agent

---

## Track 7: End-to-End Workflow Test Scenarios

### Scenario 7.1: Feature Development Lifecycle

**Objective:** Test complete feature lifecycle with memory integration

**Task:** Memory Health Dashboard implementation (3 stories from Track 5.3)

**Lifecycle Phases:**

1. **Plan → Implement**
   - Pre-planning: Query patterns, architecture for similar monitoring
   - Implementation: 3 stories (health check, usage report, quality audit)
   - Post-completion: Auto-compaction writes session learnings

2. **Test → Verify**
   - Test each script: health check, usage report, quality audit
   - Verify functionality: scripts execute, return expected output
   - Validate against acceptance criteria

3. **Document → Memory Write-Back**
   - Document usage in README or governance docs
   - Session learnings captured in sessions namespace
   - Implementation patterns captured in patterns namespace

**Memory Integration Points:**
- **Pre-Planning:** Query for similar implementations
- **During Implementation:** Query debugging if issues arise
- **Post-Completion:** Auto-compaction after Story 3
- **Session End:** Session learnings written to memory

**Validation Checklist:**
- [ ] Pre-planning memory query executed
- [ ] Retrieved patterns inform implementation
- [ ] Implementation completes successfully (3 scripts functional)
- [ ] Auto-compaction triggers after Story 3
- [ ] Session learnings written to sessions namespace
- [ ] Implementation patterns captured
- [ ] Complete memory trail exists in Pinecone (query → implement → write-back)

**Success Criteria:**
- Feature development complete ✅
- Memory integration seamless ✅
- Session learnings captured ✅
- No duplicate work (memory prevents re-solving) ✅

**Deliverable:** 3 functional monitoring scripts + complete memory trail

---

### Scenario 7.2: Ideation → Decision Lifecycle

**Objective:** Test complete ideation-to-decision workflow with memory

**Task:** Memory optimization brainstorm (Track 5.1)

**Lifecycle Phases:**

1. **Brainstorm → Evaluate**
   - Pre-brainstorm: Query product.decisions for past improvement ideas
   - Brainstorm: Generate optimization recommendations
   - Evaluate: Assess feasibility, impact, cost

2. **Decide → Document**
   - Decision: Choose optimization approach
   - Document: Write decision rationale, alternatives considered
   - Memory write-back: Product-decision to product.decisions namespace

**Memory Integration Points:**
- **Pre-Brainstorm:** Query past decisions, sessions, customer insights
- **During Brainstorm:** Use retrieved context to inform ideation
- **Post-Brainstorm:** Write product-decision to memory

**Validation Checklist:**
- [ ] Pre-brainstorm memory query executed
- [ ] Retrieved past decisions prevent duplicate discussion
- [ ] Brainstorm generates new optimization ideas
- [ ] Decision documented with rationale
- [ ] Product-decision written to product.decisions namespace
- [ ] Decision retrievable via query (relevance >0.7)

**Success Criteria:**
- Ideation-to-decision lifecycle complete ✅
- Memory integration seamless ✅
- Product-decision captured ✅
- No duplicate work ✅

**Deliverable:** Memory optimization recommendations + product-decision memory

---

### Scenario 7.3: Debugging Lifecycle (Conditional)

**Objective:** Test complete debugging workflow with memory (if errors occur)

**Task:** Debug any Phase A errors (Track 5.2)

**Lifecycle Phases:**

1. **Error → Investigate**
   - Pre-debug: Query similar errors, patterns, incidents
   - Investigate: Trace root cause, identify fix
   - Apply: Implement fix, verify resolution

2. **Fix → Verify → Document**
   - Fix: Apply root cause fix (not patch)
   - Verify: Test fix resolves error
   - Document: Write debugging-solution to memory

**Memory Integration Points:**
- **Pre-Debug:** Query debugging namespace for similar errors
- **During Debug:** Use retrieved solutions to guide investigation
- **Post-Fix:** Write debugging-solution to memory

**Validation Checklist:**
- [ ] Pre-debug memory query executed
- [ ] Retrieved solutions guide debugging (if similar error exists)
- [ ] Root cause identified and fixed
- [ ] Debugging-solution written to debugging namespace
- [ ] Solution retrievable via error query (relevance >0.8)
- [ ] Solution prevents future recurrence

**Success Criteria:**
- Debugging lifecycle complete ✅
- Memory integration seamless ✅
- Debugging-solution captured ✅
- Future recurrence prevented ✅

**Deliverable:** Fixed code + debugging-solution memory (if applicable)

---

### Scenario 7.4: PII/Secrets Audit (Critical Security Check)

**Objective:** Audit all memories written during Tracks 5-7 for PII and secrets

**Task:** Create and run memory-security-audit.ts script

**Audit Scope:**
- All memories written during Phase 4 testing (Tracks 1-7)
- Test memories written in this session (Track 5 test writes)
- Session learnings from auto-compaction
- Product-decisions from brainstorm
- Debugging-solutions from debug skill

**Forbidden Patterns:**

**API Keys:**
- `pcsk_*` - Pinecone API keys
- `sk-proj-*` - OpenAI API keys
- `pk_*` - Publishable keys
- `Bearer *` - Auth tokens
- AWS access keys (AKIA*, ASIA*)

**Passwords:**
- `password=`, `pwd=`, `secret=`
- Credential patterns

**PII:**
- Email addresses (regex patterns)
- Phone numbers (US/AU formats)
- SSN/TFN patterns
- Credit card patterns

**Script Implementation:**

```typescript
// memory-security-audit.ts
import { queryMemory } from '.claude/scripts/pinecone-memory-query';

async function scanForSecrets() {
  const forbiddenPatterns = [
    /pcsk_[A-Za-z0-9_-]+/g,  // Pinecone keys
    /sk-proj-[A-Za-z0-9_-]+/g,  // OpenAI keys
    /AKIA[0-9A-Z]{16}/g,  // AWS keys
    /password\s*=\s*[^\s]+/gi,  // Passwords
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,  // Emails
    // Additional patterns...
  ];

  // Query all namespaces
  const namespaces = [
    'orryx-brain.tooling',
    'orryx-brain.sessions',
    'product.decisions',
    'orryx-brain.debugging',
  ];

  for (const namespace of namespaces) {
    // Query recent memories (last 7 days)
    const memories = await queryMemory({
      query: '*',  // All memories
      namespace,
      topK: 100,
    });

    // Scan each memory
    for (const memory of memories) {
      for (const pattern of forbiddenPatterns) {
        if (pattern.test(memory.content)) {
          console.error(`❌ SECURITY VIOLATION: ${pattern} in ${memory.id}`);
          // Log violation, prepare for deletion
        }
      }
    }
  }
}
```

**Validation Checklist:**
- [ ] Script created and functional
- [ ] All Track 5-7 namespaces scanned
- [ ] Forbidden patterns detected
- [ ] Zero violations found (zero tolerance)
- [ ] If violations found: memories deleted, patterns updated

**Success Criteria:**
- Security audit complete ✅
- Zero PII/secrets violations ✅
- All memories safe for storage ✅
- Forbidden patterns config updated if needed ✅

**Deliverable:** memory-security-audit.ts + audit report + clean memory set

---

## Overall Success Criteria

### Track 5 (Skills) - MANDATORY
- [ ] ce-brainstorm queries and writes memory
- [ ] ce-debug queries and writes memory (if debugging occurs)
- [ ] ce-work queries memory, auto-compaction triggers
- [ ] All skill-written memories retrievable (relevance >0.6)

### Track 6 (Agents) - CONFIGURATION VALIDATED
- [x] Agent configs syntactically valid
- [x] Memory tools defined
- [x] Auto-triggers configured
- [ ] Skills demonstrate agent patterns (via Track 5)
- [ ] Future agent-mode testing guide created

### Track 7 (End-to-End) - MANDATORY
- [ ] Feature development lifecycle complete (dashboard)
- [ ] Ideation-to-decision lifecycle complete (brainstorm)
- [ ] Debugging lifecycle complete (if applicable)
- [ ] Security audit passes (zero PII/secrets)
- [ ] Complete memory trail exists for all workflows

### Critical Requirements
- **Zero Tolerance:** No PII or secrets in any memory
- **Retrieval Quality:** Written memories retrievable with relevance >0.6
- **Integration Seamless:** Memory queries/writes occur automatically without user intervention
- **Namespace Correctness:** All memories written to appropriate namespaces

---

## Phase B Execution Timeline

**Day 2 (5 hours):**
- Morning: Track 5.1 - ce-brainstorm (2 hours)
- Afternoon: Track 5.2 - ce-debug (2 hours, if errors found)
- Evening: Track 7.4 - Security audit (1 hour)

**Day 3 (5 hours):**
- Morning-Afternoon: Track 5.3 - ce-work (4 hours, 3 stories)
- Evening: Track 6 & 7 documentation (1 hour)

**Total:** ~10 hours autonomous execution

---

**Document Status:** ✅ Ready for Phase B Execution
**Last Updated:** May 19, 2026, 06:30 UTC+10
**Next Action:** Execute Phase A verification report, then proceed to Phase B testing
