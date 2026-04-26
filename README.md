# Orryx Standards

Technical standards, coding conventions, and patterns for all Orryx products.

## Purpose

Central repository for:
- Master CLAUDE.md (distributed to all product repos)
- Master AGENTS.md (distributed to all product repos)
- Coding standards (TypeScript, React, Python, etc.)
- Testing standards
- Deployment standards
- Documentation standards

## Distribution

Standards are synced to product repos:
- `CLAUDE.md` → copied to pillarworks, triora, orryx, orryx-flow
- `AGENTS.md` → copied to all product repos

Product repos extend these with product-specific additions but cannot override.

## Usage

**Read by**: All product repos, all agents
**Write by**: Architecture team, founder

Changes here propagate to all products. Make changes carefully.

## Sync Process

```bash
# Run from orryx-control-plane
./scripts/standards/sync-standards.sh
```

This copies CLAUDE.md and AGENTS.md to all product repos.
