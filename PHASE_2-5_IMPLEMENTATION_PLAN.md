# Pinecone Memory Integration - Phase 2-5 Implementation Plan

**Date:** May 18, 2026
**Status:** 🚀 ACTIVE - Phase 2 Starting
**Previous:** Phase 1 Complete (CLAUDE.md restructuring - 8,710 tokens saved)

---

## Executive Summary

**Completed:**
- ✅ Track 1: Hook Registration (orryx-brain + pillarworks)
- ✅ Track 2: Agent Configuration (24 agents with memory tools)
- ✅ Phase 1: CLAUDE.md Restructuring (~8,710 tokens saved per session)

**Remaining Work:**
- Phase 2: Hook Implementation Scripts (2-4 hours, AUTONOMOUS)
- Phase 3: Environment Setup + Historical Seeding (1-2 hours, USER ACTION)
- Phase 4: Integration Testing (2 hours, AUTONOMOUS)
- Phase 5: Governance Enforcement (6-10 hours, AUTONOMOUS)

**Total Remaining:** 11-18 hours autonomous + 1-2 hours user action

---

## Phase 2: Hook Implementation Scripts (AUTONOMOUS - Starting Now)

### Objective
Create the 4 TypeScript hook scripts that enable automatic memory operations.

### Autonomy Level
**L2 (Autonomous)** - Safe script creation, testable in isolation, no system changes until Phase 4.

### Files to Create

#### 1. D:\orryx-standards\.claude\hooks\pre-planning-memory-retrieval.ts
**Purpose:** Query Pinecone before entering plan mode
**Triggers:** PrePlanMode hook
**Implementation:**
```typescript
#!/usr/bin/env node
import { Pinecone } from '@pinecone-database/pinecone';

interface PlanningContext {
  task_description: string;
  repo: string;
  domain: string;
  keywords: string[];
}

async function retrievePlanningMemories(context: PlanningContext): Promise<void> {
  const apiKey = process.env.PINECONE_API_KEY;
  if (!apiKey) {
    console.error('[MEMORY] PINECONE_API_KEY not set, skipping memory retrieval');
    return;
  }

  const pc = new Pinecone({ apiKey });
  const index = pc.index('orryx-dev-intelligence');

  const queries = [
    `similar ${context.task_description} implementations in ${context.repo}`,
    `architecture decisions related to ${context.domain}`,
    `patterns for ${context.keywords.join(' ')}`
  ];

  console.log('[MEMORY] Querying Pinecone for planning context...');

  for (const query of queries) {
    try {
      const results = await index.namespace(`${context.repo}.architecture`).query({
        topK: 5,
        includeMetadata: true,
        includeValues: false
      });

      if (results.matches && results.matches.length > 0) {
        console.log(`[MEMORY] Found ${results.matches.length} relevant memories for: "${query}"`);
        results.matches.forEach(match => {
          console.log(`  - [${match.score?.toFixed(3)}] ${match.metadata?.type}: ${match.id}`);
        });
      }
    } catch (error) {
      console.error(`[MEMORY] Error querying: ${error}`);
    }
  }
}

// Parse context from stdin or environment
const context: PlanningContext = {
  task_description: process.env.CLAUDE_TASK_DESCRIPTION || 'general task',
  repo: process.env.CLAUDE_REPO || 'unknown',
  domain: process.env.CLAUDE_DOMAIN || 'general',
  keywords: (process.env.CLAUDE_KEYWORDS || '').split(',').filter(Boolean)
};

retrievePlanningMemories(context).catch(console.error);
```

#### 2. D:\orryx-standards\.claude\hooks\pre-edit-memory-retrieval.ts
**Purpose:** Query Pinecone before editing files
**Triggers:** PreToolUse(Edit) hook
**Implementation:**
```typescript
#!/usr/bin/env node
import { Pinecone } from '@pinecone-database/pinecone';
import * as fs from 'fs';
import * as path from 'path';

interface EditContext {
  file_path: string;
  repo: string;
}

async function retrieveEditMemories(context: EditContext): Promise<void> {
  const apiKey = process.env.PINECONE_API_KEY;
  if (!apiKey) {
    console.error('[MEMORY] PINECONE_API_KEY not set, skipping memory retrieval');
    return;
  }

  const pc = new Pinecone({ apiKey });
  const index = pc.index('orryx-dev-intelligence');

  const fileName = path.basename(context.file_path);
  const module = path.dirname(context.file_path).split('/').pop() || 'unknown';

  const queries = [
    `code review findings for ${fileName}`,
    `debugging solutions in ${context.file_path}`,
    `patterns used in ${module}`
  ];

  console.log(`[MEMORY] Querying memories for file: ${context.file_path}`);

  for (const query of queries) {
    try {
      const results = await index.namespace(`${context.repo}.patterns`).query({
        topK: 3,
        filter: { related_files: { $contains: context.file_path } },
        includeMetadata: true,
        includeValues: false
      });

      if (results.matches && results.matches.length > 0) {
        console.log(`[MEMORY] Found ${results.matches.length} memories for: "${query}"`);
        results.matches.forEach(match => {
          console.log(`  - [${match.score?.toFixed(3)}] ${match.metadata?.type}: ${match.id}`);
          if (match.metadata?.confidence) {
            console.log(`    Confidence: ${match.metadata.confidence}`);
          }
        });
      }
    } catch (error) {
      console.error(`[MEMORY] Error querying: ${error}`);
    }
  }
}

const context: EditContext = {
  file_path: process.env.CLAUDE_FILE_PATH || 'unknown',
  repo: process.env.CLAUDE_REPO || 'unknown'
};

retrieveEditMemories(context).catch(console.error);
```

#### 3. D:\orryx-standards\.claude\hooks\pre-debugging-memory-retrieval.ts
**Purpose:** Query Pinecone before debugging
**Triggers:** PreDebugMode hook
**Implementation:**
```typescript
#!/usr/bin/env node
import { Pinecone } from '@pinecone-database/pinecone';

interface DebuggingContext {
  error_message: string;
  files_affected: string[];
  repo: string;
}

async function retrieveDebuggingMemories(context: DebuggingContext): Promise<void> {
  const apiKey = process.env.PINECONE_API_KEY;
  if (!apiKey) {
    console.error('[MEMORY] PINECONE_API_KEY not set, skipping memory retrieval');
    return;
  }

  const pc = new Pinecone({ apiKey });
  const index = pc.index('orryx-dev-intelligence');

  const errorPattern = extractErrorPattern(context.error_message);

  const queries = [
    `similar error: ${errorPattern}`,
    `debugging solutions for ${context.files_affected.join(' ')}`,
    `incidents matching ${errorPattern}`
  ];

  console.log(`[MEMORY] Searching for similar errors: "${errorPattern}"`);

  for (const query of queries) {
    try {
      const results = await index.namespace(`${context.repo}.debugging`).query({
        topK: 5,
        includeMetadata: true,
        includeValues: false
      });

      if (results.matches && results.matches.length > 0) {
        console.log(`[MEMORY] Found ${results.matches.length} similar debugging cases`);
        results.matches.forEach(match => {
          console.log(`  - [${match.score?.toFixed(3)}] ${match.id}`);
          if (match.metadata?.validated) {
            console.log(`    ✓ Human-verified solution`);
          }
          if (match.metadata?.effectiveness_score) {
            console.log(`    Effectiveness: ${match.metadata.effectiveness_score}`);
          }
        });
      }
    } catch (error) {
      console.error(`[MEMORY] Error querying: ${error}`);
    }
  }
}

function extractErrorPattern(error: string): string {
  // Extract key error message without specific values
  return error
    .replace(/\d+/g, 'N')
    .replace(/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/gi, 'UUID')
    .replace(/\/[^\s]+/g, 'PATH')
    .substring(0, 200);
}

const context: DebuggingContext = {
  error_message: process.env.CLAUDE_ERROR_MESSAGE || 'unknown error',
  files_affected: (process.env.CLAUDE_FILES_AFFECTED || '').split(',').filter(Boolean),
  repo: process.env.CLAUDE_REPO || 'unknown'
};

retrieveDebuggingMemories(context).catch(console.error);
```

#### 4. D:\orryx-standards\.claude\hooks\post-story-memory-write.ts
**Purpose:** Write learnings to Pinecone after story completion
**Triggers:** PostStoryCompletion hook
**Implementation:**
```typescript
#!/usr/bin/env node
import { Pinecone } from '@pinecone-database/pinecone';
import OpenAI from 'openai';
import { v4 as uuidv4 } from 'uuid';

interface StoryLearning {
  what_worked: string;
  what_didnt_work: string;
  patterns_discovered: string[];
  files_modified: string[];
  repo: string;
  domain: string;
  confidence: number;
}

async function writeStoryLearnings(learning: StoryLearning): Promise<void> {
  const pineconeKey = process.env.PINECONE_API_KEY;
  const openaiKey = process.env.OPENAI_API_KEY;

  if (!pineconeKey) {
    console.error('[MEMORY] PINECONE_API_KEY not set, skipping memory write');
    return;
  }

  if (!openaiKey) {
    console.error('[MEMORY] OPENAI_API_KEY not set, skipping memory write');
    return;
  }

  const openai = new OpenAI({ apiKey: openaiKey });
  const pc = new Pinecone({ apiKey: pineconeKey });
  const index = pc.index('orryx-dev-intelligence');

  // Generate embedding
  const content = `
Story Learning:
What worked: ${learning.what_worked}
What didn't work: ${learning.what_didnt_work}
Patterns: ${learning.patterns_discovered.join(', ')}
Files: ${learning.files_modified.join(', ')}
  `.trim();

  console.log('[MEMORY] Generating embedding for story learning...');

  try {
    const embeddingResponse = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: content
    });

    const embedding = embeddingResponse.data[0].embedding;
    const memoryId = `session-learning-${uuidv4()}`;

    // Write to Pinecone
    await index.namespace(`${learning.repo}.sessions`).upsert([{
      id: memoryId,
      values: embedding,
      metadata: {
        type: 'session-learning',
        repo: learning.repo,
        domain: learning.domain,
        what_worked: learning.what_worked,
        what_didnt_work: learning.what_didnt_work,
        patterns_discovered: learning.patterns_discovered,
        related_files: learning.files_modified,
        confidence: learning.confidence,
        importance: learning.confidence > 0.8 ? 'high' : 'medium',
        created_at: new Date().toISOString(),
        author: 'claude-sonnet-4.5',
        author_type: 'agent',
        validated: false
      }
    }]);

    console.log(`[MEMORY] ✓ Wrote learning to ${learning.repo}.sessions (ID: ${memoryId})`);
  } catch (error) {
    console.error(`[MEMORY] Error writing: ${error}`);
  }
}

const learning: StoryLearning = {
  what_worked: process.env.CLAUDE_WHAT_WORKED || '',
  what_didnt_work: process.env.CLAUDE_WHAT_DIDNT_WORK || '',
  patterns_discovered: (process.env.CLAUDE_PATTERNS || '').split(',').filter(Boolean),
  files_modified: (process.env.CLAUDE_FILES_MODIFIED || '').split(',').filter(Boolean),
  repo: process.env.CLAUDE_REPO || 'unknown',
  domain: process.env.CLAUDE_DOMAIN || 'general',
  confidence: parseFloat(process.env.CLAUDE_CONFIDENCE || '0.7')
};

writeStoryLearnings(learning).catch(console.error);
```

### Implementation Steps

1. **Create hook scripts directory**
   ```bash
   mkdir -p D:\orryx-standards\.claude\hooks
   ```

2. **Create package.json for dependencies**
   ```bash
   cd D:\orryx-standards\.claude\hooks
   npm init -y
   npm install @pinecone-database/pinecone openai uuid
   npm install --save-dev @types/node @types/uuid typescript tsx
   ```

3. **Create each hook script** (4 files above)

4. **Add execution permissions** (if on Unix-like system)

5. **Create test script** to validate hooks in isolation
   ```typescript
   // test-hooks.ts - Dry run validation
   ```

6. **Document usage** in README.md

### Validation Criteria

- [ ] All 4 hook scripts created
- [ ] package.json with dependencies exists
- [ ] Scripts have proper shebang and TypeScript types
- [ ] Error handling for missing API keys
- [ ] Logging for debugging
- [ ] No syntax errors (tsc --noEmit)
- [ ] Callable from command line (npx tsx script.ts)

### Success Metrics

- Scripts exist and are syntactically valid
- Error handling gracefully degrades when API keys missing
- Clear logging output for debugging
- Ready to test in Phase 4 after environment setup

---

## Phase 3: Environment Setup + Historical Seeding (USER ACTION REQUIRED)

### Objective
Set up environment variables and seed Pinecone with 500-750 historical memories.

### Autonomy Level
**L0 (Supervised)** - Requires user action (API key, script execution).

### Blocking Issue
AWS Secrets Manager contains placeholder: `REPLACE_WITH_REAL_VA...`

### Required Actions

#### 1. Set Real OPENAI_API_KEY

**Option A: Update AWS Secrets Manager** (Recommended)
```bash
# Get real OpenAI API key from https://platform.openai.com/api-keys
aws secretsmanager update-secret \
  --secret-id orryx/directors/openai/api_key \
  --secret-string "sk-proj-..." \
  --region us-east-1
```

**Option B: Set Environment Variable**

**PowerShell (Windows - Recommended):**
```powershell
# Temporary (current session only)
$env:OPENAI_API_KEY = "sk-proj-..."

# Verify
echo $env:OPENAI_API_KEY

# Permanent (current user)
[System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', 'sk-proj-...', 'User')
```

**Git Bash / Unix:**
```bash
export OPENAI_API_KEY="sk-proj-..."
# Or add to ~/.bashrc or ~/.zshrc
```

**Option C: Add to GitHub Secrets**
```bash
gh secret set OPENAI_API_KEY --body "sk-proj-..." --repo orryx-brain
gh secret set OPENAI_API_KEY --body "sk-proj-..." --repo pillarworks-build-mvp
```

#### 2. Verify Pinecone Connection

```bash
export PINECONE_API_KEY="pcsk_5RuMNx_..." # Already have this
npx tsx D:\orryx-standards\.claude\scripts\pinecone-verify.ts
```

Expected output:
```
✓ Connected to Pinecone
✓ Index: orryx-dev-intelligence exists
✓ Dimension: 1536
✓ Metric: cosine
```

#### 3. Run Historical Seeding Scripts

**Script 1: Seed ADRs** (~5-10 minutes)
```bash
cd D:\orryx-standards\.claude\scripts
npx tsx seed-historical-adrs.ts

# Expected output:
# Seeding ADRs from D:\orryx-brain\docs\architecture\ADRs...
# ✓ Seeded 45 ADRs to orryx-brain.architecture
# ✓ Seeded 55 ADRs to pillarworks.architecture
# Total: 100 ADRs seeded
```

**Script 2: Seed Git Debugging History** (~20-30 minutes)
```bash
npx tsx seed-git-debugging.ts --repo=orryx-brain --max-commits=200
npx tsx seed-git-debugging.ts --repo=pillarworks --max-commits=200

# Expected output:
# Analyzing git history for bug fixes...
# Found 250 commits matching "fix|bug|error|debug"
# ✓ Seeded 120 debugging solutions to orryx-brain.debugging
# ✓ Seeded 130 debugging solutions to pillarworks.debugging
# Total: 250 debugging solutions seeded
```

**Script 3: Seed Patterns** (~5-10 minutes)
```bash
npx tsx seed-patterns.ts

# Expected output:
# Extracting patterns from orchestration docs...
# ✓ Seeded 80 patterns to orryx-brain.patterns
# ✓ Seeded 70 patterns to pillarworks.patterns
# Total: 150 patterns seeded
```

**Script 4: Seed Codeburn Findings** (~2-3 minutes)
```bash
npx tsx seed-codeburn-findings.ts

# Expected output:
# Parsing D:\orryx-audit\governance\CODEBURN_BASELINE.md...
# ✓ Seeded 50 optimization patterns to codeburn.findings
```

**Script 5: Seed Standards** (~2-3 minutes)
```bash
npx tsx seed-standards.ts

# Expected output:
# Extracting standards from CLAUDE.base.md...
# ✓ Seeded 50 standards to standards.global
```

#### 4. Verify Seeding

```bash
npx tsx D:\orryx-standards\.claude\scripts\pinecone-verify.ts --count-by-namespace

# Expected output:
# Namespace counts:
# orryx-brain.architecture: 45
# orryx-brain.debugging: 120
# orryx-brain.patterns: 80
# pillarworks.architecture: 55
# pillarworks.debugging: 130
# pillarworks.patterns: 70
# codeburn.findings: 50
# standards.global: 50
# Total: 600 memories
```

### Success Criteria

- [ ] OPENAI_API_KEY set and accessible
- [ ] Pinecone connection verified
- [ ] 500-750 memories seeded across namespaces
- [ ] Sample query returns results
- [ ] No PII or secrets leaked

### Estimated Time

- API key setup: 5 minutes
- Script execution: 30-60 minutes (mostly automated)
- Verification: 5 minutes
- **Total: 40-70 minutes**

---

## Phase 4: Integration Testing (AUTONOMOUS)

### Objective
Test memory queries and writes end-to-end with real workflows.

### Autonomy Level
**L2 (Autonomous)** - Read-only testing, no destructive operations.

### Prerequisites
- Phase 2 complete (hook scripts exist)
- Phase 3 complete (environment setup, 500+ memories seeded)

### Test Plan

#### Test 1: Memory Query in ce-brainstorm
```bash
# Invoke ce-brainstorm skill with test topic
CLAUDE_REPO=orryx-brain \
CLAUDE_TASK_DESCRIPTION="improve authentication system" \
npx tsx .claude/hooks/pre-planning-memory-retrieval.ts

# Expected: Retrieves ADRs and patterns related to auth
```

#### Test 2: Memory Query in ce-debug
```bash
# Simulate debugging scenario
CLAUDE_REPO=pillarworks \
CLAUDE_ERROR_MESSAGE="TypeError: Cannot read property 'id' of undefined" \
CLAUDE_FILES_AFFECTED="backend/api/boq.py" \
npx tsx .claude/hooks/pre-debugging-memory-retrieval.ts

# Expected: Retrieves similar errors and fixes
```

#### Test 3: Memory Query Before Edit
```bash
# Simulate pre-edit hook
CLAUDE_REPO=orryx-brain \
CLAUDE_FILE_PATH="backend/auth/jwt.py" \
npx tsx .claude/hooks/pre-edit-memory-retrieval.ts

# Expected: Retrieves code review findings and patterns for jwt.py
```

#### Test 4: Memory Write After Story
```bash
# Simulate post-story write
CLAUDE_REPO=pillarworks \
CLAUDE_WHAT_WORKED="Used YOLOv8 for element detection" \
CLAUDE_WHAT_DIDNT_WORK="Grid detection needed manual calibration" \
CLAUDE_PATTERNS="computer-vision,takeoff-automation" \
CLAUDE_FILES_MODIFIED="backend/services/detector.py,backend/services/grid.py" \
CLAUDE_CONFIDENCE=0.85 \
npx tsx .claude/hooks/post-story-memory-write.ts

# Expected: Writes learning to pillarworks.sessions namespace
```

#### Test 5: End-to-End Workflow
```bash
# Real workflow: Fix a bug in orryx-brain
# 1. Pre-debug hook retrieves similar errors
# 2. Agent fixes bug using retrieved context
# 3. Post-story hook writes solution

# Measure:
# - Hook execution time (<2 seconds)
# - Query relevance (manual inspection)
# - Write success (verify in Pinecone)
```

### Validation Criteria

- [ ] Pre-planning hook retrieves relevant ADRs
- [ ] Pre-edit hook retrieves relevant patterns
- [ ] Pre-debug hook retrieves similar errors
- [ ] Post-story hook writes learnings successfully
- [ ] Query latency <2 seconds
- [ ] No errors in hook execution
- [ ] Memories returned have relevance scores >0.7

### Success Metrics

- Hook execution success rate: >95%
- Query relevance: >80% (manual evaluation of top 3 results)
- Query performance: <2 seconds average
- Write success rate: 100%
- Zero PII leaks

### Estimated Time

- Hook testing: 1 hour
- End-to-end workflow testing: 1 hour
- **Total: 2 hours**

---

## Phase 5: Governance Enforcement (AUTONOMOUS)

### Objective
Enable hard enforcement of governance systems (optional - can run in parallel with Phase 3/4).

### Autonomy Level
**L1 (Checkpoints)** - Enforcement gates affect workflows, need validation before full activation.

### Implementation Tasks

#### 1. Enable Hard Enforcement

**Edit:** `D:\orryx-standards\.claude\config\governance.yaml`
```yaml
systems:
  context_management:
    enabled: true
    enforcement_level: "hard"  # Changed from "warn"

  read_before_edit:
    enabled: true
    enforcement_level: "hard"

  execution_budgets:
    enabled: true
    enforcement_level: "hard"
```

#### 2. Create Governance Hooks

**File:** `D:\orryx-standards\.claude\hooks\pre-edit-governance.ts`
```typescript
// Check read-before-edit requirements
// Check execution budget
// Check context budget
```

#### 3. Set Up Codeburn Weekly Routine

**Edit:** `D:\orryx-brain\.orryx\routines\routines.yaml`
```yaml
- id: R10
  name: codeburn-continuous-analysis
  schedule:
    cron: "0 20 * * 0"  # Sundays 20:00 UTC
  workflow:
    - run_codeburn_analysis
    - compare_to_baseline
    - identify_regressions
    - write_findings_to_pinecone
    - update_dashboard
```

#### 4. Document Override Procedures

**File:** `D:\orryx-standards\docs\GOVERNANCE_OVERRIDE.md`

### Validation Criteria

- [ ] Governance config enabled
- [ ] Governance hooks created
- [ ] Override procedures documented
- [ ] Codeburn R10 routine scheduled
- [ ] Test workflow passes gates
- [ ] False positive rate <5%

### Success Metrics

- Read:edit ratio improvement: 2.1:1 → >3.5:1
- High-retry sessions reduction: 35/month → <10/month
- Context-heavy sessions reduction: 148/month → <75/month
- Codeburn dashboard auto-updated weekly

### Estimated Time

- Config creation: 2 hours
- Hook implementation: 3 hours
- Codeburn routine: 1 hour
- Testing: 1 hour
- **Total: 6-10 hours**

---

## Timeline Summary

### Week 1 (Current)
- ✅ **Day 1-2:** Track 1 & 2 Complete (hook registration, agent config)
- ✅ **Day 3:** Phase 1 Complete (CLAUDE.md restructuring)
- 🔄 **Day 3-4:** Phase 2 (Hook scripts) - Starting now

### Week 2
- ⏸️ **Day 5:** Phase 3 (USER ACTION - environment setup + seeding)
- 🔜 **Day 6:** Phase 4 (Integration testing)
- 🔜 **Day 6-7:** Phase 5 (Governance enforcement - optional parallel)

### Total Timeline
- Autonomous work: 10-16 hours
- User action: 1-2 hours
- **Total: 11-18 hours across 2 weeks**

---

## Success Criteria - Overall Integration

### Functional
- [ ] All 4 hooks execute successfully
- [ ] Memory queries return relevant results
- [ ] Memory writes accumulate correctly
- [ ] Skills (ce-brainstorm, ce-debug, ce-work) use memory
- [ ] Agent workflows improved by memory context

### Performance
- [ ] Query latency: <2 seconds average
- [ ] Hook execution: <5 seconds total per workflow
- [ ] No workflow blocking or failures

### Quality
- [ ] Memory relevance: >80% (top 3 results evaluated by humans)
- [ ] No PII or secrets in memories
- [ ] Proper metadata and tagging

### Adoption
- [ ] Read:edit ratio: 2.1:1 → >3.5:1
- [ ] Context-heavy sessions: 148/month → <75/month
- [ ] High-retry sessions: 35/month → <10/month
- [ ] Memory-assisted problem solving: >60% of workflows

### Cost
- [ ] Pinecone cost: <$5/month
- [ ] OpenAI embeddings: <$10/month
- [ ] Token savings from CLAUDE.md: ~8,710 per session
- [ ] **Net savings: >$200/month after integration costs**

---

## Risk Management

### Phase 2 Risks
- **Hook scripts have bugs:** Mitigated by comprehensive error handling, logging, isolated testing
- **Dependencies conflict:** Using tsx for execution (no build step), minimal dependencies

### Phase 3 Risks
- **OPENAI_API_KEY not available:** User can create new key from OpenAI dashboard
- **Historical seeding finds bad data:** Filtering patterns for PII/secrets, dry-run mode available
- **Seeding takes too long:** Limit commits to 300, can pause/resume

### Phase 4 Risks
- **Hooks don't execute:** Clear error messages, fallback gracefully
- **Query latency high:** Two-stage retrieval, namespace pre-filtering
- **Irrelevant results:** Tuning top-k and confidence thresholds

### Phase 5 Risks
- **Governance too aggressive:** Override procedures, soft enforcement first, tunable thresholds
- **False positives:** Weekly review, adjustable rules
- **Workflow disruption:** Gradual rollout, monitoring, rollback procedures

---

## Rollback Procedures

### Phase 2 Rollback
```bash
rm -rf D:\orryx-standards\.claude\hooks\
# Hook registration in settings.local.json remains harmless without scripts
```

### Phase 3 Rollback
```bash
# Delete Pinecone namespace
# Unset environment variables
```

### Phase 4 Rollback
```bash
# No changes to revert - testing only
```

### Phase 5 Rollback
```bash
# Disable governance enforcement
export CLAUDE_GOVERNANCE_DISABLED=true
# Or revert governance.yaml to enforcement_level: "soft"
```

---

## Next Actions

**Immediate (Autonomous):**
1. Create D:\orryx-standards\.claude\hooks\ directory
2. Initialize npm project with dependencies
3. Create 4 hook scripts with full implementation
4. Create validation test script
5. Document usage in README.md
6. Test scripts in isolation (dry-run)
7. Commit Phase 2 work

**After Phase 2 Complete (User Action):**
1. User: Set OPENAI_API_KEY (real value, not placeholder)
2. User: Run historical seeding scripts (30-60 minutes)
3. User: Verify Pinecone has 500-750 memories
4. User: Signal ready for Phase 4

**After Phase 3 Complete (Autonomous):**
1. Run integration testing
2. Validate hooks in real workflows
3. Measure performance metrics
4. Document any issues
5. Proceed to Phase 5 (optional)

---

**Plan Status:** 🚀 READY - Proceeding with Phase 2 autonomously
**Next Checkpoint:** Phase 2 complete, await user for Phase 3
**Estimated Time to Next Checkpoint:** 2-4 hours
