# Canonical .gitignore snippets

Single-sourced .gitignore patterns for the Orryx Group. Each `*.gitignore` file in this directory is appended to repo-local `.gitignore` files so all repos share the same secret/PII hygiene.

## Snippets

| File | Purpose | Applied to |
|---|---|---|
| `secrets.gitignore` | Secret/PII patterns (env files, terraform state, access keys, certs) | All Orryx Group repos |

## How to apply

In each repo, the local `.gitignore` should have a delimiter comment indicating the appended block from orryx-standards:

```
# =============================================================================
# Wave 0 audit additions (2026-05-12) — secret/PII hygiene
# Single-sourced via D:\orryx-standards\gitignore-snippets\secrets.gitignore
# =============================================================================
```

To re-sync: run `D:\orryx-audit\tmp\wave0-gitignore.ps1` (idempotent — skips repos already updated).

## Adding new patterns

1. Add to the snippet file in this directory.
2. Increment the date in the delimiter comment of `wave0-gitignore.ps1`.
3. Re-run the propagation script.
4. Document the addition here.

## History

- **2026-05-12 (Wave 0):** Initial snippet covering secrets, terraform state, cloud access keys, certs, failed-shell-expansion patterns, Windows OS artefacts.
