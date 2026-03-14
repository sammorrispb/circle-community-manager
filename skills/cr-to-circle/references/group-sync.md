# CR to Circle Group Sync Reference

Sync CourtReserve event categories to Circle.so spaces for community communication. Supplements the event sync in the main SKILL.md with space membership and discussion post management.

## Space Mapping

Circle spaces **cannot** be created via API — they must be pre-created manually in the Circle web UI. This reference stores the mapping from CR event categories to Circle space IDs.

### Active Space Mappings

| CR Category | Circle Space Name | Space ID | Sync Type | Lifecycle | Status |
|------------|-------------------|----------|-----------|-----------|--------|
| Competitive Events / Tournaments | Tournaments | `1916764` | Events + partner-finding posts | Per-event | ACTIVE |
| Next Gen / Kids Program | Link and Dink Events | `1718302` | Events (existing sync) | Per-event | ACTIVE |
| Next Gen Pickleball Academy | *NOT CREATED — create manually* | `TBD` | Program info + schedule | Persistent | NEEDS SPACE |
| League | *NOT CREATED — create manually* | `TBD` | Season-based membership + schedule post | New space each season | NEEDS SPACE |
| Coached Open Play | *NOT CREATED — create manually* | `TBD` | Level-based membership + schedule post | Persistent | NEEDS SPACE |

### Player Journey Event Space Groups

Events within individual spaces are organized by player journey stage. CourtReserve events are routed to these groups based on `EventCategoryName` (primary) and `EventName` keywords/skill level parsing (secondary).

| Player Journey | Circle Space Name | Space ID | Skill Level | CR Routing Keywords | Status |
|---------------|-------------------|----------|-------------|---------------------|--------|
| Newbie | Newbie Welcome Events | `TBD` | 2.0–2.5 | "beginner", "intro", "new player", "first time", level 2.0–2.5 | NEEDS SPACE |
| Advanced Beginner | Advanced Beginner Events | `TBD` | 2.5–3.0 | level 2.5–3.0 | NEEDS SPACE |
| Intermediate | Intermediate Events | `TBD` | 3.0–3.5 | level 3.0–3.5 | NEEDS SPACE |
| Int-Adv Competitive | Intermediate-Advanced Competitive Events | `TBD` | 3.5–4.0 | "competitive", level 3.5–4.0 | NEEDS SPACE |
| Advanced Elite | Advanced Elite Invite-Only Events | `TBD` | 4.0+ / 4.5+ | "elite", "invite", "invite-only", level 4.0+, 4.5+ | NEEDS SPACE |
| Public | Public Events | `TBD` | Any / None | "social", no level specified, multi-level, tournaments spanning multiple groups | NEEDS SPACE |

**IMPORTANT**: All player journey spaces, plus Leagues, Coached Open Play, and Next Gen Academy spaces do NOT exist yet in Circle. Before running group sync for these categories, Sam must:
1. Create the space(s) in the Circle web UI
2. Copy the space ID from the URL or use the API lookup below
3. Update this mapping table with the real space ID

**To add a new space**: Create it in Circle web UI → copy the space ID from the URL → update the mapping above.

### How to Find Circle Space IDs

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/spaces?community_id=$CIRCLE_COMMUNITY_ID&per_page=100" \
  | jq '[.records[] | {id, name, slug}]'
```

## Sync Categories

### 1. Leagues → Season-Based Spaces

**CR filter**: `EventCategoryName` starts with "League" (mapped to `league` by `mapCrCategoryToType`)

**Workflow**:
1. Fetch CR league events for the target date range
2. Group by season using `parseSeasonLabel()` (e.g., "Spring 2026 Leagues")
3. Look up the Circle space ID for that season from the mapping above
4. For each registered player:
   a. Find them in Circle by email (via `/community_members/search`)
   b. Add them to the season's league space (via `/space_members`)
5. Create/update a pinned schedule post in the space with the full league calendar

**Season detection**:
```bash
# parseSeasonLabel extracts "Spring 2026" from event names like "Spring 2026 Monday Night League"
SEASON=$(echo "$EVENT_NAME" | grep -oiP '(spring|summer|fall|winter)\s+\d{4}' | head -1)
```

**Schedule post template**:
```
📅 [Season] League Schedule — [Location]

[For each league event, sorted by date:]
• [Day of Week], [Month Day] — [Start Time]-[End Time] ET
  [Event Name]
  Registered: [count]/[max] | [PublicEventUrl]

---
Updated automatically from CourtReserve.
Questions? Email sam@linkanddink.com
```

### 2. Tournaments → Partner-Finding Posts

**CR filter**: Already handled by existing sync (`EventCategoryName` contains "Competitive Events" or "Tournament")

**Extension**: After syncing the tournament event to Circle, create a discussion post in the Tournaments space for partner finding.

**Partner-finding post template**:
```
🏓 Partner Finding — [Event Name]

📍 [Location]
📅 [Day of Week], [Month Day, Year]
⏰ [Start Time] - [End Time] ET
👥 [RegisteredCount]/[MaxRegistrants] registered

Looking for a partner? Drop a comment below with:
• Your rating level
• What you're looking for in a partner
• Whether you're flexible on skill level

Register on CourtReserve: [PublicEventUrl]

---
Posted automatically from CourtReserve event sync.
```

**Circle post creation**:
```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "space_id": 1916764,
    "name": "Partner Finding — EVENT_NAME",
    "body": "POST_BODY",
    "is_comments_enabled": true,
    "is_pinned": false
  }' \
  "https://app.circle.so/api/admin/v2/posts"
```

**Dedup**: Before creating a partner-finding post, search for existing posts with the same normalized name in the space:
```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/posts?community_id=$CIRCLE_COMMUNITY_ID&space_id=1916764&per_page=50" \
  | jq '[.records[] | select(.name | ascii_downcase | contains("partner finding"))]'
```

### 3. Coached Open Play → Level-Based Spaces

**CR filter**: `EventCategoryName` starts with "Coached Open Play" (mapped to `coached_open_play` by `mapCrCategoryToType`)

**Workflow**:
1. Fetch CR coached open play events
2. Parse level from event name (e.g., "3.0-3.5", "3.5-4.0")
3. Look up Circle space ID for that level from the mapping above
4. Sync regular attendees to the space
5. Create/update a pinned schedule post with upcoming sessions

**Level detection**:
```bash
# Extract level range from event names like "Coached Open Play: 3.0-3.5"
LEVEL=$(echo "$EVENT_NAME" | grep -oP '\d+\.\d+-\d+\.\d+' | head -1)
```

**Schedule post template**:
```
📅 Coached Open Play Schedule — [Level Range]

[For each upcoming session, sorted by date:]
• [Day of Week], [Month Day] @ [Location]
  [Start Time]-[End Time] ET
  Registered: [count]/[max] | [PublicEventUrl]

---
Updated automatically from CourtReserve.
```

### 4. Player Journey Event Routing

Events from CourtReserve are routed to player journey spaces using a two-step classification: `EventCategoryName` as the primary filter, then `EventName` keyword/skill level parsing as the secondary filter.

**Routing priority** (evaluated in order — first match wins):

1. **Advanced Elite** — `EventCategoryName` or `EventName` contains "elite" or "invite-only" OR parsed level is 4.0+ or 4.5+
2. **Int-Adv Competitive** — `EventCategoryName` or `EventName` contains "competitive" (but not "Competitive Events" which routes to Tournaments) OR parsed level is 3.5–4.0
3. **Intermediate** — parsed level is 3.0–3.5
4. **Advanced Beginner** — parsed level is 2.5–3.0
5. **Newbie Welcome** — `EventCategoryName` or `EventName` contains "beginner", "intro", "new player", or "first time" OR parsed level is 2.0–2.5
6. **Public Events** — `EventName` contains "social" OR event spans multiple skill groups OR no skill level can be determined

**Level detection** (extends existing coached open play logic):

```bash
# Extract skill level range from event name
# Matches patterns like "3.0-3.5", "4.0+", "4.5+"
parse_player_journey() {
  local name="$1"
  local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  # Check keyword matches first
  if echo "$name_lower" | grep -qiE '(elite|invite.only)'; then
    echo "advanced_elite"; return
  fi
  if echo "$name_lower" | grep -qiE '(beginner|intro|new.player|first.time)'; then
    echo "newbie"; return
  fi
  if echo "$name_lower" | grep -qiE '\bsocial\b'; then
    echo "public"; return
  fi

  # Parse numeric skill level from event name
  local level_range=$(echo "$name" | grep -oP '\d+\.\d+-\d+\.\d+' | head -1)
  local level_min=$(echo "$name" | grep -oP '(\d+\.\d+)\+' | head -1 | sed 's/+//')

  if [ -n "$level_min" ]; then
    # "4.0+" or "4.5+" format
    if (( $(echo "$level_min >= 4.0" | bc -l) )); then
      echo "advanced_elite"
    elif (( $(echo "$level_min >= 3.5" | bc -l) )); then
      echo "int_adv_competitive"
    elif (( $(echo "$level_min >= 3.0" | bc -l) )); then
      echo "intermediate"
    elif (( $(echo "$level_min >= 2.5" | bc -l) )); then
      echo "advanced_beginner"
    else
      echo "newbie"
    fi
  elif [ -n "$level_range" ]; then
    # "3.0-3.5" format — use the lower bound
    local low=$(echo "$level_range" | cut -d'-' -f1)
    if (( $(echo "$low >= 4.0" | bc -l) )); then
      echo "advanced_elite"
    elif (( $(echo "$low >= 3.5" | bc -l) )); then
      echo "int_adv_competitive"
    elif (( $(echo "$low >= 3.0" | bc -l) )); then
      echo "intermediate"
    elif (( $(echo "$low >= 2.5" | bc -l) )); then
      echo "advanced_beginner"
    else
      echo "newbie"
    fi
  else
    echo "public"  # No level detected — default to public
  fi
}
```

**Journey group to space ID lookup** (update TBD values after creating spaces):

```bash
get_journey_space_id() {
  case "$1" in
    newbie)                echo "TBD" ;;  # Newbie Welcome Events
    advanced_beginner)     echo "TBD" ;;  # Advanced Beginner Events
    intermediate)          echo "TBD" ;;  # Intermediate Events
    int_adv_competitive)   echo "TBD" ;;  # Intermediate-Advanced Competitive Events
    advanced_elite)        echo "TBD" ;;  # Advanced Elite Invite-Only Events
    public)                echo "TBD" ;;  # Public Events
    *)                     echo "TBD" ;;  # Unknown — default to public
  esac
}
```

**Example routing for known CR event names**:

| CR Event Name | Detected Journey | Target Space |
|--------------|-----------------|--------------|
| Coached Open Play: 3.0-3.5 | Intermediate | Intermediate Events |
| Link & Dink Tournament: Women's Only 3.0-3.5 | Intermediate | Intermediate Events |
| Link and Dink Tournament: Mixed Doubles 3.5+ | Int-Adv Competitive | Int-Adv Competitive Events |
| DUPR Round Robin: 4.0+ | Advanced Elite | Advanced Elite Invite-Only Events |
| Beginner Clinic | Newbie | Newbie Welcome Events |
| Social Mixer | Public | Public Events |
| Link & Dink Tournament (no level) | Public | Public Events |

## Member Matching: CR → Circle

To sync CR event registrants to Circle spaces, you need to match members across systems. The only reliable cross-reference is **email**.

**Workflow**:
1. Get registrations from CR: `GET /api/v1/eventregistrationreport/listactive` → extract `Email`
2. Search Circle for each email: `GET /api/admin/v2/community_members/search?query=EMAIL`
3. If found: get `community_member_id`, add to space via `POST /api/admin/v2/space_members`
4. If not found: log as "not in Circle community" — optionally invite

```bash
# Match a CR registrant to Circle
CR_EMAIL="jane@example.com"
CIRCLE_MEMBER=$(curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members/search?community_id=$CIRCLE_COMMUNITY_ID&query=$CR_EMAIL" \
  | jq -r '.records[0].id // empty')

if [ -n "$CIRCLE_MEMBER" ]; then
  # Add to space
  curl -s -X POST \
    -H "Authorization: Token $CIRCLE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"community_id": '"$CIRCLE_COMMUNITY_ID"', "space_id": SPACE_ID, "community_member_id": '"$CIRCLE_MEMBER"'}' \
    "https://app.circle.so/api/admin/v2/space_members"
else
  echo "Not found in Circle: $CR_EMAIL"
fi
```

## Bulk Sync Strategy

1. **Fetch all CR events** for the target category and date range
2. **Group events** by the appropriate dimension (season for leagues, level for coached open play)
3. **Fetch all registrations** for those events
4. **Deduplicate registrants** by email (a player may be registered for multiple events)
5. **Batch search Circle** — search each unique email, collect member IDs
6. **Batch add to space** — add each matched member, 1s pause between calls
7. **Report**: matched count, not-in-Circle count, already-in-space count (409s)

## Rate Limits

- **CourtReserve**: 60 req/min per org
- **Circle**: No documented hard limit, but use 1s spacing for bulk writes
- **Post-bulk cooldown**: Circle may return 401 for several minutes after 100+ writes

## Safety Notes

- **Space membership is additive** — adding a member who's already in the space returns 409 (harmless)
- **Never remove members automatically** — only add. Manual removal via Circle web UI.
- **Confirm before bulk operations** — show the user how many members will be added
- **Discussion posts are visible immediately** — preview content before creating
- **PII handling** — email matching happens in-session only; don't persist cross-reference data
