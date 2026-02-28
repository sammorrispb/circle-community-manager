---
description: Quick Circle.so member operations — list, search, invite, space management
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Read
argument-hint: [action] [details...]
---

Perform Circle.so member operations. Use the circle-members skill for API endpoint patterns and curl templates.

First, validate that `$CIRCLE_API_KEY` and `$CIRCLE_COMMUNITY_ID` environment variables are set. If either is missing, activate the circle-setup skill to guide configuration.

Interpret the user's request from the arguments: $ARGUMENTS

Common actions to recognize:
- **list** / **all** — List all community members (paginate if needed)
- **search [query]** — Search members by name or email
- **invite [email]** — Invite a new member (optionally to specific spaces)
- **info [name/email]** — Show details about a specific member
- **spaces [name/email]** — Show which spaces a member belongs to
- **add-to-space [name/email] [space]** — Add a member to a space
- **remove-from-space [name/email] [space]** — Remove a member from a space

If no arguments provided, ask what member operation to perform.

For all API calls, use curl with the patterns from the circle-members skill. Parse responses with jq and present results in a clean, readable format (tables when listing multiple items).

Always confirm before destructive operations (remove member, ban).
