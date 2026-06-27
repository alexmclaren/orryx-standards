<!-- fragment: end-of-session | canonical: CLAUDE.base.md §10.2 -->

**End-of-session summary (mandatory at session/loop exit).**

- **Completed** — what was finished and verified.
- **Remaining** — what is left, with enough detail to resume cold.
- **Risks** — current open risks or fragilities.
- **Next steps** — the concrete next action.
- **State** — update SESSION_STATE.md (or the repo's equivalent) if present.

If the session is exiting via escalation (blocked, max iterations, or no-progress
per `CLAUDE.base.md §1.3.1`), state the specific stop condition and the partial
progress made — that surfacing is the intended outcome, not a failure.
