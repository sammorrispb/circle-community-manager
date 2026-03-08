---
name: CR to Circle Event Sync
description: >-
  This skill should be used when the user asks to "sync CourtReserve events
  to Circle", "create Circle events from CR", "sync tournaments", "push CR
  events to Circle", "cr-to-circle", or any operation involving syncing
  events from CourtReserve to Circle.so community.
version: 1.1.0
---

# CourtReserve to Circle Event Sync

Sync Dill Dinkers events from CourtReserve (source of truth) to Circle.so community. Supports tournaments/competitive events and Next Gen programs across both locations.

## Prerequisites

**CourtReserve** credentials (per location):
- `COURTRESERVE_ROCKVILLE_USERNAME`, `_PASSWORD`, `_ORG_ID` (10869)
- `COURTRESERVE_NORTHBETHESDA_USERNAME`, `_PASSWORD`, `_ORG_ID` (10483)

**Circle** credentials:
- `CIRCLE_API_KEY` (Token auth, not Bearer)
- `CIRCLE_COMMUNITY_ID`

## Category Filters

Events are selected from CR based on these patterns (case-insensitive):

| Category | Filter Logic |
|----------|-------------|
| Tournaments | `EventCategoryName` contains "Competitive Events" or "Tournament" OR `EventName` matches "Link & Dink" or "Tournament" |
| Next Gen | `EventCategoryName` or `EventName` contains "Next Gen" or "Kids Program" |

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

If both match, skip the event and report it as "already synced."

**Important**: During a bulk run, also track events created in the current session. After each successful Circle create, add the normalized name + date to the dedup set. This prevents duplicate creation when CR returns entries that would normalize to the same key.

**Normalization example**:
- "Link & Dink Tournament – Women's Only (3.0–3.5)" → `link and dink tournament womens only 3035`
- "Link and Dink Tournament: Women's ONLY 3.0-3.5" → `link and dink tournament womens only 3035`

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

## Error Handling

| Error | Recovery |
|-------|----------|
| CR 401 | Check CourtReserve credentials — must use explicit `Authorization: Basic` header |
| Circle 401 | Check `CIRCLE_API_KEY` — use `Token` auth, not `Bearer`. Also: may be temporary after bulk writes (see cooldown note above) |
| Circle 400 | Check required fields: name, space_id, starts_at, in_person_location |
| Circle 422 | Check datetime format (must be ISO 8601), verify space_id exists |
| Circle 429 | Rate limited — pause 60s and retry once. With 1s spacing, this is rare |
| One location fails | Continue with other location, note the failure |
