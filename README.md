# Orryx Standards

**Version 1.0.0 Governance Layer**

This repository contains the master standards, templates, and modules for the Orryx AI-native operating system.

## Purpose

All Orryx products MUST align to the standards defined in this repository:
- **CLAUDE.md / CLAUDE.base.md**: Execution protocol for Claude agents (canonical source — see "Single-sourcing pattern" below)
- **AGENTS.md / AGENTS.base.md**: Agent behavior rules (canonical source — see "Single-sourcing pattern" below)
- **gitignore-snippets/**: Canonical `.gitignore` patterns for secret/PII hygiene (NEW — Wave 0, 2026-05-12)
- **Templates**: Python, Node.js, and infrastructure templates
- **Terraform Modules**: Reusable AWS infrastructure components

### Single-sourcing pattern (Wave 0, 2026-05-12)

Previously, `CLAUDE.md` and `AGENTS.md` were duplicated by file-copy across 4–5 repos (orryx-brain, orryx-flow, orryx-mcp-gateway, Clinical_trials, orryx-standards). Files were byte-identical (verified by SHA-256), so drift was inevitable.

**Now (transitional state):** the canonical content lives in this repo as both `CLAUDE.md`/`AGENTS.md` (legacy filenames, still tracked) and `CLAUDE.base.md`/`AGENTS.base.md` (explicit "this is the base for downstream pointer references"). Downstream repos will be migrated to thin pointer files in a follow-up PR per repo.

**Single-source rule:** any change to shared agent/Claude behaviour goes in **`CLAUDE.base.md`** / **`AGENTS.base.md`** here. The legacy filenames are kept in sync until the downstream rollout is complete, then removed.

## Repository Structure

```
orryx-standards/
├── CLAUDE.md                      # Master execution protocol
├── AGENTS.md                      # Agent behavior rules
├── python/
│   └── pyproject.template.toml   # Python project template
├── node/
│   └── package.template.json     # Node.js project template
├── terraform/
│   └── modules/
│       ├── aws-ecs-service/      # ECS Fargate service module
│       ├── aws-rds-postgres/     # PostgreSQL RDS module
│       └── aws-s3-frontend/      # S3 + CloudFront frontend module
└── docker/
    └── Dockerfile.template       # Docker template
```

## Integration with Products

### Option 1: Git Submodule (Recommended)

Add orryx-standards as a submodule to your product repo:

```bash
cd /path/to/your/product
git submodule add https://github.com/alexmclaren/orryx-standards.git .orryx-standards
git submodule update --init --recursive
```

### Option 2: Manual Sync

Copy templates manually and sync weekly.

## Standards Enforcement

All products MUST:
1. **Follow CLAUDE.md** execution protocol
2. **Follow AGENTS.md** agent behavior rules
3. **Use Python 3.11+** for backend
4. **Use React 18 + TypeScript 5** for frontend
5. **Use PostgreSQL 15.10** for database
6. **Use Terraform modules** for AWS infrastructure
7. **Maintain >80% test coverage**
8. **Pass all governance gates** before deployment

## Tech Stack Standards

### Backend
- **Language**: Python 3.11+
- **Framework**: FastAPI 0.109.0+
- **ORM**: SQLAlchemy 2.0+
- **Database**: PostgreSQL 15.10
- **Testing**: pytest, >80% coverage
- **Error Handling**: error-core-python (RFC 7807)

### Frontend
- **Language**: TypeScript 5.x
- **Framework**: React 18.2.x
- **Build Tool**: Vite 5.x (or Next.js 14 for SSR)
- **Styling**: TailwindCSS 3.x
- **Testing**: Vitest

### Infrastructure
- **Platform**: AWS
- **Compute**: ECS Fargate
- **Database**: RDS PostgreSQL 15.10 (Multi-AZ)
- **Storage**: S3
- **CDN**: CloudFront
- **IaC**: Terraform
- **Monitoring**: CloudWatch + Sentry + Prometheus

## Deprecated Technologies

❌ **Do NOT use**:
- Node.js/Express for new backend services (use FastAPI)
- React 19 (use React 18 for stability)
- Railway (use AWS)
- Hardcoded secrets (use AWS Secrets Manager)

## Quality Gates

All products MUST pass before deployment:
- ✅ Lint: 0 errors
- ✅ Type check: 0 errors
- ✅ Tests: 100% passing, >80% coverage
- ✅ Security scan: 0 high/critical vulnerabilities (Trivy)
- ✅ Secrets scan: 0 secrets detected (truffleHog)
- ✅ Cost estimate: Under budget threshold (Infracost)

## Terraform Module Usage

### Example: ECS Service

```hcl
module "api_service" {
  source = "github.com/alexmclaren/orryx-standards//terraform/modules/aws-ecs-service"

  service_name       = "pillarworks-api"
  environment        = "production"
  region             = "us-east-1"
  cluster_id         = aws_ecs_cluster.main.id
  cluster_name       = aws_ecs_cluster.main.name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  image_uri          = "${aws_ecr_repository.api.repository_url}:latest"
  cpu                = 1024
  memory             = 2048

  environment_variables = {
    DATABASE_URL = module.database.connection_string
    LOG_LEVEL    = "info"
  }

  secrets = {
    JWT_SECRET = aws_secretsmanager_secret.jwt.arn
  }

  tags = {
    Product = "pillarworks"
  }
}
```

### Example: RDS PostgreSQL

```hcl
module "database" {
  source = "github.com/alexmclaren/orryx-standards//terraform/modules/aws-rds-postgres"

  db_name                = "pillarworks"
  environment            = "production"
  region                 = "us-east-1"
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  instance_class         = "db.t3.small"
  allocated_storage      = 20
  multi_az               = true
  deletion_protection    = true

  allowed_security_group_ids = [module.api_service.security_group_id]

  tags = {
    Product = "pillarworks"
  }
}
```

## Compliance

### Healthcare Products (Triora, Orryx Flow)
- **Data Residency**: ap-southeast-2 (Sydney, Australia) ONLY
- **Compliance**: Australian Privacy Act 1988, TGA Guidance
- **PHI Handling**: Encryption at rest (KMS), in transit (TLS 1.3)
- **Audit Logs**: 10-year retention

### Construction Products (PillarWorks)
- **Data Residency**: us-east-1 (no restrictions)
- **Retention**: 7 years (Australian tax law)

## Updates

This repository is the source of truth. All products MUST sync weekly via:
- Automated GitHub Actions (recommended)
- Manual sync (weekly schedule)

## Support

Questions or clarifications?
- **Issues**: github.com/alexmclaren/orryx-standards/issues
- **Email**: engineering@orryx.dev

---

**Maintained by**: Orryx Engineering
**Last Updated**: 2026-04-27
**Version**: 1.0.0
