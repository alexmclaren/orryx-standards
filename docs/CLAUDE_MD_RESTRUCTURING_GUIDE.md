# CLAUDE.md Restructuring Guide

**Purpose:** Transform bloated repository-specific CLAUDE.md files into lean overrides that reference canonical standards

**Target:** Pillarworks (992 lines), Orryx-brain (680 lines), all repos with >150 line CLAUDE.md files

**Goal:** Reduce from ~500K tokens per session → ~50K tokens per session (90% reduction)

---

## Problem Analysis

### Current State (Example: Pillarworks)

**File:** `D:\pillarworks-build-mvp\claude.md`
**Size:** 992 lines, 34.9K chars (~85.9K tokens per session)

**Content Breakdown:**
- Lines 1-50: Project overview, status, objectives (EXTERNAL → docs/STATUS.md)
- Lines 51-150: Tech stack details (EXTERNAL → docs/TECH_STACK.md)
- Lines 151-300: AWS infrastructure (EXTERNAL → docs/infrastructure/AWS.md)
- Lines 301-450: MCP endpoints (EXTERNAL → docs/governance/mcp.md)
- Lines 451-650: Agent configurations (ALREADY in agents/ directory)
- Lines 651-800: Orchestration workflows (EXTERNAL → orchestration/SYNC_STATE.md)
- Lines 801-950: Governance details (EXTERNAL → docs/governance/INDEX.md)
- Lines 951-992: Repository references (KEEP as override)

**Problems:**
1. **Duplication:** Much content already exists in other files
2. **Scope creep:** CLAUDE.md has become dumping ground
3. **Tech stack details:** These change frequently, bloat context
4. **URLs and endpoints:** Specific infrastructure details
5. **Embedded workflows:** Already documented in agent configs

---

## Restructuring Strategy

### Phase 1: Create External Documentation Structure

Create these directories and files in the target repo:

```
{repo}/
├── docs/
│   ├── STATUS.md                      # Project status, objectives, milestones
│   ├── TECH_STACK.md                  # Tech stack, versions, dependencies
│   ├── DEVELOPMENT.md                 # Dev workflows, local setup
│   ├── infrastructure/
│   │   ├── AWS.md                     # AWS infrastructure details
│   │   ├── DEPLOYMENT.md              # Deployment procedures
│   │   └── MONITORING.md              # Monitoring and observability
│   └── governance/
│       ├── INDEX.md                   # Governance overview
│       ├── mcp.md                     # MCP server configurations
│       └── quality-gates.md           # Quality gate configurations
├── orchestration/
│   └── SYNC_STATE.md                  # Orchestration state, workflows
├── CHANGELOG.md                       # Version history, changes
└── CLAUDE.md                          # Minimal override (target: <150 lines)
```

### Phase 2: Extract Content

#### Extract 1: Project Status → docs/STATUS.md

**From CLAUDE.md, extract:**
- Current sprint/phase
- Active objectives
- Current risks
- Recent achievements
- Next steps

**Template:** `D:\orryx-standards\templates\STATUS.template.md`

#### Extract 2: Tech Stack → docs/TECH_STACK.md

**From CLAUDE.md, extract:**
- Language versions
- Framework versions
- Key dependencies
- Infrastructure stack
- External services

**Template:** `D:\orryx-standards\templates\TECH_STACK.template.md`

#### Extract 3: AWS Infrastructure → docs/infrastructure/AWS.md

**From CLAUDE.md, extract:**
- AWS account details
- Deployed services
- Environment configurations
- Access patterns
- Cost monitoring

**Template:** `D:\orryx-standards\templates\AWS.template.md`

#### Extract 4: MCP Configuration → docs/governance/mcp.md

**From CLAUDE.md, extract:**
- MCP server endpoints
- Authentication details
- Available tools/resources
- Usage patterns

**Template:** `D:\orryx-standards\templates\MCP.template.md`

#### Extract 5: Governance → docs/governance/INDEX.md

**From CLAUDE.md, extract:**
- Quality gates
- Review processes
- Compliance requirements
- Approval workflows

**Template:** `D:\orryx-standards\templates\GOVERNANCE.template.md`

### Phase 3: Create Minimal CLAUDE.md

**New CLAUDE.md structure:**

```markdown
# {Repo Name} — Claude Execution Protocol

> **Canonical source:** [CLAUDE.base.md in orryx-standards](https://github.com/orryx/orryx-standards/blob/main/CLAUDE.base.md)
> Read that first for the shared Claude execution protocol across all Orryx repositories.

---

## Repository-Specific Overrides

### §X.1: Project Context

**Quick Links:**
- [Project Status & Objectives](docs/STATUS.md)
- [Tech Stack](docs/TECH_STACK.md)
- [Development Guide](docs/DEVELOPMENT.md)
- [Infrastructure](docs/infrastructure/AWS.md)
- [Governance](docs/governance/INDEX.md)

**Current Sprint:** {sprint_name}
**Key Objectives:** {1-3 bullet points}
**Critical Risks:** {1-2 bullet points}

### §X.2: Domain-Specific Rules

**Clinical Compliance** (if applicable):
- No real patient data
- CDSS only (no diagnosis)
- 10-year audit logs required

**Authentication** (if applicable):
- OAuth2 + JWT pattern
- Refresh tokens in httpOnly cookies
- See: [Auth Architecture ADR](docs/architecture/ADRs/001-authentication.md)

### §X.3: Repository Conventions

**File Organization:**
- `backend/`: Python FastAPI backend
- `frontend/`: React + TypeScript frontend
- `tests/`: Pytest test suite
- `docs/`: Documentation

**Branching:**
- `main`: Production
- `develop`: Integration
- `feature/*`: Features
- `hotfix/*`: Urgent fixes

### §X.4: Agent Configuration

Agents configured in `agents/claude/*.yaml`:
- Orchestrator, Architect, Engineer, Reviewer, etc.

See: [Agent README](agents/README.md)

### §X.5: Custom Overrides

{Any repo-specific overrides to CLAUDE.base.md protocols}

Example:
- Override §9 Context Management: Allow 200K tokens for legacy codebase exploration

---

**Last Updated:** {date}
**Owner:** {team_name}
```

**Target Size:** 50-150 lines

---

## Step-by-Step Restructuring Process

### For Pillarworks (Example)

#### Step 1: Backup Current CLAUDE.md

```bash
cd /d/pillarworks-build-mvp
cp claude.md claude.md.backup.20260518
git add claude.md.backup.20260518
git commit -m "Backup: Original CLAUDE.md before restructuring"
```

#### Step 2: Create docs/ Structure

```bash
mkdir -p docs/infrastructure
mkdir -p docs/governance

# Create initial files
touch docs/STATUS.md
touch docs/TECH_STACK.md
touch docs/DEVELOPMENT.md
touch docs/infrastructure/AWS.md
touch docs/governance/INDEX.md
touch docs/governance/mcp.md
```

#### Step 3: Extract Content

**Use extraction script:**
```bash
npx tsx /d/orryx-standards/scripts/extract-claude-md-content.ts \
  --input=claude.md \
  --output-dir=docs/ \
  --repo=pillarworks
```

**Or manually extract** using templates from `orryx-standards/templates/`

#### Step 4: Validate Extracted Content

```bash
# Verify all links work
npx tsx /d/orryx-standards/scripts/validate-docs-links.ts

# Check for broken references
grep -r "docs/" claude.md.backup.20260518 | \
  while read line; do
    # Check if file exists
  done
```

#### Step 5: Create New Minimal CLAUDE.md

```bash
# Use template
cp /d/orryx-standards/templates/CLAUDE.override.template.md claude.md

# Customize for Pillarworks
vim claude.md
```

#### Step 6: Test and Validate

**Test Checklist:**
1. [ ] Claude Code loads new CLAUDE.md without errors
2. [ ] All referenced docs/ files exist and are readable
3. [ ] Agents can access external documentation
4. [ ] No broken links
5. [ ] Context size reduced (measure before/after)

**Measure Context Reduction:**
```bash
# Before
wc -w claude.md.backup.20260518  # Should be ~17K words

# After
wc -w claude.md  # Should be <3K words
```

#### Step 7: Git Commit

```bash
git add docs/ claude.md
git commit -m "refactor: Restructure CLAUDE.md - externalize content to docs/

- Reduce CLAUDE.md from 992 to ~120 lines (88% reduction)
- Extract project status to docs/STATUS.md
- Extract tech stack to docs/TECH_STACK.md
- Extract infrastructure to docs/infrastructure/AWS.md
- Extract governance to docs/governance/INDEX.md
- Extract MCP config to docs/governance/mcp.md
- Reference canonical CLAUDE.base.md from orryx-standards

Estimated token reduction: ~75K tokens per session
See: CLAUDE_MD_RESTRUCTURING_GUIDE.md"

git push origin feature/claude-md-restructure
```

#### Step 8: Create PR

**PR Title:** `Restructure CLAUDE.md: Externalize content for 88% size reduction`

**PR Description:**
```markdown
## Summary
Restructure bloated CLAUDE.md (992 lines) into lean override (<150 lines) that references canonical standards.

## Changes
- ✅ Extract project status → docs/STATUS.md
- ✅ Extract tech stack → docs/TECH_STACK.md
- ✅ Extract infrastructure → docs/infrastructure/AWS.md
- ✅ Extract governance → docs/governance/INDEX.md
- ✅ Extract MCP config → docs/governance/mcp.md
- ✅ Create minimal CLAUDE.md referencing orryx-standards

## Impact
- **Token reduction:** ~75K tokens per session (88% reduction)
- **Maintainability:** Easier to update tech stack without touching CLAUDE.md
- **Clarity:** Behavior (CLAUDE.md) vs details (docs/) separation
- **Consistency:** References canonical CLAUDE.base.md

## Testing
- [x] Claude Code loads new CLAUDE.md successfully
- [x] All documentation links functional
- [x] Agent workflows unaffected
- [x] Context size measured: 85.9K → ~10K tokens

## Rollout Plan
1. Merge to `develop`
2. Test with 5 sessions
3. Monitor context usage
4. Merge to `main` if successful

## References
- CLAUDE_MD_RESTRUCTURING_GUIDE.md
- CLAUDE_MD_AUDIT.md (original analysis)
```

---

## Validation Checklist

After restructuring, verify:

- [ ] **Size:** New CLAUDE.md is <150 lines
- [ ] **References:** All docs/ links work
- [ ] **Canonical:** References orryx-standards/CLAUDE.base.md
- [ ] **Agents:** Agent workflows still function
- [ ] **Hooks:** Governance hooks still trigger
- [ ] **Context:** Measured token reduction achieved
- [ ] **Completeness:** No critical info lost
- [ ] **Git:** Backed up original, committed changes
- [ ] **PR:** Created with clear description
- [ ] **Testing:** Tested with real Claude Code sessions

---

## Rollback Plan

If issues arise:

```bash
# Revert to backup
cp claude.md.backup.20260518 claude.md
git add claude.md
git commit -m "Rollback: Restore original CLAUDE.md due to {issue}"
git push origin hotfix/claude-md-rollback
```

---

## Success Metrics

**Per Repository:**
- CLAUDE.md size: 500-1000 lines → <150 lines (70-85% reduction)
- Token overhead: ~60-86K → ~8-15K tokens (80-85% reduction)
- Maintainability: Changes to tech stack/infrastructure don't touch CLAUDE.md

**Across Ecosystem:**
- Total context reduction: ~500K tokens/session → ~50K tokens/session
- Cost impact: ~$0.25/session saved
- Annual savings (1000 sessions/year): ~$250/year per repo

---

## Troubleshooting

### Issue: "File not found" errors

**Cause:** Broken links to extracted docs
**Fix:**
```bash
# Check all links
grep -r "docs/" claude.md | while read line; do
  file=$(echo "$line" | sed 's/.*(\(docs\/[^)]*\)).*/\1/')
  if [ ! -f "$file" ]; then
    echo "Missing: $file"
  fi
done
```

### Issue: Agents can't find information

**Cause:** Critical info not in external docs or CLAUDE.md override
**Fix:** Add to CLAUDE.md override section or create missing doc

### Issue: Context size not reduced

**Cause:** External docs too large, loaded into context anyway
**Fix:** Ensure external docs are NOT loaded by default, only on-demand

---

## Template Files

All templates available in:
- `D:\orryx-standards\templates\CLAUDE.override.template.md`
- `D:\orryx-standards\templates\STATUS.template.md`
- `D:\orryx-standards\templates\TECH_STACK.template.md`
- `D:\orryx-standards\templates\AWS.template.md`
- `D:\orryx-standards\templates\GOVERNANCE.template.md`
- `D:\orryx-standards\templates\MCP.template.md`

---

**Version:** 1.0.0
**Last Updated:** 2026-05-18
**Owner:** Orryx Claude Code Optimization Team
