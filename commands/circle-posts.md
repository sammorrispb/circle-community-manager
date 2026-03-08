---
description: Quick Circle.so post operations — list, create, comment, manage posts in spaces
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Read
argument-hint: [action] [details...]
---

Perform Circle.so post operations. Use the circle-posts skill for API endpoint patterns and curl templates.

First, validate that `$CIRCLE_API_KEY` is set. If missing, activate the circle-setup skill to guide configuration.

Interpret the user's request from the arguments: $ARGUMENTS

Common actions to recognize:
- **list [space]** — List recent posts in a space
- **create [title] in [space]** — Create a new post
- **get [post id]** — Get a specific post
- **comment [text] on [post id]** — Add a comment to a post
- **delete [post id]** — Delete a post (requires confirmation)
- **announce [message] in [space]** — Create and pin an announcement post

If no arguments provided, list spaces and ask which space to view posts for.

**Important**: Post endpoints use `/posts` (not `/comments/posts`). Do NOT include `community_id` — the token is community-scoped.

For all API calls, use curl with the patterns from the circle-posts skill. Parse responses with jq and present results in clean, readable format.

Always confirm before deleting posts.
