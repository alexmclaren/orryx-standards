---
name: career-job-scan
description: Daily swarm scan for new AI/senior product roles; updates D:\career\pipeline.md, flags exceptional matches and deadlines
---

# Daily career job scan (autonomous swarm)

You are running Alex McLaren's daily job-discovery routine. Work autonomously; Alex is not watching.

## Candidate profile (fixed)
Product Manager, Business Banking @ CBA (~decade, commercial lending tech, ~$1B remediation), MBA + M.Fin, advanced hands-on AI practitioner (multi-agent orchestration, evals, agentic workflows, ships production AI on AWS/Cloudflare). Positioning: "AI Product Manager who ships agents" — NEVER "banking Senior PM". Made redundant Jul 2026; on a deliberate break; apply track = TOP-TIER ONLY.

## Target criteria
- Roles: AI Product Manager, Senior/Lead/Principal PM, Head of AI Product, AI transformation/strategy, technical PM, fractional/contract AI product.
- Locations: Brisbane/Gold Coast preferred; remote Australia; Sydney/Melbourne acceptable at ~$180k+ base (relocation open); exceptional international flagged only.
- Comp floor: ~$150k base (Brisbane) / $180k+ (relocation) / $1,100+/day contract.
- EXCEPTIONAL (flag loudly): AI-platform/agent-PM roles $200k+, Head of AI Product roles, or anything matching his agentic/evals/multi-agent stack the way Zendesk's "Senior Principal PM AI Platform" did. Rare — most days there will be none.

## Method — model-tiered swarm
1. Read state first: D:\career\pipeline.md (current pipeline + dead ends), D:\career\company-intel.md (scores), C:\Users\alexa\.claude\projects\D--\memory\project_career_engagement_2026_07_02.md (strategy; note CAO Partners is SUNK — never resurface it).
2. Fan out 3-4 parallel Agent-tool subagents with model "haiku" for raw discovery via WebSearch (SEEK/LinkedIn/Indeed snippets + employer careers pages: Canva, Atlassian, Xero, Zendesk AU, TechnologyOne, Suncorp/ANZ Brisbane, QLD Gov smartjobs, Octopus Deploy). One subagent per source cluster. Browser tools (mcp__claude-in-chrome__*) may be used READ-ONLY if available; if not, WebSearch snippets suffice.
3. Use one "sonnet" subagent to open/verify detail on the plausible new finds (title, company, location, salary, posted/closing dates, apply URL).
4. Synthesize yourself (dedupe against pipeline.md including dead-ends section; rank by fit).

## Output (all writes stay under D:\career\ — personal data NEVER goes into any git repo)
- Append genuinely new roles to the pipeline table in D:\career\pipeline.md (status NEW, same column format).
- Write D:\career\scan-log\YYYY-MM-DD.md: 5-15 line brief — new roles found (or "nothing new"), any EXCEPTIONAL flag at the top with ⭐, deadline warnings for pipeline roles closing within 7 days, and any pipeline listings discovered to be closed/filled (mark them CLOSED in pipeline.md, don't delete).
- If an EXCEPTIONAL role is found, make it unmissable: first line of the scan log, and state why it clears the bar.

## Hard rules
- READ-ONLY on the web: never apply, never submit forms, never sign in, never message recruiters, never accept terms.
- Never modify anything outside D:\career\ (except nothing — that's the only write surface).
- Don't re-add roles listed in pipeline.md dead-ends or CLOSED rows; don't resurface CAO Partners.
- Keep total runtime lean: if searches are dry, say so in 3 lines and stop.