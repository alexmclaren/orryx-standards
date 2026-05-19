# Agent Memory Integration Testing Guide

**Date:** May 19, 2026
**Purpose:** Guide for validating agent memory tool usage in real agent-mode workflows
**Status:** 🟡 Configuration Validated - Usage Testing Deferred
**Phase:** Phase 4 Track 6 Documentation

---

## Executive Summary

Agent configurations (engineer.yaml, architect.yaml, reviewer.yaml) have been validated with memory_query and memory_write tools correctly defined. However, **agent-mode execution cannot be triggered in automated testing**. This guide provides instructions for manual validation during future agent-mode workflows.

**Current State:**
- ✅ Agent YAML configs syntactically valid
- ✅ memory_query and memory_write tools defined
- ✅ Auto-triggers configured (before_planning, after_completion, etc.)
- ⏸️ **Usage validation pending** - requires real agent-mode execution

---

## Agent Configurations

### Engineer Agent (`agents/claude/engineer.yaml`)

**Memory Tools:**
- `memory_query` - Query memories before planning/editing
- `memory_write` - Write learnings after completion

**Auto-Query Triggers:**
- `before_planning` - Retrieve patterns, architecture, debugging memories
- `before_editing_file` - Query file-specific code review, debugging history
- `before_architecture_decision` - Query ADRs, design patterns
- `after_debugging_success` - Query past debugging solutions
- `after_code_review` - Query review patterns

**Auto-Write Triggers:**
- `session_compaction` - Write session learnings after N stories
- `adr_created` - Write ADR to architecture namespace
- `debugging_solution_found` - Write solution to debugging namespace
- `incident_resolved` - Write postmortem to incidents namespace
- `pattern_identified` - Write pattern to patterns namespace

---

### Architect Agent (`agents/claude/architect.yaml`)

**Memory Tools:**
- `memory_query` - Query ADRs, architecture patterns
- `memory_write` - Write ADRs, design patterns

**Auto-Query Triggers:**
- `before_planning` - Retrieve architecture patterns, cross-subsidiary patterns
- `before_architecture_decision` - Query existing ADRs for consistency
- `before_adr_creation` - Query related ADRs
- `after_design_review` - Query review feedback patterns

**Auto-Write Triggers:**
- `adr_created` - Write ADR to architecture namespace
- `architecture_decision_made` - Write decision to decisions namespace
- `design_pattern_identified` - Write pattern to patterns namespace
- `cross_subsidiary_pattern_discovered` - Write to architecture.cross-repo namespace

---

### Reviewer Agent (`agents/claude/reviewer.yaml`)

**Memory Tools:**
- `memory_query` - Query code review patterns, recurring issues
- `memory_write` - Write review patterns, security findings

**Auto-Query Triggers:**
- `before_code_review` - Query review patterns, file-specific issues
- `before_security_review` - Query security vulnerabilities, past incidents
- `after_code_review_complete` - Query for recurring issues

**Auto-Write Triggers:**
- `code_review_pattern_identified` - Write pattern to patterns namespace
- `security_vulnerability_found` - Write finding to security namespace
- `recurring_issue_detected` - Write pattern to patterns namespace
- `best_practice_validated` - Write standard to standards namespace

---

## Testing Scenarios

### Scenario 1: Engineer Agent Memory Usage

**When to Test:** Next feature implementation using engineer agent in agent-mode

**How to Test:**
1. Launch engineer agent: `agent engineer`
2. Provide feature request: "Implement user profile avatar upload"
3. Observe agent behavior:
   - **Expected:** Before planning, agent queries memory for similar implementations
   - **Expected:** Retrieved memories displayed in planning context
   - **Expected:** After implementation, agent writes session learnings

**Validation Checklist:**
- [ ] memory_query fires before_planning trigger
- [ ] Retrieved memories shown in agent output
- [ ] Agent incorporates past patterns into implementation
- [ ] memory_write fires after story completion
- [ ] Session learnings written to orryx-brain.sessions namespace
- [ ] Query Pinecone to verify memory was written

**Verification Command:**
```bash
# After agent completes, query for session learnings
export PINECONE_API_KEY="..." && \
export OPENAI_API_KEY="..." && \
cd D:/orryx-standards && \
npx tsx .claude/scripts/pinecone-memory-query.ts \
  --query="user profile avatar upload implementation" \
  --repo=orryx-brain \
  --domain=sessions \
  --top-k=3
```

**Expected Result:** Retrieves session learning with high relevance (>0.7)

---

### Scenario 2: Architect Agent ADR Creation

**When to Test:** Next architecture decision requiring ADR

**How to Test:**
1. Launch architect agent: `agent architect`
2. Request ADR: "Create ADR for switching from REST to GraphQL API"
3. Observe agent behavior:
   - **Expected:** Queries existing ADRs from architecture namespace
   - **Expected:** Displays related past decisions
   - **Expected:** After ADR creation, writes to architecture namespace

**Validation Checklist:**
- [ ] memory_query fires before_adr_creation trigger
- [ ] Retrieved ADRs ensure consistency with past decisions
- [ ] Agent avoids contradicting prior ADRs
- [ ] memory_write fires after ADR completion
- [ ] New ADR written to orryx-brain.architecture namespace
- [ ] ADR retrievable via query

**Verification Command:**
```bash
# Query for new ADR
npx tsx .claude/scripts/pinecone-memory-query.ts \
  --query="GraphQL API architecture decision" \
  --repo=orryx-brain \
  --domain=architecture \
  --top-k=5
```

**Expected Result:** New ADR appears with type=adr, confidence>0.8

---

### Scenario 3: Reviewer Agent Pattern Detection

**When to Test:** Next code review using reviewer agent

**How to Test:**
1. Launch reviewer agent: `agent reviewer`
2. Request review: "Review PR #123"
3. Observe agent behavior:
   - **Expected:** Queries code review patterns before review
   - **Expected:** Flags recurring issues if found in memory
   - **Expected:** Writes new patterns if identified

**Validation Checklist:**
- [ ] memory_query fires before_code_review trigger
- [ ] Retrieved patterns inform review (e.g., past SQL injection issues)
- [ ] Agent identifies recurring patterns across PRs
- [ ] memory_write fires if new pattern detected
- [ ] Pattern written to orryx-brain.patterns namespace
- [ ] Pattern retrievable and useful for future reviews

**Verification Command:**
```bash
# Query for code review patterns
npx tsx .claude/scripts/pinecone-memory-query.ts \
  --query="code review patterns SQL injection" \
  --repo=orryx-brain \
  --domain=patterns \
  --top-k=5
```

**Expected Result:** Patterns with examples, what worked, why it worked

---

## Success Criteria

### Agent Configuration (✅ Complete)
- [x] All 3 agent YAML files parse without errors
- [x] memory_query and memory_write tools defined
- [x] Auto-triggers configured for all agents
- [x] Tool parameter schemas valid

### Agent Usage (⏸️ Pending Manual Testing)
- [ ] Engineer agent queries memory before planning
- [ ] Engineer agent writes session learnings after work
- [ ] Architect agent queries ADRs before decisions
- [ ] Architect agent writes ADRs to architecture namespace
- [ ] Reviewer agent queries patterns before review
- [ ] Reviewer agent writes patterns when identified
- [ ] All agent-written memories are retrievable
- [ ] Memory integration improves agent output quality

---

## Troubleshooting

### Issue: Agent doesn't query memory before planning

**Possible Causes:**
- Auto-trigger not configured correctly in YAML
- Agent mode not recognizing trigger points
- Pinecone API key not accessible to agent

**Debug Steps:**
1. Check agent logs for memory tool invocations
2. Verify PINECONE_API_KEY in environment
3. Test memory scripts manually to confirm connectivity
4. Check agent YAML for correct trigger syntax

---

### Issue: Memory write succeeds but confidence is low (<0.5)

**Possible Causes:**
- Insufficient context in memory content
- Generic descriptions without specifics
- Missing related files or examples

**Fixes:**
- Add more context to memory content (error messages, file paths, code snippets)
- Include related_files metadata
- Add retrieval_triggers keywords
- Mark as human-reviewed (validated: true) if confidence is justified

---

### Issue: Retrieved memories not relevant to current task

**Possible Causes:**
- Query too generic (low semantic similarity)
- Wrong namespace queried
- Memory content lacks detail

**Fixes:**
- Use more specific query terms
- Verify namespace filter (e.g., orryx-brain.debugging vs pillarworks.debugging)
- Improve memory content quality (add examples, context, outcomes)
- Consider re-ranking or hybrid search (future enhancement)

---

## Integration with Skills

**Important:** Skills (ce-brainstorm, ce-debug, ce-work) have the same memory integration patterns as agents. If skills successfully query and write memory, agents should behave similarly.

**Validation via Skills:**
- ✅ ce-brainstorm queries product.decisions before brainstorming (Track 5.1 validated)
- ✅ ce-brainstorm writes product-decision after completion (Track 5.1 validated)
- ✅ ce-work auto-compaction writes session learnings (Track 5.3 validated)

**Inference:** Agent memory tools use identical scripts. If skills work, agents should work when properly triggered in agent-mode.

---

## Future Enhancements

### Phase 6 Improvements
1. **Query Quality:** Implement re-ranking with cross-encoder models
2. **Hybrid Search:** Combine vector search with keyword BM25
3. **Query Analytics:** Track which queries return low relevance, improve embeddings
4. **Memory Pruning:** Auto-prune low-confidence, unused memories
5. **Cross-Repo Sharing:** Enable orryx-brain.patterns → pillarworks.patterns sharing

### Observability
1. **Agent Memory Dashboard:** Track agent memory usage (queries per session, writes per agent)
2. **Quality Metrics:** Measure retrieval relevance, confidence trends over time
3. **Cost Tracking:** Monitor Pinecone API usage, OpenAI embedding costs

---

## Conclusion

Agent memory integration is **configuration-complete** and **usage validation is deferred** to real agent-mode workflows. This guide provides testing scenarios and validation criteria for when user launches agents during actual work.

**Next Steps:**
1. Use engineer/architect/reviewer agents in next real task
2. Observe memory tool invocations in agent logs
3. Verify memories written to correct namespaces
4. Validate retrieval quality and relevance
5. Update this guide with findings

---

**Document Status:** Ready for Manual Validation
**Last Updated:** May 19, 2026, 07:30 UTC+10
**Phase:** Phase 4 Track 6 Complete (Configuration Validated)
