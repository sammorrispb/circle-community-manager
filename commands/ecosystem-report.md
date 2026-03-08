---
description: Daily ecosystem briefing — Circle, CourtReserve, and Play Date health at a glance
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Bash(base64:*), Read
---

Generate a daily ecosystem briefing across all connected systems. Use the ecosystem-health skill for API patterns and dashboard format.

First, check which environment variables are set to determine which systems to include:
- `CIRCLE_API_KEY` + `CIRCLE_COMMUNITY_ID` → Circle
- `COURTRESERVE_ROCKVILLE_USERNAME` → CR Rockville
- `COURTRESERVE_NORTHBETHESDA_USERNAME` → CR North Bethesda

Gather data from all available systems, then present a concise daily briefing:

```
Daily Ecosystem Report — [DATE]
══════════════════════════════════════

Circle: [member count] members | [n] upcoming events | [n] posts (7d)
CR RV:  [n] reservations today | [n] events (14d)
CR NB:  [n] reservations today | [n] events (14d)

Quick Stats:
  Next event: [name] on [date]
  New members (7d): [count]
  Active spaces: [list of spaces with recent activity]

Health: [All Systems OK / Issues Detected]
══════════════════════════════════════
```

If any API call fails, note the failure and continue with remaining systems. A partial report is always better than no report.

For the full detailed dashboard, recommend the ecosystem-health skill.
