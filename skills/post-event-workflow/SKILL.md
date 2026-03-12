---
name: Post-Event Survey Workflow
description: >-
  This skill should be used when the user asks to "run post-event survey",
  "create rating session", "generate voter links", "pairwise survey",
  "post-event workflow", "rating survey pipeline", "who would you play with again",
  "send voter links", "check survey results", "event survey status", or any
  operation involving the pairwise player rating survey after a community event.
version: 2.0.0
---

# Post-Event Pairwise Rating Survey Pipeline

End-to-end workflow: CourtReserve event registrants → pairwise rating session → voter links → distribution → results. Replaces 4-5 manual steps Sam does after every tournament/event.

## System Architecture

**Two systems involved:**
- **CourtReserve** — source of event registrants (name + email)
- **Play Date app** (`player-rating-survey-three.vercel.app`) — creates sessions, generates voter links, collects pairwise votes, computes affinity scores

**Data flow:**
```
CR Event → registrants (name + email)
  → POST /api/session {mode: "create"} → voter links (#vote-{base64url})
  → Generate session link (#session-{base64url}) for public sharing
  → Players visit links → pairwise comparisons (A/B/Equal/Skip)
     - Session link: player taps name → claim form → vote
     - Voter link: player goes straight to vote (private distribution)
  → POST /api/vote → recomputeAllPairs() + computeEventRatings()
  → player_pairs (affinity) + player_event_ratings (play-again %)
```

## Prerequisites

**Required:**
- `COURTRESERVE_ROCKVILLE_USERNAME` + `_PASSWORD` + `_ORG_ID` (and/or North Bethesda equivalents)
- `ADMIN_SECRET` — Play Date admin authentication

**Optional:**
- `CIRCLE_API_KEY` + `CIRCLE_COMMUNITY_ID` — for posting voter links to Circle

## Step 1: Find the CourtReserve Event

Query CR for recent Link & Dink events. Default to Rockville; ask user if they want North Bethesda instead.

```bash
LOC="ROCKVILLE"  # or NORTHBETHESDA
U_VAR="COURTRESERVE_${LOC}_USERNAME"
P_VAR="COURTRESERVE_${LOC}_PASSWORD"
O_VAR="COURTRESERVE_${LOC}_ORG_ID"
AUTH=$(echo -n "${!U_VAR}:${!P_VAR}" | base64)

# Look back 30 days for past events
START_DATE=$(date -d "-30 days" +%m/%d/%Y 2>/dev/null || date -v-30d +%m/%d/%Y)
END_DATE=$(date +%m/%d/%Y)

curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/eventcalendar/eventlist?OrgId=${!O_VAR}&StartDate=$START_DATE&EndDate=$END_DATE" \
  | jq '[.Data[] | select(.EventName // "" | test("link.*dink|tournament|round.?robin|dupr|mixer|social"; "i")) | {EventId, EventName, StartDateTime, EndDateTime, MaxRegistrants}]'
```

**Note:** CR API responses wrap results in `.Data[]` (not top-level array). Event fields are `EventId`, `EventName`, `StartDateTime`, `EndDateTime` (not `Id`, `Name`, `StartDate`).

Present matching events and ask the user to confirm which one. If no match, widen search or try different keywords.

## Step 2: Get Event Registrants

Fetch active registrations for the event's date range:

```bash
# Use the event's StartDateTime from Step 1, formatted as MM/DD/YYYY
EVENT_DATE_FROM="MM/DD/YYYY"  # event start date
EVENT_DATE_TO="MM/DD/YYYY"    # event end date (same day for single-day events)

curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/eventregistrationreport/listactive?OrgId=${!O_VAR}&eventDateFrom=$EVENT_DATE_FROM&eventDateTo=$EVENT_DATE_TO" \
  | jq '[.Data[] | select(.EventName | test("EVENT_NAME_PATTERN"; "i")) | {FirstName, LastName, Email, EventName}]'
```

Extract unique players: `"{FirstName} {LastName}"` and `Email` for each registrant.

**Constraints:**
- Max 12 players per session (Play Date hard limit). If more, ask user to select a subset or split into multiple sessions.
- If 0 registrants found, report it and stop.

## Step 3: Create Rating Session

Build the session name following Hub convention: `"{EventName} — {Mon Day}"` (e.g., "Link & Dink Round Robin — Mar 8").

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "create",
    "secret": "'"$ADMIN_SECRET"'",
    "sessionName": "SESSION_NAME_HERE",
    "players": ["Player One", "Player Two", "Player Three"]
  }' \
  "https://player-rating-survey-three.vercel.app/api/session"
```

**Success response** (200):
```json
{
  "ok": true,
  "links": {
    "Player One": "#vote-eyJzIj...",
    "Player Two": "#vote-eyJzIj...",
    "Player Three": "#vote-eyJzIj..."
  }
}
```

**Session already exists** (409):
```json
{ "error": "Session \"...\" already exists" }
```
→ Skip creation and proceed to Step 5 (check vote status).

**Auth error** (401): Check `ADMIN_SECRET` is set correctly.

## Step 4: Generate Links (Session + Voter)

Two link types serve different distribution needs:

### Session Link (for public sharing)

One link for everyone — players tap their name from a roster, fill a quick claim form, then vote.

```bash
# Build session link from the player list used in Step 3
SESSION_PAYLOAD=$(echo -n '{"s":"SESSION_NAME_HERE","p":["Player One","Player Two","Player Three"]}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
SESSION_LINK="https://player-rating-survey-three.vercel.app/#session-${SESSION_PAYLOAD}"
```

**Use for:** Circle posts, group chats, any public/semi-public channel where you don't control who sees the link.

### Voter Links (personalized, for private distribution)

Prepend the base URL to each hash fragment from the Step 3 response:

```
https://player-rating-survey-three.vercel.app/{hash_fragment}
```

**Use for:** Direct email, text, or DM — each player gets their own link and skips the roster/claim step.

### Present Both

```
Session Link (shareable):
https://player-rating-survey-three.vercel.app/#session-eyJzIj...

Voter Links (personalized):
| Player Name    | Email              | Voter Link |
|----------------|--------------------|------------|
| Player One     | player1@email.com  | https://player-rating-survey-three.vercel.app/#vote-eyJz... |
| Player Two     | player2@email.com  | https://player-rating-survey-three.vercel.app/#vote-eyJz... |
```

## Step 5: Check Who Has Already Voted

For each player, check submission status:

```bash
# URL-encode session name and voter name (spaces → %20, etc.)
curl -s "https://player-rating-survey-three.vercel.app/api/vote?session=SESSION_NAME_URL_ENCODED&voter=VOTER_NAME_URL_ENCODED"
```

**Response:** `{ "submitted": true }` or `{ "submitted": false }`

Present a status summary:

```
Vote Status — "Session Name"
════════════════════════════
Voted:    Player One, Player Three
Pending:  Player Two, Player Four (2 remaining)
```

## Step 6: Distribute Links

**Option A — Public post (Circle, group chat, social):**

Use the **session link** from Step 4. One link, no personalized URLs exposed.

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": SPACE_ID,
    "name": "Rate Your Experience — SESSION_NAME",
    "body": "<h2>Rate Your Playing Partners</h2><p>Thanks for attending <strong>EVENT_NAME</strong>! Help us match you with great partners.</p><p>Click the link below, find your name, and complete the 2-minute survey:</p><p><a href=\"SESSION_LINK_HERE\">Start the Survey</a></p><p><em>Player Rating Survey by Link &amp; Dink</em></p>",
    "status": "published"
  }' \
  "https://app.circle.so/api/admin/v2/posts"
```

**Why session link?** Individual voter links in a public post let anyone click someone else's link and vote as them. The session link requires players to identify themselves via a claim form — no impersonation possible.

**Important:** Do NOT include `community_id` in post creation — it causes 401 errors.

Always preview the post and get user confirmation before publishing.

**Option B — Private distribution (email, text, DM):**

Use the **voter links** from Step 4. Each player gets their own personalized link directly — faster UX since they skip the roster and claim form.

Only include players who HAVEN'T voted yet (check Step 5).

Present pending voter links as a table the user can copy for individual distribution.

## Step 7: Monitor & Verify Results

After votes come in, check results:

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "results",
    "secret": "'"$ADMIN_SECRET"'",
    "sessionName": "SESSION_NAME_HERE"
  }' \
  "https://player-rating-survey-three.vercel.app/api/session"
```

Response includes:
- `voters[]` — list of players who have submitted
- `scores` — per-player: `chosen` count, `appearances` count, `play_again_pct` (%)
- `rankings` — sorted by play-again %

Present a results summary:

```
Results — "Session Name"
════════════════════════
Voters:  4/6 submitted

Rankings:
  1. Player One — 85% play-again
  2. Player Three — 72% play-again
  3. Player Two — 68% play-again
  ...
```

Results are auto-computed on each vote submission — no manual trigger needed.

## Step 8: Data Destinations

After votes are submitted, data flows to these tables (in Play Date's Supabase):

| Table | What it holds |
|-------|---------------|
| `rating_responses` | Raw pairwise votes per voter (session_name, voter, votes jsonb) |
| `player_pairs` | Aggregated affinity scores per player pair (mutual affinity, asymmetry) |
| `player_event_ratings` | Per-event play-again % for each player |

**Hub sync:** Data syncs to The Hub's Supabase via `play_date_sync` mode in `api/ai-admin.js`.

## Step 9: Circle Community Discovery (Return Path)

After voting closes, guide completers back to the Circle community. This step prevents the survey-Circle loop by providing a clear exit from the survey flow into meaningful community engagement.

**When to run:** After most voters have submitted (check Step 5). This step is optional but recommended — skip it only if the event was CR-only with no Circle presence.

### Find the Original Survey Post

If a survey link was posted to Circle in Step 6 (Option A), locate that post:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/posts?space_id=SPACE_ID&per_page=20&page=1&status=published" \
  | jq '[.records[] | select(.name | test("SESSION_NAME_PATTERN"; "i")) | {id, name, space_id}]'
```

If no Circle post was created (Step 6 Option B was used), skip this step.

### Add Welcome-Back Comment

For voters who completed the survey and are Circle members, add a comment on the original survey post:

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "post_id": POST_ID,
    "body": "<p><strong>Survey complete — welcome to Link &amp; Dink!</strong></p><p>Thanks to everyone who rated their playing partners! Your responses help us build better groups and match you with great partners for future events.</p><p><strong>What to explore next:</strong></p><ul><li>Check out <strong>upcoming events</strong> in this space</li><li>Browse <strong>partner-finding posts</strong> in the Tournaments space to connect with players at your level</li><li>Reply here and <strong>introduce yourself</strong> — share your skill level and what you enjoy playing!</li></ul><p>You'\''ll start seeing personalized match suggestions based on your survey responses soon.</p>"
  }' \
  "https://app.circle.so/api/admin/v2/comments"
```

Do NOT include `community_id` in comment creation. Do NOT include any Play Date survey links — this is the exit from the survey flow.

### Note Non-Circle Voters

If any voters completed the survey but are not Circle members, report them as potential Circle invite candidates. Do not auto-invite — let the user decide.

Use the `circle-survey-return` command for the full workflow: `/circle-survey-return "SESSION_NAME" POST_ID`

## Variations

### Quick Session (Skip CR Lookup)

If the user already has a player list (not from CR), skip Steps 1-2 and jump directly to Step 3 with the provided names.

### Check Status Only

If a session already exists and the user just wants status, run Steps 5 and 7 only.

### Re-send Links

If a session exists and the user wants to nudge non-voters, run Step 5 to find pending voters, then Step 6 with only their links.

### Return to Circle

If voting is mostly complete and a Circle survey post exists, run Step 9 to add a welcome-back comment guiding completers to community discovery. Use `/circle-survey-return "SESSION_NAME"` or `/post-event-survey return "SESSION_NAME"`.

## Error Handling

| Error | Recovery |
|-------|----------|
| No CR events found | Widen date range or try different search terms |
| 0 registrants for event | Check event name filter; the date range may not match |
| >12 registrants | Ask user to select a subset or split into multiple sessions |
| 409 session exists | Skip creation, proceed to check status (Step 5) |
| 401 on session create | Verify `ADMIN_SECRET` is set correctly |
| Empty vote check response | Player name may have special characters — check URL encoding |
| Circle post 401 | Remove `community_id` from the request body |

## Related Skills

- **cr-events** — CourtReserve event registration endpoint details
- **cr-recruit** — Find CR attendees who haven't taken surveys
- **circle-posts** — Circle post creation API patterns
- **ecosystem-lookup** — Cross-system player search
