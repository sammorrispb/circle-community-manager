---
name: Hub Agent Bridge
description: >-
  This skill should be used when the user asks to "check Hub agent",
  "Hub insights", "agent suggestions", "trigger Hub action", "fill event
  spots", "run matching", "Hub agent status", "engagement scores",
  "at-risk members", or any operation that interfaces with The Hub's
  AI Agent system.
version: 1.0.0
---

# Hub AI Agent Bridge

Surface Hub AI Agent insights and trigger agent actions from Claude Code conversations. The Hub's AI agent runs daily at 6am UTC, generating recommendations for event fills, invitations, and member engagement.

## Prerequisites

**Required**:
- The Hub must be deployed (production: `https://the-hub-nine.vercel.app`)
- Admin access (API calls require admin auth)

**Optional** (for acting on agent suggestions):
- `CIRCLE_API_KEY` + `CIRCLE_COMMUNITY_ID` — to execute Circle actions from agent recommendations

## Hub API Base

```
https://the-hub-nine.vercel.app/api/ai-admin
```

All calls are `POST` with JSON body containing a `mode` field.

**Authentication**: Hub API endpoints require Supabase auth. For admin operations, the request must include valid Supabase session credentials. If auth is not available from the terminal, note which endpoints can be called and which need the Hub admin UI.

## Available Modes

### Query Agent History

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "agent_execute", "action": "list_recent"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"
```

### Event Fill Recommendations

The agent analyzes upcoming events and suggests fill strategies:

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "organizer_fill", "eventId": "EVENT_ID"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"
```

### Auto-Match Operations

```bash
# Queue players for matching
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "auto_match_queue"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"

# Run the matching algorithm
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "auto_match_run"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"
```

### Weekly Match

```bash
# Enroll in weekly matching
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "weekly_match_enroll"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"

# Check weekly match status
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "weekly_match_status"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"
```

### Play Date Integration

```bash
# Check Play Date sync status
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "play_date_status"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"

# Sync Play Date profiles into Hub
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "play_date_sync"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"

# Get Play Date profiles
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "play_date_profiles"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"

# Get Play Date match results
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "play_date_matches"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"

# Run Play Date matching
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "play_date_run_match"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"

# Get Play Date social graph
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "play_date_votes_graph"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"
```

### Social Vectors

```bash
# Recompute social preference vectors
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "recompute_social_vectors"}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"
```

### Log Agent Outcome

After taking action on an agent recommendation:

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"mode": "log_outcome", "actionId": "ACTION_ID", "outcome": "success|failure", "details": "..."}' \
  "https://the-hub-nine.vercel.app/api/ai-admin"
```

## Bridging Agent Suggestions to Circle Actions

When the Hub agent recommends actions that involve Circle, bridge them:

### Agent Says "Invite Player X to Event Y"

1. Get the recommendation from Hub
2. Search Circle for the player (use ecosystem-lookup skill)
3. Find or create the Circle event
4. Add the player as an attendee (use circle-events skill)
5. Log the outcome back to Hub

### Agent Says "Post in Community About Event"

1. Get the content suggestion from Hub
2. Create the post in Circle (use circle-posts skill)
3. Log the outcome back to Hub

### Agent Says "Player Completed Survey"

When the Hub identifies players who recently completed the Play Date survey:

1. Use `play_date_profiles` or `play_date_status` to get the list of recent completers
2. For each completer, search Circle by email to check membership
3. For completers who ARE Circle members:
   - Run `/circle-survey-return "SESSION_NAME"` to add a welcome-back comment on the original survey post
   - This guides them to community discovery (events, partner-finding, introductions) and prevents the survey-Circle redirect loop
4. For completers who are NOT Circle members:
   - Note as potential Circle invite candidates
   - Optionally invite to Circle (use circle-members skill) — let the user decide
5. Log the outcome back to Hub

### Agent Says "Fill Low-Capacity Event"

1. Get the fill recommendations from Hub
2. For each suggested player, invite to Circle event (use circle-events skill)
3. Optionally post in the event's space
4. Log outcomes back to Hub

## Presentation

When showing agent data, format as:

```
Hub Agent Status
════════════════════════════════
Last Run:     [timestamp]
Status:       [success/error]
────────────────────────────────
Recommendations:
  1. [action type]: [description]
     Confidence: [score]
     Target: [player/event]

  2. [action type]: [description]
     ...
────────────────────────────────
Actions Available:
  - organizer_fill: Fill event spots with AI recommendations
  - auto_match_run: Run the auto-matching algorithm
  - play_date_sync: Sync Play Date profiles
  - recompute_social_vectors: Refresh social preference data
```

## Authentication Note

The Hub API requires Supabase JWT authentication for most endpoints. When calling from the terminal:

1. **If Supabase access token is available**: Include as `Authorization: Bearer TOKEN`
2. **If not available**: Note which actions require the Hub admin UI and offer to:
   - Open the Hub admin URL for the user
   - Provide the curl command template for when they have a token
   - Suggest using the Hub's admin panel directly

Most read-only status checks may work without auth. Write operations (fill, match, sync) require admin auth.

## Error Handling

| Error | Recovery |
|-------|----------|
| 401 Unauthorized | Need Supabase auth token — guide user to Hub admin UI |
| 404 Not Found | Hub may not be deployed or endpoint changed — check deployment |
| 500 Server Error | Check Hub logs via Vercel dashboard |
| Network error | Hub may be cold-starting — retry after 5s |

## Related Skills

- **circle-events** — Creating events and managing attendees
- **circle-posts** — Posting agent recommendations to community
- **circle-members** — Inviting members suggested by the agent
- **ecosystem-lookup** — Looking up players the agent references
- **ecosystem-health** — Overall system health context
