# {REPO_NAME} — Claude Execution Protocol

> **Canonical source:** [CLAUDE.base.md in orryx-standards](https://github.com/orryx/orryx-standards/blob/main/CLAUDE.base.md)
>
> Read that first for the shared Claude execution protocol across all Orryx repositories.
> This file contains ONLY repository-specific overrides and context.

---

## Quick Reference

**Documentation:**
- [Project Status & Objectives](docs/STATUS.md) - Current sprint, goals, risks
- [Tech Stack](docs/TECH_STACK.md) - Languages, frameworks, versions
- [Development Guide](docs/DEVELOPMENT.md) - Local setup, workflows
- [Infrastructure](docs/infrastructure/AWS.md) - AWS resources, deployment
- [Governance](docs/governance/INDEX.md) - Quality gates, compliance

**Current Sprint:** {SPRINT_NAME}

**Key Objectives (Top 3):**
1. {OBJECTIVE_1}
2. {OBJECTIVE_2}
3. {OBJECTIVE_3}

**Critical Risks:**
- {RISK_1}
- {RISK_2}

---

## §1: Repository-Specific Context

### 1.1 Project Overview

**Product:** {PRODUCT_NAME}
**Purpose:** {1-2 sentence description}
**Users:** {TARGET_USERS}
**Stage:** {MVP | Beta | Production}

### 1.2 File Organization

```
{REPO_NAME}/
├── {BACKEND_DIR}/           # {Backend description}
├── {FRONTEND_DIR}/          # {Frontend description}
├── {TESTS_DIR}/             # {Tests description}
├── {DOCS_DIR}/              # Documentation
├── agents/                  # Agent configurations
└── orchestration/           # Orchestration state
```

### 1.3 Branching Strategy

- `main` - Production releases
- `develop` - Integration branch
- `feature/*` - Feature development
- `hotfix/*` - Emergency fixes

---

## §2: Domain-Specific Rules

### 2.1 {DOMAIN_1} (e.g., Clinical Compliance)

{Add domain-specific rules that override or extend CLAUDE.base.md}

Example:
- **Clinical data:** No real patient data, synthetic only
- **Decision support:** CDSS only (no diagnosis)
- **Audit logs:** 10-year retention required
- **Privacy:** AU data residency (ap-southeast-2)

### 2.2 {DOMAIN_2} (e.g., Authentication)

Example:
- **Pattern:** OAuth2 + JWT with refresh tokens
- **Storage:** Refresh tokens in httpOnly cookies
- **Expiry:** Access 15min, Refresh 7 days
- **Reference:** [Auth ADR](docs/architecture/ADRs/001-authentication.md)

---

## §3: Technology-Specific Conventions

### 3.1 Backend ({LANGUAGE})

- **Framework:** {FRAMEWORK} {VERSION}
- **Testing:** {TEST_FRAMEWORK}
- **Linting:** {LINTER_CONFIG}
- **Type checking:** {TYPE_CHECKER}

**Conventions:**
- {CONVENTION_1}
- {CONVENTION_2}

### 3.2 Frontend ({LANGUAGE})

- **Framework:** {FRAMEWORK} {VERSION}
- **State management:** {STATE_LIBRARY}
- **Styling:** {STYLING_APPROACH}
- **Testing:** {TEST_FRAMEWORK}

**Conventions:**
- {CONVENTION_1}
- {CONVENTION_2}

---

## §4: Agent Configuration

Agents are configured in `agents/claude/*.yaml`:

- **Orchestrator** - Coordinates multi-agent workflows
- **Architect** - Design and architecture decisions
- **Engineer** - Implementation and coding
- **Reviewer** - Code review and quality
- **{CUSTOM_AGENT}** - {Description}

See: [Agent README](agents/README.md)

**Default Autonomy:** L2 (End-to-end execution)

---

## §5: Overrides to Canonical Standards

### 5.1 Override §9: Context Management

{If applicable, override context budgets from CLAUDE.base.md}

Example:
```yaml
# Allow larger context for legacy codebase exploration
task_budgets:
  investigation:
    max_tokens: 200000  # Override from default 120000
```

### 5.2 Override §11: Read-Before-Edit

{If applicable, override read-before-edit requirements}

Example:
```yaml
# Relaxed for documentation-heavy repo
minimum_reads_before_edit:
  default: 2  # Override from default 4
```

### 5.3 {Additional Overrides}

{Add any other repo-specific overrides}

---

## §6: Integration Points

### 6.1 CI/CD

- **Platform:** {PLATFORM}
- **Deployment:** {DEPLOYMENT_APPROACH}
- **Environments:** {ENVIRONMENTS}

See: [Deployment Guide](docs/infrastructure/DEPLOYMENT.md)

### 6.2 Monitoring

- **APM:** {APM_TOOL}
- **Logs:** {LOG_AGGREGATION}
- **Alerts:** {ALERTING_SYSTEM}

See: [Monitoring Guide](docs/infrastructure/MONITORING.md)

### 6.3 External Services

{List key external services}

Example:
- **Auth:** Auth0
- **Payments:** Stripe
- **Email:** SendGrid

---

## §7: Common Pitfalls & Solutions

### 7.1 {COMMON_ISSUE_1}

**Problem:** {Description}
**Solution:** {How to avoid/fix}
**Reference:** {Link to detailed solution}

### 7.2 {COMMON_ISSUE_2}

**Problem:** {Description}
**Solution:** {How to avoid/fix}
**Reference:** {Link to detailed solution}

---

## §8: Quick Commands

```bash
# Setup
{SETUP_COMMAND}

# Run locally
{RUN_COMMAND}

# Run tests
{TEST_COMMAND}

# Lint
{LINT_COMMAND}

# Deploy
{DEPLOY_COMMAND}
```

---

**Last Updated:** {DATE}
**Owner:** {TEAM_NAME}
**Version:** {VERSION}
