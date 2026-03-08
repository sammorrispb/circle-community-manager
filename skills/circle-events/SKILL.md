---
name: Circle Events
description: >-
  This skill should be used when the user asks to "create an event",
  "list events", "show RSVPs", "who RSVPed", "upcoming events",
  "past events", "add attendee", "event management", "delete event",
  "update event", or any operation involving Circle.so community events
  and attendees.
version: 1.2.0
---

# Circle.so Event Management

Create, manage, and analyze community events and attendees via the Circle Admin API v2.

## Prerequisites

Ensure `$CIRCLE_API_KEY` and `$CIRCLE_COMMUNITY_ID` are set. If not, activate the circle-setup skill first.

## Core API Endpoints

All requests use base URL `https://app.circle.so/api/admin/v2` with header `Authorization: Token $CIRCLE_API_KEY`.

### List Events (paginated)

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1"
```

Response: `{ "records": [...], "has_next_page": true|false }`

Each event record contains: `id`, `name`, `slug`, `body`, `starts_at`, `ends_at`, `location_type`, `in_person_location`, `virtual_location_url`, `duration_in_seconds`, `rsvp_disabled`, `hide_attendees`, `space` (object with `id`, `name`, `slug`), `url`, `created_at`, `likes_count`, `comments_count`, `cover_image_url`, `topics`.

### Get Single Event

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID?community_id=$CIRCLE_COMMUNITY_ID"
```

### Create Event

Circle events use a Rails nested resource pattern. The payload must:
1. Put `community_id` and `space_id` at the root level
2. Wrap event fields inside an `event` key
3. Put schedule/location in `event_setting_attributes` (singular) inside `event`
4. For in-person events, `in_person_location` must be a JSON-stringified object (not null)

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "space_id": SPACE_ID,
    "event": {
      "name": "Event Title",
      "body": "Event description text",
      "event_setting_attributes": {
        "starts_at": "2026-03-15T18:00:00.000Z",
        "ends_at": "2026-03-15T20:00:00.000Z",
        "location_type": "in_person",
        "in_person_location": "{\"formatted_address\":\"ADDRESS\",\"name\":\"VENUE NAME\"}",
        "duration_in_seconds": 7200,
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

Required fields:
- `community_id` (root) — community to create in
- `space_id` (root) — which space to post the event in (list spaces first if unknown)
- `event.name` — event title
- `event.event_setting_attributes.starts_at` — ISO 8601 datetime
- `event.event_setting_attributes.location_type` — `"in_person"`, `"virtual"`, or `"tbd"`

Required for in-person events:
- `event.event_setting_attributes.in_person_location` — JSON-stringified object with at minimum `formatted_address` and `name` keys. **Must not be null** or the API returns "Nil is not a valid JSON source."

Optional fields:
- `event.body` — plain text description (rendered as-is in Circle)
- `event.event_setting_attributes.ends_at` — ISO 8601 datetime
- `event.event_setting_attributes.duration_in_seconds` — integer
- `event.event_setting_attributes.rsvp_disabled` — boolean (default false)
- `event.event_setting_attributes.virtual_location_url` — URL string (for virtual events)

**Common in_person_location values** (Dill Dinkers):
- Rockville: `{"formatted_address":"40 Southlawn Ct, Rockville, MD 20850, USA","geometry":{"location":{"lat":39.1024421,"lng":-77.1294295}},"name":"Dill Dinkers Rockville"}`
- North Bethesda: `{"formatted_address":"4942 Boiling Brook Pkwy, North Bethesda, MD 20852, USA","name":"Dill Dinkers North Bethesda"}`

**Natural language date handling**: When the user says something like "Thursday at 6pm", convert to ISO 8601 using the current date context. Always confirm the interpreted date before creating.

### Update Event

Uses the same nested structure as create. Only include fields that need to change.

```bash
curl -s -X PUT \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "space_id": SPACE_ID,
    "event": {
      "name": "Updated Title",
      "event_setting_attributes": {
        "starts_at": "2026-03-15T19:00:00.000Z"
      }
    }
  }' \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID"
```

### Delete Event

Requires both `community_id` and `space_id` as query parameters.

```bash
curl -s -X DELETE \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID?community_id=$CIRCLE_COMMUNITY_ID&space_id=SPACE_ID"
```

Returns `{"message":"Event deleted."}` with HTTP 200 on success. **Always confirm with user before deleting.**

## Attendee Management

### List Event Attendees (paginated)

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID/event_attendees?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1"
```

### Add Attendee to Event

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
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
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/event_attendees?community_id=$CIRCLE_COMMUNITY_ID&event_id=EVENT_ID&community_member_id=MEMBER_ID"
```

## Pagination

Same pattern as members — max 100 per page:

1. Start with `page=1&per_page=100`
2. Check `has_next_page` in response
3. If `true`, increment page and repeat

For event listing, extract useful fields:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1" \
  | jq '[.records[] | {id, name, starts_at, ends_at, location_type, url, space: .space.name}]'
```

## Common Workflows

### List Upcoming Events

1. Fetch all events
2. Filter by `starts_at` > current datetime using jq:
```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
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

## Related: Posts in Event Spaces

Events in Circle live inside spaces. You can also create **posts** in event spaces (e.g., announcements, recaps, invite links). Use the circle-posts skill for post CRUD — the endpoint is `/posts` (do NOT include `community_id` for post endpoints).

Common pattern: After an event, create a post in the same space with a recap, photos, or Play Date invite links for attendees.

## DMs / Direct Messages — Not Available

The Circle Admin API v2 does **not** expose DM/chat endpoints. Tested endpoints that return 404:
- `/chat_rooms`
- `/chat_room_messages`
- `/direct_messages`
- `/messages`

For member-to-member messaging, use the Circle web UI or consider the Headless Member API (which enables member-authenticated actions but doesn't explicitly document DM creation either).

**Alternative for direct outreach**: Create a post in a space with personalized content, or use email via Circle's invitation system.

## Safety Notes

- **Always confirm before deleting events** — deletion is permanent
- **Confirm dates before creating** — echo the interpreted datetime back to the user
- **Bulk attendee operations** — add a brief pause between API calls to respect rate limits
