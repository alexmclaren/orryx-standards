# CLAUDE.md - Orryx Master Standards

> This is the MASTER copy in orryx-standards.
> Distributed to all product repos. Do not edit in product repos.
> Last synced: [AUTO-UPDATED]

---

# 0. 🚨 CORE OPERATING PRINCIPLES (NON-NEGOTIABLE)

### 0.1 PLAN MODE FIRST (MANDATORY)

Claude MUST NOT begin implementation immediately.

Every non-trivial task MUST start with:
1. **PLAN MODE**
2. **Human approval (if required) OR autonomous continuation**
3. **EXECUTION MODE**

---

### 0.2 AUTONOMOUS DELIVERY DEFAULT

Default assumption:
> Claude operates autonomously until the task is fully complete.

Claude should:
- Continue working without waiting for input
- Resolve gaps independently where safe
- Only stop when:
  - Blocked by external dependency
  - Requires human approval
  - Reaches defined completion criteria

---

### 0.3 ACCEPTANCE CRITERIA FIRST

Before any work begins, Claude MUST define:
- What "DONE" looks like
- How it will be verified
- What success metrics exist

If unclear → Claude must define it.

---

### 0.4 PRODUCTION REALITY > ASSUMPTIONS

Claude must always validate:
- What ACTUALLY exists (APIs, DB, infra)
- What is BROKEN vs PLANNED
- What is MOCKED vs REAL

Never trust:
- Docs (may be outdated)
- Frontend assumptions
- Old schemas

Always verify against:
- Running system
- Logs
- API responses

---

# 1. EXECUTION FRAMEWORK

## 1.1 PLAN MODE (REQUIRED)

Claude must output structured plan before acting.

### PLAN MODE OUTPUT

1. **Objective**
2. **Current State (Reality Check)**
3. **Target State**
4. **Gaps Identified**
5. **Approach Options** (if applicable)
6. **Chosen Approach**
7. **Step-by-Step Execution Plan**
8. **Risks**
9. **Acceptance Criteria**
10. **Autonomy Level** (L0–L3)

---

## 1.2 EXECUTION PATTERNS

### Standard Execution
For simple, well-defined tasks.

### Deep Research
For unclear requirements or unknown codebase areas.
- Use explorer agent capabilities
- Thorough investigation
- Multiple options evaluated
- Recommendation with evidence

### RALPH Loop
For complex problems requiring iteration.
- Research → Analyze → Learn → Plan → Hypothesize
- Min 2 iterations, max 5
- Exit when acceptance criteria met

### Swarming
For large tasks with independent components.
- Multiple agents in parallel
- Coordinated via control plane
- Combined deliverable

### Parallel Tasks
For independent tasks across products.
- Execute simultaneously
- Max 3 concurrent

---

## 1.3 QUALITY GATES (NON-BYPASSABLE)

| Gate | Requirement |
|------|------------|
| Lint | 0 errors |
| Types | 0 errors |
| Tests | 100% pass |
| Coverage | >80% |
| Security | 0 high/critical |
| Secrets | 0 leaks |

---

## 1.4 CROSS-REPO AWARENESS

Claude must be aware of:
- **orryx-governance**: Security and compliance policies
- **orryx-standards**: This document and coding standards
- **orryx-knowledge**: Domain knowledge and patterns

Always reference these before implementing.

---

# 2. HEALTHCARE DOMAIN RULES

## 2.1 PATIENT DATA

**Classification**: HIGHLY SENSITIVE

**Requirements**:
- Encrypt at rest (AES-256)
- Encrypt in transit (TLS 1.3)
- Log all access (immutable, 10-year retention)
- AU data residency only (ap-southeast-2)

**Forbidden**:
- Storing patient data in frontend localStorage
- Logging patient data
- Displaying patient data in error messages

## 2.2 CLINICAL DECISION SUPPORT

Orryx products are **CDSS systems** (Clinical Decision Support), not diagnostic tools.

**Requirements**:
- All recommendations cite source (RACGP guidelines)
- Clear that this is decision support, not diagnosis
- Healthcare professional makes final decision

**Forbidden**:
- Claiming to diagnose
- Overriding clinician judgment
- Unsourced recommendations

## 2.3 CONSENT MANAGEMENT

**Requirements**:
- Explicit consent before collection
- Granular consent options
- Ability to revoke consent
- Audit trail of consent changes

---

# 3. TESTING STANDARDS

## 3.1 Test-Driven Development

1. Write tests FIRST
2. Implement minimal solution
3. Pass tests
4. Refactor

## 3.2 Coverage Requirements

- Unit tests: 80% minimum
- Integration tests: Critical paths
- E2E tests: Happy paths + key error cases

## 3.3 Test Structure

```typescript
describe('Feature', () => {
  describe('when condition', () => {
    it('should expected_behavior', () => {
      // Arrange
      // Act
      // Assert
    });
  });
});
```

---

# 4. SECURITY STANDARDS

## 4.1 Authentication

- Use existing auth patterns (see orryx-knowledge/patterns/authentication-pattern.md)
- Sessions: httpOnly, secure cookies
- Passwords: bcrypt with 10+ rounds
- MFA: Required for production access

## 4.2 Input Validation

- Validate all inputs
- Sanitize before database operations
- Use parameterized queries (prevent SQL injection)
- Validate file uploads

## 4.3 Secrets Management

**Never** commit:
- API keys
- Passwords
- Private keys
- Database credentials

**Always** use:
- Environment variables
- AWS Secrets Manager (production)

---

# 5. CODE STANDARDS

## 5.1 TypeScript

- Strict mode enabled
- No `any` types (use `unknown` if needed)
- Explicit return types on functions
- Interfaces for object shapes

## 5.2 React

- Functional components only
- Hooks for state management
- Props interface defined
- Accessibility (WCAG 2.1 AA)

## 5.3 Error Handling

- Try/catch around async operations
- Meaningful error messages
- Log errors (without sensitive data)
- Return user-friendly messages

---

# 6. DEPLOYMENT RULES

## 6.1 Never Deploy Without

- [ ] All tests passing
- [ ] Security scan passing
- [ ] Human approval (production)
- [ ] Rollback plan documented

## 6.2 Deployment Stages

1. Development (auto-deploy)
2. Staging (auto-deploy after tests)
3. Production (manual approval required)

---

# 7. DOCUMENTATION REQUIREMENTS

## 7.1 Code Comments

- Complex logic explained
- Why, not what
- External API calls documented

## 7.2 README Files

- Setup instructions
- Architecture overview
- Key patterns

## 7.3 API Documentation

- OpenAPI/Swagger for REST APIs
- GraphQL schema for GraphQL APIs

---

# 8. LEARNINGS CAPTURE

After every task, capture:
- **Patterns discovered**: Reusable implementations
- **Issues encountered**: Problems faced and solutions
- **Improvements suggested**: What could be better

Update orryx-knowledge repo with learnings.

---

# 9. HUMAN REVIEW BOUNDARIES

### AUTO (SAFE)
- Documentation
- Tests
- Refactoring (non-breaking)
- UI improvements
- Bug fixes (non-security)

### REQUIRE HUMAN REVIEW

Tag: `[REQUIRES HUMAN REVIEW]`

For:
- Clinical logic
- Patient matching/identification
- Compliance interpretation
- Privacy/consent decisions
- Production data handling
- Security changes
- Breaking changes
- Database migrations

---

# 10. FAILURE HANDLING

If blocked:
1. Clearly state blocker
2. Attempt workaround
3. Provide options
4. Continue other parallel tasks if possible

---

# 11. TONE & STYLE

- Clear > clever
- Direct > verbose
- Structured always
- No fluff
- No emojis (unless user requests)

---

# 12. DEFINITION OF DONE

A task is ONLY complete when:
- [ ] Acceptance criteria met
- [ ] Tests pass (>80% coverage)
- [ ] Security scan pass
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Learnings captured
- [ ] Ready for production OR clearly labelled otherwise

---

**PRODUCT-SPECIFIC ADDITIONS BELOW THIS LINE**
(Product repos extend this file but cannot override above)
