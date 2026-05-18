# Claude Code Governance Configuration

Comprehensive governance configuration for the Orryx Claude Code ecosystem.

## Overview

This directory contains YAML configuration files that control all governance systems:

| File | Purpose | Addresses |
|------|---------|-----------|
| **governance.yaml** | Master governance orchestration | Overall health, hook coordination |
| **context-budget.yaml** | Context management & token budgets | 148 context-heavy sessions (36-40:1 ratio) |
| **execution-budgets.yaml** | Retry limits & loop detection | 35 high-retry sessions (22-134 retries) |
| **read-before-edit.yaml** | Read-before-edit enforcement | Read:edit ratio 2.1:1 (target: >4:1) |
| **memory-freshness.yaml** | Pinecone memory lifecycle | Memory staleness, validation |
| **codeburn.yaml** | Codeburn integration & monitoring | Real-time monitoring, weekly scans |

## Configuration Architecture

```
governance.yaml (MASTER)
├── Orchestrates all systems
├── Defines enforcement levels
├── Coordinates hooks
└── Manages escalation rules
    │
    ├─► context-budget.yaml
    │   ├── Task-scoped budgets
    │   ├── Auto-reset triggers
    │   ├── Staged execution
    │   └── Auto-summarization
    │
    ├─► execution-budgets.yaml
    │   ├── Retry budgets by task
    │   ├── Loop detection patterns
    │   ├── Confidence-based escalation
    │   └── Approval checkpoints
    │
    ├─► read-before-edit.yaml
    │   ├── Mandatory exploration
    │   ├── Dependency tracing
    │   ├── Pre-edit validation
    │   └── Enforcement layers
    │
    ├─► memory-freshness.yaml
    │   ├── Expiration rules
    │   ├── Validation workflow
    │   ├── Usage-based retention
    │   └── Auto-correction
    │
    └─► codeburn.yaml
        ├── Session monitoring
        ├── Analysis schedule
        ├── Issue auto-creation
        └── Pinecone integration
```

## Quick Start

### 1. Validate Configuration

```bash
# Check YAML syntax
yamllint .claude/config/*.yaml

# Validate against schema (if available)
npx tsx .claude/scripts/validate-config.ts
```

### 2. Enable Governance Systems

Edit `governance.yaml` to enable/disable systems:

```yaml
systems:
  context_management:
    enabled: true
    enforcement_level: "hard"

  read_before_edit:
    enabled: true
    enforcement_level: "hard"

  execution_budgets:
    enabled: true
    enforcement_level: "hard"
```

### 3. Repository-Specific Overrides

Create local override files in your repo:

```yaml
# .claude/config/governance.local.yaml
systems:
  execution_budgets:
    enforcement_level: "soft"  # Override for this repo
```

## Governance Systems

### 1. Context Management (`context-budget.yaml`)

**Problem:** 148 sessions with 36-40:1 input/cache-to-output ratios

**Solution:**
- Task-scoped budgets (typo fix: 2K, feature: 150K tokens)
- Automatic context reset triggers
- Staged execution (Design → Implement → Test → Docs)
- Working memory summarization every 3 stories

**Target Impact:**
- Avg input:output ratio: 36-40:1 → <8:1
- Context-heavy sessions: 148/month → <20/month
- Wasted context: ~75% → <25%

### 2. Execution Budgets (`execution-budgets.yaml`)

**Problem:** 35 sessions with 22-134 retries, no loop detection

**Solution:**
- Retry budgets by task type (typo: 2, feature: 25)
- Loop detection (identical errors, oscillating, code churn)
- Circuit breaker pattern (opens after 5 failures)
- Confidence-based escalation

**Target Impact:**
- Sessions >10 retries: 35/month → <5/month
- Sessions >50 retries: ~5/month → 0/month
- Loop detection triggers: 0 → ~10/month (good!)

### 3. Read-Before-Edit Governance (`read-before-edit.yaml`)

**Problem:** Read:edit ratio 2.1:1 (should be 4+:1)

**Solution:**
- Mandatory exploration checklist (7 items)
- Dependency tracing (imports, importers, callers)
- Pre-edit validation checkpoints
- Multi-layer enforcement (hooks, skills, standards)

**Target Impact:**
- Read:edit ratio: 2.1:1 → >4:1
- First-attempt success: ~50% → >80%
- Premature edit blocks: 0 → ~20/month (intentional)

### 4. Memory Freshness (`memory-freshness.yaml`)

**Problem:** No memory expiration or validation strategy

**Solution:**
- Expiration rules by memory type (sessions: 365d, debugging: 180d)
- Usage-based retention (frequently used = extended lifetime)
- Automatic validation workflow
- Memory correction protocol

**Target Impact:**
- Stale memories: Unknown → <10%
- Memory quality: Unknown → >80% validated
- Duplicate prevention: 0 → ~30% duplicate work avoided

### 5. Codeburn Integration (`codeburn.yaml`)

**Problem:** No continuous monitoring or automated improvement

**Solution:**
- Real-time session monitoring
- Weekly comprehensive scans
- Auto-create GitHub issues for regressions
- Write findings to Pinecone

**Target Impact:**
- Regressions detected: Unknown → <24 hours
- Issues auto-created: 0 → ~5/week
- Codeburn scans: 0 → 7/week

## Enforcement Levels

Each governance system has an enforcement level:

| Level | Behavior | Can Override? | Logs | Alerts |
|-------|----------|---------------|------|--------|
| **hard** | Blocks execution until resolved | No | Yes | Yes |
| **soft** | Blocks but allows override with justification | Yes | Yes | Yes |
| **warn** | Warns but allows continuation | Yes | Yes | No |

### Changing Enforcement Levels

```yaml
# In governance.yaml
systems:
  read_before_edit:
    enforcement_level: "hard"  # Change to "soft" or "warn"
```

## Hook Orchestration

Governance is enforced via hooks at key lifecycle events:

```yaml
hooks:
  pre_planning:
    - memory-retrieval (non-blocking)
    - context-budget-check (blocking)

  pre_edit:
    - memory-retrieval (non-blocking)
    - read-before-edit-gate (blocking)
    - dependency-check (non-blocking)

  pre_debugging:
    - memory-retrieval (non-blocking)
    - execution-budget-check (blocking)

  post_story:
    - memory-write (non-blocking)
    - session-metrics-log (non-blocking)

  pre_commit:
    - lint-check (blocking)
    - type-check (blocking)
    - test-check (blocking)
    - security-scan (blocking)
```

## Escalation Rules

Governance escalates to humans when:

```yaml
escalation:
  triggers:
    - retry_count > max_retries → block_and_escalate
    - confidence_score < 0.3 → warn_and_escalate
    - cost_budget_exceeded → block_and_escalate
    - loop_detected → block_and_escalate
    - critical_domain_change → require_human_review

  critical_domains:
    - authentication, authorization, payment
    - data-migration, patient-data
    - clinical-logic, compliance, privacy
```

## Monitoring & Dashboards

### Governance Dashboard

Auto-updated at `docs/governance/DASHBOARD.md`:

```markdown
## Health Score: B (85/100)

### Violations (Last 7 Days)
- Context budget exceeded: 3 times
- Read-before-edit blocked: 12 times (good!)
- Loop detected: 1 time

### Trends
- Read:edit ratio: 2.1 → 3.8 (improving ✅)
- Avg retries: 8 → 4 (improving ✅)
- Context-heavy sessions: 148 → 52 (improving ✅)
```

### Codeburn Dashboard

Auto-updated at `docs/governance/CODEBURN_DASHBOARD.md`:

```markdown
## Health Score: F → C (20 → 72) +52 points ✅

### Critical Issues
- 0 sessions >100 retries (was 5) ✅
- 12 context-heavy sessions (was 148) ✅

### Savings
- Monthly cost: $2,055 → $1,200 (-42%) ✅
- Savings achieved: $855/month
```

## Configuration Validation

### Syntax Validation

```bash
# Install yamllint
pip install yamllint

# Validate
yamllint .claude/config/*.yaml
```

### Semantic Validation

```bash
# Run config validator (TODO: implement)
npx tsx .claude/scripts/validate-config.ts
```

### Test Configuration

```bash
# Dry-run with test data
CLAUDE_CONFIG_DRY_RUN=true npx tsx .claude/scripts/test-governance.ts
```

## Troubleshooting

### Issue: Governance blocking legitimate work

**Solution 1: Temporary override**
```yaml
# .claude/config/governance.local.yaml
systems:
  read_before_edit:
    enforcement_level: "soft"  # Allow overrides
```

**Solution 2: Emergency bypass**
```bash
# Set environment variable
export CLAUDE_GOVERNANCE_BYPASS="true"
export CLAUDE_GOVERNANCE_BYPASS_REASON="Emergency hotfix for production incident"
```

### Issue: Too many alerts

**Solution: Adjust thresholds**
```yaml
# In codeburn.yaml
immediate_alerts:
  context_heavy:
    condition: "input_to_output_ratio > 50:1"  # More lenient
```

### Issue: Configuration not loading

**Check:**
1. YAML syntax errors: `yamllint .claude/config/*.yaml`
2. File permissions: `ls -la .claude/config/`
3. Logs: `.claude/logs/governance.log`

## Best Practices

### 1. Start with Soft Enforcement

```yaml
systems:
  read_before_edit:
    enforcement_level: "soft"  # Start soft, tighten later
```

### 2. Monitor Before Enforcing

Enable monitoring first, observe for 1 week, then enforce:

```yaml
# Week 1: Monitor only
monitoring:
  enabled: true
enforcement:
  enabled: false

# Week 2+: Enforce
enforcement:
  enabled: true
```

### 3. Repo-Specific Tuning

Different repos have different needs:

```yaml
# Experimental repo: Relaxed
execution_budgets:
  feature_small:
    max_attempts: 20  # More experimentation

# Production repo: Strict
execution_budgets:
  feature_small:
    max_attempts: 10  # Tighter control
```

### 4. Review Dashboard Weekly

Schedule weekly team reviews of:
- Governance dashboard
- Codeburn dashboard
- Violation trends
- Optimization backlog

## Migration Guide

### From No Governance → Full Governance

**Phase 1: Monitoring (Week 1)**
```yaml
# Enable monitoring, no enforcement
systems:
  context_management:
    enabled: true
    enforcement_level: "warn"
```

**Phase 2: Soft Enforcement (Weeks 2-3)**
```yaml
# Enable soft enforcement with overrides
systems:
  context_management:
    enforcement_level: "soft"
```

**Phase 3: Hard Enforcement (Week 4+)**
```yaml
# Enable hard enforcement
systems:
  context_management:
    enforcement_level: "hard"
```

## Configuration Reference

### Complete Example

See `governance.yaml` for the complete master configuration with all systems enabled.

### Schema Documentation

(TODO: Generate JSON schema for validation)

## Support & Contributions

**Issues:**
- File issues at: `orryx/optimization-tracking`
- Tag with: `governance`, `config`

**Questions:**
- Slack: `#claude-code-governance`
- Docs: `docs/governance/`

---

**Version:** 1.0.0
**Last Updated:** 2026-05-18
**Owner:** Orryx Claude Code Optimization Team
