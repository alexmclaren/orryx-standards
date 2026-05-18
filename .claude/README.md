# Claude Code Pinecone Integration

Complete Pinecone memory integration for Claude Code ecosystem.

## Overview

This integration provides **persistent memory** and **RAG capabilities** across all development activities:

- **Before Planning:** Retrieve similar implementations, ADRs, and patterns
- **Before Editing:** Retrieve code review findings, debugging history, and known issues
- **Before Debugging:** Retrieve similar errors, validated fixes, and related incidents
- **After Work:** Automatically write learnings, patterns, and decisions to memory

## Architecture

### Components

```
.claude/
├── scripts/
│   ├── pinecone-init.ts              # Initialize Pinecone index
│   ├── pinecone-verify.ts            # Verify connection
│   ├── pinecone-memory-query.ts      # Query interface (CLI + library)
│   └── pinecone-memory-write.ts      # Write interface (CLI + library)
├── hooks/
│   ├── pre-planning-memory-retrieval.ts    # Before PLAN MODE
│   ├── pre-edit-memory-retrieval.ts        # Before file edits
│   ├── pre-debugging-memory-retrieval.ts   # Before debugging
│   └── post-story-memory-write.ts          # After story completion
└── README.md                         # This file
```

### Pinecone Index Structure

**Index Name:** `orryx-dev-intelligence`
**Dimension:** 1536 (OpenAI ada-002 embeddings)
**Metric:** Cosine similarity
**Type:** Serverless (AWS us-east-1)

**Namespaces:**
```
{repo}.sessions          # Session learnings
{repo}.architecture      # ADRs and design decisions
{repo}.patterns          # Implementation patterns
{repo}.debugging         # Debugging solutions
{repo}.incidents         # Production incidents

standards.global         # Orryx-wide standards
architecture.cross-repo  # Cross-repo integration patterns
incidents.postmortems    # Production incident learnings
codeburn.findings        # Codeburn optimization patterns
codex.reviews            # Codex architectural feedback
```

## Setup

### Prerequisites

1. **Pinecone Account**
   - Sign up: https://www.pinecone.io/
   - Create API key from dashboard
   - Set environment variable:
     ```bash
     export PINECONE_API_KEY="your-api-key-here"
     ```

2. **OpenAI API Key** (for embeddings)
   ```bash
   export OPENAI_API_KEY="your-openai-key-here"
   ```

3. **Install Dependencies**
   ```bash
   npm install @pinecone-database/pinecone openai uuid
   npm install -D @types/uuid tsx
   ```

### Step 1: Create Index

```bash
npx tsx .claude/scripts/pinecone-init.ts
```

**Output:**
```
🚀 Initializing Pinecone index...
📦 Creating index: orryx-dev-intelligence
✅ Index created successfully!
```

### Step 2: Verify Connection

```bash
npx tsx .claude/scripts/pinecone-verify.ts
```

**Output:**
```
🔍 Verifying Pinecone connection...
✅ All verification tests passed!
🎉 Pinecone is ready for use
```

### Step 3: Deploy Hooks (Optional)

Add to your `.claude/settings.json`:

```json
{
  "hooks": {
    "pre-planning": ".claude/hooks/pre-planning-memory-retrieval.ts",
    "pre-edit": ".claude/hooks/pre-edit-memory-retrieval.ts",
    "pre-debugging": ".claude/hooks/pre-debugging-memory-retrieval.ts",
    "post-story": ".claude/hooks/post-story-memory-write.ts"
  }
}
```

## Usage

### Manual Memory Queries

**Search for JWT authentication patterns:**
```bash
npx tsx .claude/scripts/pinecone-memory-query.ts "JWT authentication patterns" \
  --repo=pillarworks \
  --domain=patterns \
  --top-k=5
```

**Search for NoneType errors:**
```bash
npx tsx .claude/scripts/pinecone-memory-query.ts "NoneType error" \
  --domain=debugging \
  --min-confidence=0.8 \
  --validated-only
```

**Search specific namespace:**
```bash
npx tsx .claude/scripts/pinecone-memory-query.ts "incident response" \
  --namespace=incidents.postmortems \
  --min-confidence=0.8
```

### Manual Memory Writes

**Write a pattern:**
```bash
npx tsx .claude/scripts/pinecone-memory-write.ts \
  --content="Use refresh tokens with JWT for better security. Store refresh tokens in httpOnly cookies." \
  --type=pattern \
  --repo=pillarworks \
  --domain=architecture \
  --tags=authentication,security,JWT \
  --importance=high
```

**Write a debugging solution:**
```bash
npx tsx .claude/scripts/pinecone-memory-write.ts \
  --content="NoneType error in login: User model missing email validation. Added required field and migration." \
  --type=debugging-solution \
  --repo=pillarworks \
  --domain=debugging \
  --tags=NoneType,email,authentication \
  --related-files=backend/auth/login.py,backend/models/user.py \
  --validated
```

### Hook Usage

Hooks are triggered automatically by Claude Code:

**Pre-Planning Hook:**
- Triggered: Before entering PLAN MODE
- Retrieves: Similar implementations, ADRs, patterns, lessons learned
- Output: Injected into Claude's context before planning

**Pre-Edit Hook:**
- Triggered: Before editing any file
- Retrieves: Code review findings, debugging history, successful patterns
- Output: File-specific warnings and recommendations

**Pre-Debugging Hook:**
- Triggered: When debugging an error
- Retrieves: Similar errors, validated fixes, related incidents
- Output: Ranked list of potential solutions

**Post-Story Hook:**
- Triggered: After story completion or every 3 stories
- Writes: Learnings, patterns, gotchas, decisions to Pinecone
- Output: Confirmation of memories written

## Memory Types

| Type | Description | Usage |
|------|-------------|-------|
| `session-learning` | Learnings from coding sessions | After story completion |
| `adr` | Architecture Decision Records | After ADR created |
| `pattern` | Implementation patterns that worked | After pattern identified |
| `debugging-solution` | Root causes and fixes | After bug fixed |
| `incident` | Production incident postmortems | After incident resolved |
| `code-review` | Code review findings | After PR reviewed |
| `standard` | Standards and conventions | After standard defined |
| `decision` | Product/technical decisions | After decision made |
| `codeburn-finding` | Codeburn optimization patterns | After Codeburn analysis |
| `codex-review` | Codex architectural feedback | After Codex review |

## Metadata Schema

Every memory has comprehensive metadata:

```typescript
{
  id: string;                    // UUID
  type: MemoryType;              // See table above
  repo: string;                  // Repository name
  domain: string;                // Domain (architecture, debugging, etc.)
  namespace: string;             // Full namespace path
  created_at: string;            // ISO 8601 timestamp
  updated_at: string;            // Last update
  author: string;                // Author name
  author_type: 'human' | 'agent';
  tags: string[];                // Searchable tags
  confidence: number;            // 0-1 confidence score
  importance: 'critical' | 'high' | 'medium' | 'low';
  related_files: string[];       // File paths involved
  related_issues: string[];      // GitHub issue IDs
  related_prs: string[];         // GitHub PR IDs
  retrieval_triggers: string[];  // Keywords for retrieval
  relevant_to: string[];         // Task types where relevant
  validated: boolean;            // Human-verified
  usage_count: number;           // Times retrieved
  effectiveness_score?: number;  // 0-1 feedback score
}
```

## Query Options

**Namespace Filtering:**
- `--namespace=X`: Search specific namespace
- `--repo=X`: Search all domains in repo
- `--domain=X`: Search domain across repos
- Default: Cross-repo namespaces (standards.global, architecture.cross-repo)

**Quality Filtering:**
- `--min-confidence=N`: Minimum confidence 0-1 (default: 0.6)
- `--min-importance=I`: Minimum importance (low, medium, high, critical)
- `--validated-only`: Only human-validated memories

**Result Tuning:**
- `--top-k=N`: Number of results (default: 5)
- `--recency-bias=N`: Weight recent memories 0-1 (default: 0)
- `--include-superseded`: Include superseded memories (default: false)

## Integration with CLAUDE.md

Add to your repo's `CLAUDE.md`:

```markdown
## §X: Persistent Memory Integration

Before ANY non-trivial task, query Pinecone memory:
- Before planning: Retrieve similar implementations, ADRs, patterns
- Before editing: Retrieve code review findings, debugging history
- Before architecture: Retrieve existing ADRs, cross-repo patterns, incidents
- Before debugging: Retrieve similar errors, known fixes

After EVERY story completion:
- Write learnings to Pinecone (auto-compaction handles this)

Memory Query Command:
  /memory-query "your search query" [--namespace=X]

Memory Write Command:
  /memory-write "content" --type=pattern --tags=X,Y,Z
```

## Cost Estimate

**Pinecone Serverless Pricing:**
- Storage: ~$0.25/GB/month
- Read queries: ~$0.10/1M queries
- Write operations: ~$2.00/1M writes

**Expected Usage:**
- Storage: ~5GB (100K memories) = **$1.25/month**
- Queries: ~500/day = **$0.0015/month**
- Writes: ~100/day = **$0.006/month**

**Total: ~$1.26/month**

**ROI:** $1.26/month investment → ~$200/month savings from preventing duplicate work = **159x return**

## Troubleshooting

**Issue: "PINECONE_API_KEY environment variable not set"**
```bash
export PINECONE_API_KEY="your-key"
# Or add to .env file
```

**Issue: "OPENAI_API_KEY environment variable not set"**
```bash
export OPENAI_API_KEY="your-key"
# Or add to .env file
```

**Issue: "Index not found"**
```bash
# Create index first
npx tsx .claude/scripts/pinecone-init.ts
```

**Issue: Hook not running**
- Check `.claude/settings.json` hook configuration
- Verify file paths are correct
- Check hook file permissions (should be executable)

**Issue: No memories returned**
- Check namespace spelling
- Lower `--min-confidence` threshold
- Try broader queries
- Verify memories exist in that namespace

## Advanced Usage

### Programmatic Usage

```typescript
import { queryMemory, writeMemory } from '.claude/scripts/pinecone-memory-query';

// Query
const result = await queryMemory({
  query: "authentication patterns",
  namespaces: ["pillarworks.patterns"],
  topK: 5,
  minConfidence: 0.7
});

// Write
await writeMemory({
  content: "Pattern description...",
  type: "pattern",
  repo: "pillarworks",
  domain: "architecture",
  tags: ["authentication", "JWT"],
  importance: "high"
});
```

### Memory Correction

If a memory is incorrect or outdated:

```bash
# Write corrected version with supersedes flag
npx tsx .claude/scripts/pinecone-memory-write.ts \
  --content="Corrected pattern..." \
  --type=pattern \
  --repo=pillarworks \
  --domain=architecture \
  --supersedes=<old-memory-id>
```

### Freshness Management

Configure in `.claude/memory-freshness.yaml`:

```yaml
freshness_rules:
  session_learnings:
    expire_after_days: 365
  debugging_solutions:
    expire_after_days: 180
  architecture_decisions:
    expire_after_days: 730
  incidents_postmortems:
    expire_after_days: never
```

## References

- **Full Setup Guide:** `D:\orryx-audit\pinecone\PINECONE_SETUP_GUIDE.md`
- **CLAUDE.base.md §13:** Pinecone Memory Integration
- **Pinecone Docs:** https://docs.pinecone.io/
- **OpenAI Embeddings:** https://platform.openai.com/docs/guides/embeddings

---

**Version:** 1.0.0
**Last Updated:** 2026-05-18
**Owner:** Orryx Claude Code Optimization Team
