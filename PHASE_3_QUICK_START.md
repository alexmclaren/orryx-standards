# Phase 3 Quick Start - Environment Setup

**Platform:** Windows (PowerShell)  
**Time Required:** 5-10 minutes setup + 30-60 minutes seeding

---

## Step 1: Set OPENAI_API_KEY

### Get API Key
1. Go to: https://platform.openai.com/api-keys
2. Create new key (or use existing)
3. Copy the key: `sk-proj-...`

### Set in PowerShell

```powershell
# Option A: Current session only (quick test)
$env:OPENAI_API_KEY = "sk-proj-..."

# Verify
echo $env:OPENAI_API_KEY

# Option B: Permanent (recommended)
[System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', 'sk-proj-...', 'User')

# Then restart PowerShell and verify
echo $env:OPENAI_API_KEY
```

### Alternative: Update AWS Secrets Manager

```powershell
aws secretsmanager update-secret `
  --secret-id orryx/directors/openai/api_key `
  --secret-string "sk-proj-..." `
  --region us-east-1
```

---

## Step 2: Verify Pinecone Connection

```powershell
# Set Pinecone key (already have this)
$env:PINECONE_API_KEY = "pcsk_5RuMNx_..."

# Verify connection (script to be created in Phase 3)
npx tsx D:\orryx-standards\.claude\scripts\pinecone-verify.ts
```

Expected output:
```
✓ Connected to Pinecone
✓ Index: orryx-dev-intelligence exists
✓ Dimension: 1536
✓ Metric: cosine
```

---

## Step 3: Run Historical Seeding Scripts

**Note:** These scripts will be created as part of Phase 3 autonomous work.

```powershell
cd D:\orryx-standards\.claude\scripts

# Seed ADRs (5-10 minutes)
npx tsx seed-historical-adrs.ts

# Expected: ~100 ADRs seeded to architecture namespaces

# Seed Git debugging history (20-30 minutes)
npx tsx seed-git-debugging.ts --repo=orryx-brain --max-commits=200
npx tsx seed-git-debugging.ts --repo=pillarworks --max-commits=200

# Expected: ~250 debugging solutions seeded

# Seed patterns (5-10 minutes)
npx tsx seed-patterns.ts

# Expected: ~150 patterns seeded

# Seed Codeburn findings (2-3 minutes)
npx tsx seed-codeburn-findings.ts

# Expected: ~50 optimization patterns seeded

# Seed standards (2-3 minutes)
npx tsx seed-standards.ts

# Expected: ~50 standards seeded
```

---

## Step 4: Verify Seeding

```powershell
# Check namespace counts
npx tsx D:\orryx-standards\.claude\scripts\pinecone-verify.ts --count-by-namespace
```

Expected output:
```
Namespace counts:
orryx-brain.architecture: 45
orryx-brain.debugging: 120
orryx-brain.patterns: 80
pillarworks.architecture: 55
pillarworks.debugging: 130
pillarworks.patterns: 70
codeburn.findings: 50
standards.global: 50
Total: 600 memories
```

---

## Troubleshooting

### "Command not found: npx"

```powershell
# Install Node.js from: https://nodejs.org/
# Then verify:
node --version
npm --version
```

### "OPENAI_API_KEY not set"

```powershell
# Check if set:
echo $env:OPENAI_API_KEY

# If empty, set again:
$env:OPENAI_API_KEY = "sk-proj-..."
```

### "Pinecone index not found"

1. Go to: https://app.pinecone.io
2. Verify index `orryx-dev-intelligence` exists
3. Check dimension is 1536
4. Check metric is cosine

---

## What Happens Next (Autonomous)

After you complete Phase 3, I will automatically proceed with:

**Phase 4: Integration Testing (2 hours)**
- Test memory queries in ce-brainstorm, ce-debug, ce-work
- Validate end-to-end workflows
- Measure performance metrics

**Phase 5: Governance Enforcement (6-10 hours, optional)**
- Enable hard governance gates
- Set up Codeburn weekly routine
- Create override procedures

---

## Current Status

✅ **Complete:**
- Track 1: Hook Registration
- Track 2: Agent Configuration (24 agents)
- Phase 1: CLAUDE.md Restructuring (8.7K tokens saved)
- Phase 2: Hook Implementation (601 lines)

⏸️ **Blocked (Your Action Required):**
- Phase 3: Environment Setup + Historical Seeding

🔜 **Ready (Autonomous):**
- Phase 4: Integration Testing
- Phase 5: Governance Enforcement

---

**Time Estimate:** 40-70 minutes total for Phase 3

**Next:** Once environment is set up, signal me and I'll proceed autonomously with Phase 4.
