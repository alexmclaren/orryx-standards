# Shared prompt fragments

Versioned, reusable prompt fragments referenced by `commands/*.md`, repo
`CLAUDE.md` overrides, and scheduled routines. **Single-source rule:** each
fragment restates a section that already lives canonically in `CLAUDE.base.md`
(cited inline). If the canonical section changes, update the fragment here and
re-propagate — do not let copies drift.

| Fragment | Purpose | Canonical source |
|---|---|---|
| `reality-check.md` | Preamble that forces verification over assumption | `CLAUDE.base.md §0.4` |
| `acceptance-criteria.md` | Scaffold for defining + verifying DONE | `CLAUDE.base.md §0.3`, §12 |
| `end-of-session.md` | End-of-session summary template | `CLAUDE.base.md §10.2` |

Reference a fragment from a command or CLAUDE.md with a relative link, e.g.
`see prompts/reality-check.md`. Keep fragments short — they are includes, not docs.
