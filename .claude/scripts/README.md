# Pinecone Memory System - Scripts & Usage Guide

This directory contains scripts for managing persistent memory in the Orryx ecosystem using Pinecone vector database.

## Prerequisites

1. **Environment Variables** (Required):
   ```bash
   export PINECONE_API_KEY="pcsk_..."
   export OPENAI_API_KEY="sk-..."
   ```

2. **Dependencies**:
   - Node.js 18+ with TypeScript support
   - `@pinecone-database/pinecone` package
   - `openai` package
   - `uuid` package

3. **Pinecone Index**:
   - Index name: `orryx-dev-intelligence`
   - Dimension: 1536 (OpenAI ada-002 embeddings)
   - Metric: cosine
   - Serverless (recommended)

## Core Scripts

### 1. pinecone-memory-write.ts

Write memories to Pinecone for future retrieval.

**Usage:**
```bash
npx tsx pinecone-memory-write.ts \
  --content="Use JWT with refresh tokens for authentication" \
  --type=pattern \
  --repo=orryx-brain \
  --domain=architecture \
  --tags=authentication,security,JWT \
  --importance=high \
  --validated
```

**Required Arguments:**
- `--content=TEXT` - Memory content
- `--type=TYPE` - Memory type (see types below)
- `--repo=REPO` - Repository name
- `--domain=DOMAIN` - Domain name

**Optional Arguments:**
- `--tags=TAG1,TAG2` - Comma-separated tags
- `--confidence=N` - Confidence score 0-1 (default: 0.8)
- `--importance=LEVEL` - critical|high|medium|low (default: medium)
- `--author=NAME` - Author name
- `--author-type=TYPE` - human|agent (default: agent)
- `--related-files=FILES` - Comma-separated file paths
- `--related-issues=IDS` - Comma-separated issue IDs
- `--validated` - Mark as human-validated
- `--expires-in-days=N` - Memory expiration

**Memory Types:**
- `session-learning` - Session learnings from ce-work
- `adr` - Architecture Decision Records
- `pattern` - Implementation patterns
- `debugging-solution` - Bug fixes and solutions
- `incident` - Production incident postmortems
- `code-review` - Code review findings
- `standard` - Standards and conventions
- `decision` - Product decisions
- `codeburn-finding` - Codeburn optimization patterns
- `codex-review` - Codex architectural feedback

**Examples:**

```bash
# Write a debugging solution
npx tsx pinecone-memory-write.ts \
  --content="NullPointerException in UserService.getCurrentUser(): Returns undefined when JWT expired. Added null check and redirect to login." \
  --type=debugging-solution \
  --repo=orryx-brain \
  --domain=debugging \
  --tags=NullPointerException,authentication,JWT \
  --related-files=backend/services/UserService.ts,backend/middleware/auth.ts \
  --related-issues=#456 \
  --importance=high \
  --validated

# Write an architecture pattern
npx tsx pinecone-memory-write.ts \
  --content="Middleware Pattern: Centralize auth logic in middleware layer to keep controllers thin. See auth.middleware.ts for implementation." \
  --type=pattern \
  --repo=orryx-brain \
  --domain=architecture \
  --tags=middleware,authentication,pattern \
  --importance=high \
  --validated
```

### 2. seed-historical-adrs.ts

Seed historical Architecture Decision Records from `docs/architecture/ADRs/` directories.

**Usage:**
```bash
npx tsx seed-historical-adrs.ts
```

**What it does:**
- Scans ADR directories in orryx-brain, pillarworks, and clinical-trials
- Extracts ADR number and title from filenames and content
- Writes each ADR to Pinecone with metadata
- Adds contextual tags (security, performance, etc.)

**Expected Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📚 Seeding Historical ADRs to Pinecone
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📂 Scanning orryx-brain: D:\orryx-brain\docs\architecture\ADRs
   Found 23 markdown files
📂 Scanning pillarworks: D:\pillarworks-build-mvp\docs\architecture\ADRs
   Found 15 markdown files

📊 Total ADRs to seed: 38

✅ orryx-brain: ADR 1 - Use JWT for Authentication
✅ orryx-brain: ADR 2 - Adopt Microservices Architecture
...
```

**Locations Scanned:**
- `D:\orryx-brain\docs\architecture\ADRs`
- `D:\orryx-brain\architecture\decisions`
- `D:\pillarworks-build-mvp\docs\architecture\ADRs`
- `D:\pillarworks-build-mvp\architecture\decisions`
- `D:\Clinical.Trials\docs\architecture\ADRs`
- `D:\Clinical.Trials\architecture\decisions`

### 3. seed-git-debugging.ts

Seed debugging solutions from git commit history.

**Usage:**
```bash
npx tsx seed-git-debugging.ts
```

**What it does:**
- Searches git history for commits with keywords: fix, bug, error, debug, crash
- Extracts commit details (hash, message, author, date, files changed)
- Categorizes by error type (null-check, race-condition, authentication, etc.)
- Writes up to 300 most recent bug fixes to Pinecone

**Expected Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🐛 Seeding Git Debugging History to Pinecone
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 Scanning orryx-brain for bug fixes...
   Found 127 bug fix commits
🔍 Scanning pillarworks for bug fixes...
   Found 89 bug fix commits

📊 Total commits to seed: 216

✅ orryx-brain: a1b2c3d - Fix NullPointerException in auth middleware
✅ pillarworks: d4e5f6g - Fix race condition in file upload
...
```

**Repositories Scanned:**
- `D:\orryx-brain`
- `D:\pillarworks-build-mvp`
- `D:\Clinical.Trials`

**Timeframe:** Last 1 year of commits

## Namespace Structure

Memories are organized hierarchically:

```
orryx-dev-intelligence (Index)
├── orryx-brain.architecture    - orryx-brain ADRs and design
├── orryx-brain.debugging       - orryx-brain bug fixes
├── orryx-brain.patterns        - orryx-brain implementation patterns
├── orryx-brain.sessions        - orryx-brain session learnings
├── pillarworks.architecture    - pillarworks ADRs and design
├── pillarworks.debugging       - pillarworks bug fixes
├── pillarworks.patterns        - pillarworks patterns
├── pillarworks.sessions        - pillarworks learnings
├── clinical-trials.*           - clinical-trials namespaces
├── standards.global            - Cross-repo standards
├── incidents.postmortems       - Production incident learnings
├── codeburn.findings           - Codeburn optimization patterns
└── codex.reviews               - Codex architectural feedback
```

## Metadata Schema

Each memory includes:

```typescript
{
  // Core Identity
  id: string;              // Unique UUID
  type: MemoryType;        // Memory type (adr, pattern, etc.)

  // Context
  repo: string;            // Repository name
  domain: string;          // Domain (architecture, debugging, etc.)
  namespace: string;       // Full namespace (repo.domain)

  // Temporal
  created_at: string;      // ISO 8601 timestamp
  updated_at: string;      // Last update timestamp
  expires_at?: string;     // Optional expiration

  // Provenance
  author: string;          // Author name
  author_type: string;     // 'human' or 'agent'
  session_id?: string;     // Session ID if applicable

  // Classification
  tags: string[];          // Searchable tags
  confidence: number;      // 0-1 confidence score
  importance: string;      // critical|high|medium|low

  // Relationships
  related_files: string[]; // File paths
  related_issues: string[]; // GitHub issue IDs
  related_prs: string[];   // GitHub PR IDs

  // Quality
  validated: boolean;      // Human-verified
  usage_count: number;     // Times retrieved
  effectiveness_score: number; // 0-1 effectiveness
}
```

## Running the Seeding Scripts

### Full Seeding Process

1. **Set environment variables:**
   ```bash
   export PINECONE_API_KEY="pcsk_..."
   export OPENAI_API_KEY="sk-..."
   ```

2. **Seed ADRs (Expected: ~50-100 memories):**
   ```bash
   cd D:\orryx-standards\.claude\scripts
   npx tsx seed-historical-adrs.ts
   ```

3. **Seed Git Debugging (Expected: ~200-300 memories):**
   ```bash
   npx tsx seed-git-debugging.ts
   ```

4. **Verify:**
   ```bash
   # Check Pinecone dashboard or query via API
   # Total expected: 500-750 memories
   ```

### Troubleshooting

**Error: "PINECONE_API_KEY environment variable not set"**
```bash
# Windows PowerShell
$env:PINECONE_API_KEY = "pcsk_..."

# Windows CMD
set PINECONE_API_KEY=pcsk_...

# Linux/Mac
export PINECONE_API_KEY="pcsk_..."
```

**Error: "OpenAI API error: 429 Rate Limit"**
- Scripts include 1-second delays between writes
- Reduce batch size or increase delay
- Check OpenAI API limits

**Error: "Module not found: @pinecone-database/pinecone"**
```bash
# Install dependencies
npm install @pinecone-database/pinecone openai uuid
```

## Integration with Skills

The memory system is integrated into 3 core skills:

### ce-brainstorm
- **Phase -1**: Query past brainstorms, product decisions, customer insights
- **Phase 5**: Write brainstorm outcomes to memory

### ce-debug
- **Phase -1**: Query similar errors, known fixes, incidents
- **Phase 5**: Write debugging solutions to memory

### ce-work
- **Phase -1**: Query implementations, patterns, architecture decisions
- **Phase 5**: Write session learnings to memory

## Integration with Hooks

Hooks are registered in `.claude/settings.local.json`:

- **PrePlanMode**: Query memory before planning
- **PreToolUse (Edit)**: Query memory before editing files
- **PreDebugMode**: Query memory before debugging
- **PostStoryCompletion**: Write learnings after story completion

## Cost Estimation

**Per Memory Write:**
- OpenAI embedding: ~$0.0001 per write
- Pinecone storage: ~$0.00025 per GB
- Pinecone queries: ~$0.10 per 1M queries

**Seeding Costs (500 memories):**
- Embeddings: ~$0.05
- Storage: ~$0.001
- **Total: ~$0.051**

**Monthly Operational Costs (estimated):**
- ~500 queries/day: ~$0.015/month
- ~50 writes/day: ~$0.15/month
- Storage (5GB): ~$1.25/month
- **Total: ~$1.42/month**

**ROI:** $1.42/month investment → ~$200/month savings (avoiding duplicate work)

## Next Steps

After running the seeding scripts:

1. **Verify memories in Pinecone dashboard**
2. **Test retrieval with a query**
3. **Run a brainstorm/debug/work session to test integration**
4. **Monitor effectiveness_score over time**
5. **Set up automated refreshing (monthly ADR re-seed)**

## Support

For issues or questions:
- Check environment variables are set
- Verify Pinecone index exists and is accessible
- Check OpenAI API key has embedding permissions
- Review error logs for specific failures
