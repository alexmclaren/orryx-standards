# {REPO_NAME} - Tech Stack

**Last Updated:** {DATE}
**Stack Version:** {VERSION}

---

## Backend

### Language & Runtime

- **Language:** {LANGUAGE} {VERSION}
- **Runtime:** {RUNTIME} {VERSION}
- **Package Manager:** {PACKAGE_MANAGER} {VERSION}

### Framework & Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| {FRAMEWORK} | {VERSION} | Web framework |
| {ORM} | {VERSION} | Database ORM |
| {AUTH_LIB} | {VERSION} | Authentication |
| {VALIDATION_LIB} | {VERSION} | Input validation |
| {TESTING_LIB} | {VERSION} | Testing |

### Database

- **Primary:** {DATABASE} {VERSION}
- **Cache:** {CACHE} {VERSION}
- **Search:** {SEARCH_ENGINE} {VERSION} (if applicable)

---

## Frontend

### Language & Runtime

- **Language:** {LANGUAGE} {VERSION}
- **Runtime:** {RUNTIME} {VERSION}
- **Package Manager:** {PACKAGE_MANAGER} {VERSION}

### Framework & Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| {FRAMEWORK} | {VERSION} | UI framework |
| {STATE_MGMT} | {VERSION} | State management |
| {ROUTER} | {VERSION} | Routing |
| {UI_LIBRARY} | {VERSION} | Component library |
| {FORM_LIB} | {VERSION} | Form handling |
| {HTTP_CLIENT} | {VERSION} | API client |
| {TESTING_LIB} | {VERSION} | Testing |

---

## Infrastructure

### Cloud Provider

- **Provider:** {AWS | GCP | Azure}
- **Region:** {REGION}
- **Account:** {ACCOUNT_ID}

### Compute

- **App Server:** {SERVICE} ({INSTANCE_TYPE})
- **Database:** {SERVICE} ({INSTANCE_TYPE})
- **Cache:** {SERVICE} ({INSTANCE_TYPE})
- **Queue:** {SERVICE} (if applicable)

### Storage

- **Object Storage:** {SERVICE}
- **File Storage:** {SERVICE} (if applicable)
- **Backup:** {SERVICE}

### Networking

- **Load Balancer:** {SERVICE}
- **CDN:** {SERVICE}
- **DNS:** {SERVICE}

---

## External Services

### Authentication & Authorization

- **Service:** {SERVICE}
- **Protocol:** {PROTOCOL}
- **Integration:** {INTEGRATION_APPROACH}

### Payment Processing

- **Service:** {SERVICE}
- **Integration:** {INTEGRATION_APPROACH}

### Email & Notifications

- **Email:** {SERVICE}
- **SMS:** {SERVICE} (if applicable)
- **Push:** {SERVICE} (if applicable)

### Monitoring & Observability

- **APM:** {SERVICE}
- **Logs:** {SERVICE}
- **Metrics:** {SERVICE}
- **Alerts:** {SERVICE}
- **Error Tracking:** {SERVICE}

---

## Development Tools

### Code Quality

- **Linter:** {LINTER} (config: {CONFIG_FILE})
- **Formatter:** {FORMATTER} (config: {CONFIG_FILE})
- **Type Checker:** {TYPE_CHECKER} (config: {CONFIG_FILE})

### Testing

- **Unit Tests:** {FRAMEWORK}
- **Integration Tests:** {FRAMEWORK}
- **E2E Tests:** {FRAMEWORK}
- **Coverage Tool:** {TOOL}
- **Coverage Target:** {PERCENTAGE}%

### CI/CD

- **Platform:** {PLATFORM}
- **Pipeline:** {PIPELINE_FILE}
- **Deploy Target:** {TARGET}

---

## Version Constraints

### Python (if applicable)

```toml
[tool.poetry.dependencies]
python = "^{MIN_VERSION}"
{framework} = "^{MIN_VERSION}"
# ... other constraints
```

### Node.js (if applicable)

```json
{
  "engines": {
    "node": ">={MIN_VERSION}",
    "npm": ">={MIN_VERSION}"
  }
}
```

---

## Upgrade Policy

### Regular Updates

- **Patch versions:** Auto-update via Dependabot
- **Minor versions:** Review and test before merge
- **Major versions:** Requires ADR and migration plan

### Security Updates

- **Critical vulnerabilities:** Patch within 24 hours
- **High vulnerabilities:** Patch within 7 days
- **Medium vulnerabilities:** Patch within 30 days

---

## Migration Notes

### Recent Major Upgrades

#### {UPGRADE_1} ({DATE})

- **From:** {OLD_VERSION}
- **To:** {NEW_VERSION}
- **Reason:** {REASON}
- **Migration:** [Guide](docs/migrations/{MIGRATION_DOC}.md)

#### {UPGRADE_2} ({DATE})

- **From:** {OLD_VERSION}
- **To:** {NEW_VERSION}
- **Reason:** {REASON}
- **Migration:** [Guide](docs/migrations/{MIGRATION_DOC}.md)

---

## Context for Claude

**When should you read this file:**
- Before installing new dependencies
- Before making framework-specific decisions
- When debugging version conflicts
- Before proposing architectural changes

**What to pay attention to:**
- Minimum version requirements
- Deprecated libraries (don't use)
- External service integrations
- Testing framework conventions

---

**Version:** {VERSION}
**Owner:** {TEAM_NAME}
