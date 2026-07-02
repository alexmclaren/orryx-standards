---
name: vault-competitive-intel-refresh
description: Quarterly refresh of competitor/market research notes in the Obsidian vault for Alex's active ventures
---

Quarterly competitive-intelligence refresh for Alex McLaren's Obsidian knowledge vault.

OBJECTIVE: Keep the competitor + market research notes for the active ventures current. Append a dated delta to each — never rewrite history.

VENTURES (active, AU-first lens): Orryx (AI consultancy→platform), Triora (clinical/PHI platform), Pillarworks (AI construction Bill-of-Quantities automation), Orryx Flow (clinical workflow app).

FILES TO UPDATE (in place — they already exist):
- D:\Vault\main\00-Personal\Research\Research-Competitors-orryx.md
- D:\Vault\main\00-Personal\Research\Research-Competitors-triora.md
- D:\Vault\main\00-Personal\Research\Research-Competitors-Pillarworks.md
- D:\Vault\main\00-Personal\Research\Research-Competitors-Flow.md
- and the market-context notes: Research-Orryx.md, Research-Triora.md, Research-Pillarworks.md (same folder)

STEPS per venture:
1. Read the existing note first (note its current competitor list + last refresh date).
2. Use web search (AU-first, then global) to find: new entrants, pricing changes, funding rounds/M&A, positioning shifts, and any newly-visible weaknesses among named competitors since the last refresh.
3. UPDATE the note: bump the `updated:` frontmatter date to today (ISO). Add a new section "## Refresh {today ISO date}" summarising ONLY what changed since last quarter (deltas). Do NOT rewrite or delete the existing body/history. Add any new source URLs to the ## Sources section. Every new claim must carry a citation URL inline.
4. Preserve the vault schema (D:\Vault\main\00-Personal\_SCHEMA.md): `uid` is IMMUTABLE — never change it; keep the typed `related:` block intact; keep status/type/domain as-is.

CONSTRAINTS:
- NEVER edit anything under D:\Vault\main\10-Operator-Memory or D:\Vault\main\20-Fleet (those are read-only junctions to other systems).
- Do NOT refresh the canon reference notes (Reference-AU-Clinical-Regulatory, Reference-CF-AWS-AI-Stack, Reference-AI-Pricing-and-GTM) on this timer — they are stable and refresh on-demand only.
- If a venture's status has clearly changed (e.g. paused/killed), note it in the delta but do not restructure.
- No fabrication: if nothing material changed for a venture this quarter, write "## Refresh {date} — no material change" and move on. Honesty over filler.

OUTPUT: A short summary per venture of what changed (new competitors / pricing moves / funding / nothing-material), and confirm which note files were updated.