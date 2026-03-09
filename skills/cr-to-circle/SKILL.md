---
name: CR to Circle Sync
description: >-
  Use this skill for any task that connects CourtReserve and Circle.so —
  moving registrations, events, memberships, or content between the two
  platforms. Key scenarios: sync league registrants to a Circle space, create
  schedule posts or partner-finding posts in Circle for CourtReserve programs,
  push coached open play attendees into level-based Circle spaces, sync
  tournament or Next Gen events from CR to Circle. Applies whenever both
  platforms are involved or implied — e.g., "schedule post in the coached
  open play Circle space" implies pulling CourtReserve data. Domain terms:
  leagues, coached open play, Link and Dink, Dill Dinkers, tournaments,
  Circle spaces, partner-finding. Do NOT use for Circle-only tasks (manual
  event creation, member removal, lookups) or CourtReserve-only tasks
  (searching members, viewing registrations) with no cross-platform element.
version: 2.0.0
---

# CourtReserve to Circle Sync

Sync Dill Dinkers events and groups from CourtReserve (source of truth) to Circle.so community. Supports:

- **Event sync**: Tournaments and Next Gen programs → Circle events (existing)
- **Group sync**: Leagues, coached open play, tournament partner-finding → Circle space memberships and discussion posts (new — see `references/group-sync.md`)

## Prerequisites

**CourtReserve** credentials (per location):
- `COURTRESERVE_ROCKVILLE_USERNAME`, `_PASSWORD`, `_ORG_ID` (10869)
- `COURTRESERVE_NORTHBETHESDA_USERNAME`, `_PASSWORD`, `_ORG_ID` (10483)

**Circle** credentials:
- `CIRCLE_API_KEY` (Token auth, not Bearer)
- `CIRCLE_COMMUNITY_ID`

## Category Filters

### Event Sync Categories (create Circle events)

Events are selected from CR based on these patterns (case-insensitive):

| Category | Filter Logic |
|----------|-------------|
| Tournaments | `EventCategoryName` contains "Competitive Events" or "Tournament" OR `EventName` matches "Link & Dink" or "Tournament" |
| Next Gen | `EventCategoryName` or `EventName` contains "Next Gen" or "Kids Program" |

### Group Sync Categories (sync to Circle spaces)

These categories sync registrant memberships and discussion posts to Circle spaces. See `references/group-sync.md` for full workflows, templates, and space ID mapping.

| Category | Circle Space | Sync Action | Lifecycle |
|----------|-------------|-------------|-----------|
| League | Season-based space (e.g., "Spring 2026 Leagues") | Add registrants to space + schedule post | New space each season |
| Tournament | Tournaments (`1916764`) | Partner-finding discussion post | Per-event |
| Coached Open Play | Level-based space (e.g., "Coached Open Play: 3.0-3.5") | Add attendees to space + schedule post | Persistent |

**Member matching**: CR → Circle matching uses email. Search Circle with `GET /api/admin/v2/community_members/search?query=EMAIL`, then add to space with `POST /api/admin/v2/space_members`.

**Space creation constraint**: Circle spaces cannot be created via API. Pre-create spaces manually in the Circle web UI, then store the space ID in `references/group-sync.md`.

Always exclude cancelled events (`IsCanceled == true`).

**Priority**: If an event matches both Next Gen and Tournament filters (unlikely but possible), classify it as **Next Gen** (check Next Gen first).

**Known matching event names** (confirmed 2026-03-07 run):
- Tournament: "Link and Dink Tournament: *", "DUPR Round Robin: *", "Moneyball *", "Pickleball for a Purpose: *", "ASIA Families Tournament", "Round Robin: DUPR *"
- Next Gen: "Red/Orange/Green/Yellow Ball: Next Gen Pickleball Academy (*)", "Spring Break Kids Camp (Ages 5-13)", "Next Gen PB Start of Season Party"

## CR to Circle Field Mapping

| CourtReserve Field | Circle Field | Notes |
|---|---|---|
| `EventName` | `event.name` | Use as-is; do NOT add prefixes |
| `StartDateTime` | `event_setting_attributes.starts_at` | Convert to ISO 8601 UTC if needed |
| `EndDateTime` | `event_setting_attributes.ends_at` | Convert to ISO 8601 UTC if needed |
| OrgId mapped to location | `event_setting_attributes.in_person_location` | JSON string (see below) |
| — | `event_setting_attributes.location_type` | Always `"in_person"` |
| `PublicEventUrl` | Included in `event.body` | Registration link |
| `MaxRegistrants` | Included in `event.body` | Capacity info |
| `RegisteredCount` | Included in `event.body` | Spots remaining |
| `EventCategoryName` | Determines `space_id` | See space routing |

## Circle Space Routing

| CR Category | Circle Space | Space ID |
|---|---|---|
| Competitive Events / Tournaments | Tournaments | `1916764` |
| Next Gen / Kids Program | Link and Dink Events | `1718302` |

## Location Mapping

**Rockville** (OrgId 10869):
```json
{"formatted_address":"40 Southlawn Ct, Rockville, MD 20850, USA","geometry":{"location":{"lat":39.1024421,"lng":-77.1294295}},"name":"Dill Dinkers Rockville"}
```

**North Bethesda** (OrgId 10483):
```json
{"formatted_address":"4942 Boiling Brook Pkwy, North Bethesda, MD 20852, USA","name":"Dill Dinkers North Bethesda"}
```

## Dedup Strategy

Before creating a Circle event, check if one already exists with:
1. **Normalized name match** — before comparing, normalize both names:
   - Lowercase
   - Replace `&` with `and`
   - Strip all punctuation (dashes, en-dashes, colons, commas, parentheses, apostrophes, etc.)
   - Collapse multiple spaces to single space
   - Trim leading/trailing whitespace
2. **Same start date** (compare date portion `YYYY-MM-DD` only, not exact timestamp)
3. **Same location** — extract from Circle's `in_person_location` field (see below)

The dedup key is `normalized_name|date|location`. All three must match to consider an event a duplicate.

**Why location matters**: Both Rockville and North Bethesda often have the same program on the same date (e.g., "Orange Ball: Next Gen Pickleball Academy"). Without location in the key, a bash associative array (last-write-wins) will silently drop one location's event.

If all three match, skip the event and report it as "already synced."

**Important**: During a bulk run, also track events created in the current session. After each successful Circle create, add the normalized name + date + location to the dedup set. This prevents duplicate creation when CR returns entries that would normalize to the same key.

**Normalization example**:
- "Link & Dink Tournament – Women's Only (3.0–3.5)" → `link and dink tournament womens only 3035`
- "Link and Dink Tournament: Women's ONLY 3.0-3.5" → `link and dink tournament womens only 3035`

These normalize identically — multiple syncs with different punctuation conventions WILL create duplicates if you don't dedup. See "Duplicate Detection & Cleanup" below.

### Extracting location from Circle events

Circle's `in_person_location` is a JSON string containing the venue name. Use it to determine location:

```bash
c_loc_raw=$(echo "$CIRCLE_EVENTS" | jq -r ".[$i].in_person_location // \"\"")
if echo "$c_loc_raw" | grep -qi "rockville"; then
  c_loc="rv"
elif echo "$c_loc_raw" | grep -qi "bethesda"; then
  c_loc="nb"
else
  c_loc="unknown"
fi
```

When processing CR events, derive location from which org they came from: Rockville (OrgId 10869) → `rv`, North Bethesda (OrgId 10483) → `nb`.

### Normalization in bash/jq

```bash
normalize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed "s/&/and/g" | sed "s/[^a-z0-9 ]//g" | tr -s ' ' | sed 's/^ *//;s/ *$//'
}
```

### Fetching Existing Circle Events

```bash
# Paginate through all Circle events
PAGE=1
while true; do
  RESPONSE=$(curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
    "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=$PAGE")
  # Collect records...
  HAS_NEXT=$(echo "$RESPONSE" | jq -r '.has_next_page')
  [ "$HAS_NEXT" = "true" ] || break
  PAGE=$((PAGE + 1))
done
```

## Duplicate Detection & Cleanup

Multiple sync runs or punctuation differences between CR exports can create duplicate Circle events. The telltale sign: events with `ends_at == starts_at` (broken time conversion) alongside correct versions of the same event.

### Finding duplicates

```bash
# Find all events where ends_at == starts_at (broken duplicates)
echo "$CIRCLE_RELEVANT" | jq '[.[] | select(.starts_at == .ends_at) | {id, name, starts_at, space: .space.id}]'
```

### Verifying a broken event has a correct twin

Before deleting, confirm a correct version exists at the same location and date:

```bash
# For a broken event, search for its twin by normalized name + date + location
echo "$CIRCLE_RELEVANT" | jq '[.[] | select(.starts_at[:10] == "YYYY-MM-DD") | select(.starts_at != .ends_at)]'
```

### Deleting duplicate events

Circle's DELETE endpoint requires `space_id` as a query parameter:

```bash
curl -s -X DELETE \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID?community_id=$CIRCLE_COMMUNITY_ID&space_id=SPACE_ID"
```

Without `space_id`, the API returns 404 with "Missing parameter: space_id".

**Space IDs**: Tournament = `1916764`, NextGen = `1718302`.

Add 1s spacing between deletes to avoid rate limiting.

## Description Templates

### Tournament Events

```
[EventName]

Location: [Venue Name] - [Address]
Date: [Day of Week], [Month Day, Year]
Time: [Start Time] - [End Time] ET

Entry fee and details on CourtReserve.
Capacity: [MaxRegistrants] players | [spots remaining] spots left

Register on CourtReserve:
[PublicEventUrl]

---
Hosted by Dill Dinkers and the Link & Dink community.
Questions? Email sam@linkanddink.com
```

### Next Gen / Kids Program Events

```
[EventName]

Location: [Venue Name] - [Address]
Date: [Day of Week], [Month Day, Year]
Time: [Start Time] - [End Time] ET

Youth program by Next Gen Academy.
Learn more at www.nextgenpbacademy.com

Capacity: [MaxRegistrants] players | [spots remaining] spots left

Register on CourtReserve:
[PublicEventUrl]
```

## Circle Event API Shapes

### POST (Create) — `ends_at` works in nested attributes

Uses the confirmed Rails nested resource pattern:

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "space_id": SPACE_ID,
    "event": {
      "name": "EVENT_NAME",
      "body": "EVENT_BODY",
      "event_setting_attributes": {
        "starts_at": "ISO_START",
        "ends_at": "ISO_END",
        "location_type": "in_person",
        "in_person_location": "JSON_STRING_LOCATION",
        "rsvp_disabled": false,
        "hide_attendees": false,
        "send_email_reminder": true,
        "send_in_app_notification_reminder": true,
        "send_email_confirmation": true,
        "send_in_app_notification_confirmation": true,
        "hide_location_from_non_attendees": false,
        "enable_custom_thank_you_message": false
      }
    }
  }' \
  "https://app.circle.so/api/admin/v2/events"
```

**Critical**: `in_person_location` must be a JSON-stringified object (not null), or the API returns "Nil is not a valid JSON source."

### PUT (Update) — Must use `duration_in_seconds`

Circle's Rails backend silently ignores `ends_at` inside `event_setting_attributes` on PUT updates (Rails nested attributes quirk — the field is accepted without error but discarded). Use `duration_in_seconds` instead:

```bash
curl -s -X PUT \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "space_id": SPACE_ID,
    "event": {
      "ends_at": "ISO_END",
      "event_setting_attributes": {
        "starts_at": "ISO_START",
        "duration_in_seconds": SECONDS
      }
    }
  }' \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID"
```

**Key differences from POST**:
- `duration_in_seconds` (integer) in `event_setting_attributes` — the API computes `ends_at = starts_at + duration`
- Flat `ends_at` on the `event` object is optional (belt-and-suspenders; the duration field does the real work)
- `ends_at` inside `event_setting_attributes` is silently ignored on PUT — never rely on it for updates

### DELETE — Requires `space_id` query param

```bash
curl -s -X DELETE \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID?community_id=$CIRCLE_COMMUNITY_ID&space_id=SPACE_ID"
```

Returns 200 on success. Without `space_id`, returns 404 "Missing parameter: space_id".

## CourtReserve Event List API

```bash
AUTH=$(echo -n "$USERNAME:$PASSWORD" | base64)
curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/eventcalendar/eventlist?OrgId=ORG_ID&StartDate=YYYY-MM-DD&EndDate=YYYY-MM-DD"
```

Response: `{ "Data": [...] }` — each item has `EventId`, `EventName`, `StartDateTime`, `EndDateTime`, `EventCategoryName`, `MaxRegistrants`, `RegisteredCount`, `IsCanceled`, `PublicEventUrl`.

**CR date format**: `StartDateTime` and `EndDateTime` are `M/D/YYYY H:MM:SS AM/PM` (Eastern time). Convert to ISO 8601 UTC with a two-step approach (handles EST/EDT automatically):
```bash
EPOCH=$(TZ=America/New_York date -d "$dt" +%s)
ISO_UTC=$(date -u -d "@$EPOCH" +"%Y-%m-%dT%H:%M:%S.000Z")
```
**Do NOT use** `date -d "$dt" -u` or `TZ=America/New_York date -d "$dt" -u` — on a UTC system, both treat the input as UTC, producing times shifted by 4-5 hours.

**Volume note**: A 3-month window returns ~400+ total events per location. Only ~70 per location match tournament/Next Gen filters. The rest are open play, clinics, leagues, etc.

## Bulk Sync Strategy

For large syncs (100+ events):

1. **Dry run first** — filter and dedup without creating, to verify counts
2. **1s spacing** between Circle API writes — confirmed sufficient for 139 events (zero 429s)
3. **Within-run dedup** — track events created during this run in memory so same-name/same-date events from different CR entries don't create duplicates
4. **Process by location** — Rockville first, then North Bethesda; if one fails, the other still completes
5. **Post-sync cooldown** — Circle API may return 401 "API token not found" on read requests for several minutes after bulk writes (~100+). Wait 5-10 minutes before verification reads, or verify via Circle.so web UI
6. **Log everything** — pipe output to a log file (`tee /tmp/cr_circle_sync_log.txt`) for audit trail

### Bash script notes
- Use `#!/usr/bin/env bash` (not `#!/bin/bash`)
- Do NOT use `set -u` (unbound variable errors with the dedup string)
- If writing files on Windows/WSL, fix line endings: `sed -i 's/\r$//' script.sh`
- Use `jq -Rs .` to safely escape event body/name for JSON payloads
- Use `jq -c . | jq -Rs .` for double-encoding the location JSON string

## Sync History

| Date | Range | Rockville | North Bethesda | Total | Failures |
|------|-------|-----------|---------------|-------|----------|
| 2026-03-07 | Mar 7 – May 31, 2026 | 71 (17T + 54NG) | 68 (22T + 46NG) | 139 | 0 |
| 2026-03-08 | Cleanup | — | — | 11 deleted | Broken duplicates (ends_at == starts_at) from first sync |

## Group Sync Workflows

For detailed workflows, templates, and space ID mappings, see `references/group-sync.md`.

### Quick Reference: League Sync

```bash
# 1. Fetch league events from CR
TODAY=$(date +%Y-%m-%d); END=$(date -d "+90 days" +%Y-%m-%d)
curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/eventcalendar/eventlist?OrgId=$ORG_ID&StartDate=$TODAY&EndDate=$END" \
  | jq '[.Data[] | select(.IsCanceled == false) | select(.EventCategoryName | ascii_downcase | startswith("league"))]'

# 2. Get registrations for league events
FROM="${TODAY}T00:00:00"; TO="${END}T23:59:59"
curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/eventregistrationreport/listactive?OrgId=$ORG_ID&eventDateFrom=$FROM&eventDateTo=$TO" \
  | jq '[.Data[] | select(.EventName | ascii_downcase | contains("league")) | {Email, Name: "\(.FirstName) \(.LastName)", EventName}]'

# 3. Match each registrant email → Circle member → add to space
# See references/group-sync.md for the full matching workflow
```

### Quick Reference: Tournament Partner-Finding Post

```bash
# After syncing a tournament event to Circle, create a partner-finding post
EVENT_NAME="Link and Dink Tournament: Mixed Doubles 3.5+"
BODY=$(cat <<'POSTEOF'
🏓 Partner Finding — EVENT_NAME_HERE

Looking for a partner? Drop a comment with your rating and what you're looking for.

Register on CourtReserve: EVENT_URL_HERE
POSTEOF
)
BODY_JSON=$(echo "$BODY" | jq -Rs .)

curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "space_id": 1916764,
    "name": "Partner Finding — '"$EVENT_NAME"'",
    "body": '"$BODY_JSON"',
    "is_comments_enabled": true
  }' \
  "https://app.circle.so/api/admin/v2/posts"
```

## Error Handling

| Error | Recovery |
|-------|----------|
| CR 401 | Check CourtReserve credentials — must use explicit `Authorization: Basic` header |
| Circle 401 | Check `CIRCLE_API_KEY` — use `Token` auth, not `Bearer`. Also: may be temporary after bulk writes (see cooldown note above) |
| Circle 400 | Check required fields: name, space_id, starts_at, in_person_location |
| Circle 422 | Check datetime format (must be ISO 8601), verify space_id exists |
| Circle 429 | Rate limited — pause 60s and retry once. With 1s spacing, this is rare |
| One location fails | Continue with other location, note the failure |
