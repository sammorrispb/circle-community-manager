---
description: Community health snapshot — member count, spaces, recent events, engagement pulse
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Read
---

Generate a Circle.so community health snapshot. Use the circle-setup, circle-members, and circle-events skills for API patterns.

First, validate that `$CIRCLE_API_KEY` and `$CIRCLE_COMMUNITY_ID` environment variables are set. If either is missing, activate the circle-setup skill to guide configuration.

Gather the following data points via Circle Admin API v2 curl calls:

1. **Spaces**: Fetch all spaces, count them, list names
2. **Members**: Fetch first page of members to assess community size (check has_next_page for "100+" indicator)
3. **Recent Events**: Fetch events, separate into upcoming vs past (last 30 days)
4. **Recent Members**: Note any members with recent `created_at` dates (new joins)

Present results as a clean community health report:

```
Community Health Snapshot
═════════════════════════
Spaces:          [count] ([list of names])
Members:         [count or 100+]
Upcoming Events: [count] ([next event name + date])
Past 30 Days:    [count] events held
New Members:     [count] joined recently
```

If any API call fails, report the specific error and continue with remaining data points. A partial report is better than no report.
