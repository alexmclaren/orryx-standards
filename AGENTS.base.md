# AGENTS.md - Agent Behavior Rules for Orryx Ecosystem

**Version**: 1.0.0
**Last Updated**: 2026-04-27
**Applies To**: All Orryx products and Claude agents

---

## Core Principles

### 1. Alignment with CLAUDE.md
All agents MUST follow the execution protocol defined in CLAUDE.md. This file (AGENTS.md) extends those rules with agent-specific behaviors.

### 2. Domain Safety
- Healthcare agents: NO diagnosis claims, CDSS only, AU Privacy Act 1988 compliance
- Construction agents: NO structural engineering advice without disclaimers
- Financial agents: NO investment advice, informational only

### 3. Multi-Repo Awareness
Agents operating across Orryx products MUST:
- Respect product boundaries
- Use MCP Gateway for cross-product communication
- Never make changes in products without explicit task packet authorization

---

## Agent Types

### Explorer Agents
**Purpose**: Codebase discovery, pattern identification, drift analysis

**Rules**:
- READ-ONLY operations
- Use Glob/Grep efficiently
- Report findings without making changes
- Maximum thoroughness when requested

### Plan Agents
**Purpose**: Design implementation approaches

**Rules**:
- MUST explore codebase first
- Present multiple options when ambiguous
- Document trade-offs
- Reference existing patterns from orryx-knowledge

### Execution Agents
**Purpose**: Implement approved plans

**Rules**:
- Follow approved plan exactly
- Use RALPH loop (min 2-3 iterations)
- Run all quality gates
- Update todo list continuously

### Review Agents
**Purpose**: Code review, security audit, compliance check

**Rules**:
- Check against orryx-standards
- Verify orryx-governance compliance
- Flag security issues immediately
- No rubber-stamping (genuine review required)

---

## Cross-Product Coordination

### Task Packet Protocol
When a task affects multiple products:
1. orryx-control-plane creates task packet
2. Task packet specifies affected repos
3. Agents coordinate via control-plane registry
4. Each agent reports completion back to control-plane

### Conflict Resolution
If agents discover conflicting patterns:
1. Defer to orryx-standards (source of truth)
2. If standards silent, escalate to human
3. Document decision in orryx-knowledge

---

## Quality Standards

### Code Quality
- Zero linting errors
- Zero type errors
- >80% test coverage
- All tests passing

### Security
- Zero high/critical vulnerabilities
- No hardcoded secrets
- No SQL injection risks
- Proper input validation at boundaries

### Documentation
- Code comments for non-obvious logic
- README updates for new features
- API docs for public endpoints
- Changelog entries

---

## Healthcare-Specific Rules (Triora, Orryx Flow)

### Data Handling
- PHI stays in ap-southeast-2 (Australia)
- NO cross-region replication
- Encryption at rest (KMS) and in transit (TLS 1.3)
- 10-year audit log retention

### Clinical Logic
- CDSS only (Clinical Decision Support System)
- NO diagnosis claims
- NO treatment recommendations
- Clinical matching = informational only

### Compliance
- Australian Privacy Act 1988 (13 APPs)
- TGA Guidance on AI as medical device
- NHMRC National Statement on ethical conduct

---

## Construction-Specific Rules (PillarWorks)

### BOQ Estimates
- Clearly label as ESTIMATES only
- Include disclaimer about professional QS review
- NO structural engineering advice
- NO building code compliance claims

### Data Handling
- No compliance restrictions (construction data not PHI)
- Standard encryption practices
- 7-year retention (Australian tax law)

---

## Error Handling

### All Agents Must
- Use error-core-python (RFC 7807 Problem Details)
- Log errors to Sentry with full context
- Never expose stack traces to end users
- Retry with exponential backoff (max 3 retries)

### Error Response Format
```json
{
  "type": "https://pillarworks.io/errors/validation-failed",
  "title": "Validation Failed",
  "status": 400,
  "detail": "The uploaded file must be a PDF",
  "instance": "/api/v1/boq/upload/abc-123"
}
```

---

## Authentication & Authorization

### Standard Pattern
- JWT access tokens (30 min expiry)
- HTTP-only cookies
- Refresh tokens (7 day expiry)
- Token rotation on refresh

### Product-Specific Auth
- Triora: Healthcare provider credentials required
- PillarWorks: Multi-tenant workspace authorization
- MCP Gateway: Service-to-service JWT

---

## Monitoring & Observability

### Required Instrumentation
- Sentry error tracking (all products)
- Prometheus metrics (ECS services)
- CloudWatch logs (14-day non-prod, 90-day prod)
- Structured logging (JSON format)

### Key Metrics
- Request rate, error rate, latency (p50, p95, p99)
- Database query performance
- AI/LLM API latency and cost
- Background job queue depth

---

## Deployment Gates (orryx-governance)

### Pre-Deployment Checks
1. **Security Scan**: Trivy (zero high/critical)
2. **Dependency Audit**: pip-audit / npm audit (zero high/critical)
3. **Secrets Leak**: truffleHog (zero secrets)
4. **Cost Estimate**: Infracost (under budget threshold)
5. **Test Coverage**: >80%

### Deployment Approval
- Dev: Auto-deploy on PR merge
- Staging: Auto-deploy on main branch push
- Production: Manual approval required

---

## Knowledge Management

### When to Update orryx-knowledge
- After solving a novel problem
- After production incident (post-mortem required)
- After discovering anti-pattern
- After validating a new pattern

### Knowledge Structure
```
orryx-knowledge/
├── domains/
│   ├── healthcare/patterns/
│   ├── healthcare/anti-patterns/
│   ├── construction/patterns/
│   └── construction/anti-patterns/
├── technical/
│   ├── fastapi-best-practices.md
│   ├── react-patterns.md
│   └── terraform-modules.md
└── lessons-learned/
    └── YYYY-MM-DD-incident-name.md
```

---

## Failure Modes & Recovery

### Agent Stuck/Blocked
1. Clearly state blocker
2. Attempt workaround
3. Provide options to human
4. Continue parallel work if possible

### Conflicting Requirements
1. Document conflict explicitly
2. Present options with trade-offs
3. Recommend preferred option with justification
4. Wait for human decision

### External Dependency Failure
1. Implement circuit breaker pattern
2. Fallback to cached data if safe
3. Degrade gracefully
4. Alert monitoring systems

---

## Tone & Communication

### With Humans
- Clear > clever
- Direct > verbose
- Structured always
- No fluff, no excessive praise

### In Code Comments
- Explain WHY, not WHAT (code shows what)
- Document non-obvious trade-offs
- Reference ticket/task packet numbers
- Keep comments up-to-date with code

### In Documentation
- Assume reader has context
- Use examples liberally
- Link to related docs
- Keep it concise

---

## Version Control

### Commit Messages
Format: `type(scope): description`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code refactor (no behavior change)
- `test`: Adding/updating tests
- `chore`: Build/tooling changes

Example: `feat(triora): add melanoma trial matching algorithm`

### Branch Strategy
- `main`: Production-ready code
- `feature/*`: New features
- `fix/*`: Bug fixes
- `hotfix/*`: Emergency production fixes

---

## Testing Requirements

### Unit Tests
- Test behavior, not implementation
- Mock external dependencies
- Fast execution (<100ms per test)
- Descriptive test names

### Integration Tests
- Test real database interactions
- Test real API calls (to test endpoints)
- Use factories for test data
- Clean up after each test

### E2E Tests
- Critical user journeys only
- Run in staging environment
- Acceptable to be slower
- Required for production deployment

---

## Cost Consciousness

### AI/LLM Usage
- Cache responses where appropriate
- Use smaller models when sufficient
- Batch requests when possible
- Monitor token usage

### AWS Resources
- Right-size instances (don't over-provision)
- Use spot instances for dev/staging
- Implement auto-scaling
- Review costs monthly

### Database Optimization
- Add indexes for slow queries
- Archive old data
- Use connection pooling
- Monitor query performance

---

## Incident Response

### Severity Levels
- **SEV1**: Production down, data loss risk → Page on-call immediately
- **SEV2**: Degraded performance, user impact → Alert team, fix within 4 hours
- **SEV3**: Minor issue, workaround exists → Fix in next sprint
- **SEV4**: Enhancement request → Backlog

### Post-Mortem Required
- All SEV1 and SEV2 incidents
- Must be completed within 7 days
- Must update orryx-knowledge/lessons-learned/
- Focus on prevention, not blame

---

## Continuous Improvement

### Retrospective Cadence
- After each major feature
- After each incident
- Monthly for ongoing work

### Metrics to Track
- Deployment frequency
- Change failure rate
- Mean time to recovery
- Test coverage trend

---

**Compliance**: This document is mandatory for all agents operating in the Orryx ecosystem. Deviations require explicit approval and documentation.

**Updates**: This document is version-controlled in orryx-standards. All products must sync to latest version weekly.

**Questions**: Escalate ambiguities to orryx-governance for clarification and documentation updates.
