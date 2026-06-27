<!-- fragment: reality-check | canonical: CLAUDE.base.md §0.4 -->

**Reality check (do this before trusting any plan or claim).**

Validate what ACTUALLY exists, not what is documented or assumed:
- What APIs, DB tables, and infra are really present and reachable?
- What is BROKEN vs merely PLANNED?
- What is MOCKED vs REAL?

Do **not** trust: docs, frontend assumptions, or old schemas.
**Always verify against:** the running system, logs, and live API/DB responses.

If you cannot verify a fact directly, label it as unverified rather than
asserting it.
