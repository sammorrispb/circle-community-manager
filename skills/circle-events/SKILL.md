---
name: Circle Events
description: >-
  This skill should be used when the user asks to "create an event",
  "list events", "show RSVPs", "who RSVPed", "upcoming events",
  "past events", "add attendee", "event management", "delete event",
  "update event", or any operation involving Circle.so community events
  and attendees.
version: 1.0.0
---

# Circle.so Event Management

Create, manage, and analyze community events and attendees via the Circle Admin API v2.

## Prerequisites

Ensure `$CIRCLE_API_KEY` and `$CIRCLE_COMMUNITY_ID` are set. If not, activate the circle-setup skill first.

## Core API Endpoints

All requests use base URL `https://app.circle.so/api/admin/v2` with header `Authorization: Bearer $CIRCLE_API_KEY`.

### List Events (paginated)

```bash
curl -s -H "Authorization: Bearer $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1"
```

Response: `{ "records": [...], "has_next_page": true|false }`

Each event record contains: `id`, `name`, `slug`, `description`, `starts_at`, `ends_at`, `location`, `event_type`, `space_id`, `created_at`, `rsvp_count`.

### Get Single Event

```bash
curl -s -H "Authorization: Bearer $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID?community_id=$CIRCLE_COMMUNITY_ID"
```

### Create Event

```bash
curl -s -X POST \
  -H "Authorization: Bearer $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "name": "Event Title",
    "space_id": SPACE_ID,
    "starts_at": "2026-03-15T18:00:00Z",
    "ends_at": "2026-03-15T20:00:00Z",
    "location": "Rockville Courts",
    "event_type": "in_person",
    "description": "Event description text"
  }' \
  "https://app.circle.so/api/admin/v2/events"
```

Required fields:
- `name` — event title
- `space_id` — which space to create it in (list spaces first if unknown)
- `starts_at` — ISO 8601 datetime

Optional fields:
- `ends_at` — ISO 8601 datetime
- `location` — free-text location string
- `event_type` — `"in_person"`, `"virtual"`, or `"hybrid"`
- `description` — event description (plain text or TipTap JSON)

**Natural language date handling**: When the user says something like "Thursday at 6pm", convert to ISO 8601 using the current date context. Always confirm the interpreted date before creating.

### Update Event

```bash
curl -s -X PUT \
  -H "Authorization: Bearer $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "name": "Updated Title",
    "location": "New Location"
  }' \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID"
```

Only include fields that need to change.

### Delete Event

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID?community_id=$CIRCLE_COMMUNITY_ID"
```

Returns HTTP 204 on success. **Always confirm with user before deleting.**

## Attendee Management

### List Event Attendees (paginated)

```bash
curl -s -H "Authorization: Bearer $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID/event_attendees?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1"
```

### Add Attendee to Event

```bash
curl -s -X POST \
  -H "Authorization: Bearer $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "event_id": EVENT_ID,
    "community_member_id": MEMBER_ID,
    "status": "going"
  }' \
  "https://app.circle.so/api/admin/v2/event_attendees"
```

Status values: `"going"`, `"interested"`, `"not_going"`

### Remove Attendee from Event

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/event_attendees?community_id=$CIRCLE_COMMUNITY_ID&event_id=EVENT_ID&community_member_id=MEMBER_ID"
```

## Pagination

Same pattern as members — max 100 per page:

1. Start with `page=1&per_page=100`
2. Check `has_next_page` in response
3. If `true`, increment page and repeat

For event listing, extract useful fields:

```bash
curl -s -H "Authorization: Bearer $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1" \
  | jq '[.records[] | {id, name, starts_at, ends_at, location, event_type, rsvp_count}]'
```

## Common Workflows

### List Upcoming Events

1. Fetch all events
2. Filter by `starts_at` > current datetime using jq:
```bash
curl -s -H "Authorization: Bearer $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100" \
  | jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '[.records[] | select(.starts_at > $now) | {id, name, starts_at, location}] | sort_by(.starts_at)'
```

### List Past Events

Same approach, filter where `starts_at` < now, sort descending.

### Show RSVPs for an Event

1. Find the event (by name search or list + filter)
2. Fetch attendees for that event ID
3. Present as a table: name, email, RSVP status

### Create Event from Natural Language

When the user says "Create a mixer Thursday at 6pm at Rockville":
1. Parse the date — convert to ISO 8601 (confirm with user)
2. List spaces to find the right `space_id`
3. Compose the create payload
4. Confirm details before sending
5. Create the event and report the result

### Post-Event Attendee Summary

1. Get event details
2. Fetch all attendees
3. Group by status (going, interested, not_going)
4. Present counts and names per status

### Bulk Add Attendees

When adding multiple members to an event:
1. Get the event ID
2. For each member, search by name/email to get their `community_member_id`
3. Add each as attendee with status `"going"`
4. Brief pause between calls to avoid rate limiting
5. Report successes and failures

## Error Handling

| Status | Meaning | Recovery |
|--------|---------|----------|
| 400 | Missing required field | Check name, space_id, starts_at |
| 401 | Invalid API key | Re-check CIRCLE_API_KEY |
| 404 | Event not found | Verify event ID |
| 409 | Duplicate attendee | Member already RSVPed |
| 422 | Validation error | Check datetime format, space_id |
| 429 | Rate limited | Wait and retry |

## Safety Notes

- **Always confirm before deleting events** — deletion is permanent
- **Confirm dates before creating** — echo the interpreted datetime back to the user
- **Bulk attendee operations** — add a brief pause between API calls to respect rate limits
