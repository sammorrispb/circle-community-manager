---
name: Circle Members
description: >-
  This skill should be used when the user asks to "list members",
  "search members", "invite someone to Circle", "add member to space",
  "remove member", "show member info", "who is in the community",
  "member management", or any operation involving Circle.so community
  members or space memberships.
version: 1.2.0
---

# Circle.so Member Management

Manage community members, invitations, and space memberships via the Circle Admin API v2.

## Prerequisites

Ensure `$CIRCLE_API_KEY` and `$CIRCLE_COMMUNITY_ID` are set. If not, activate the circle-setup skill first.

## Core API Endpoints

All requests use base URL `https://app.circle.so/api/admin/v2` with header `Authorization: Token $CIRCLE_API_KEY`.

### List Members (paginated)

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1"
```

Response: `{ "records": [...], "has_next_page": true|false }`

Each member record contains: `id`, `name`, `email`, `avatar_url`, `created_at`, `last_seen_at`, `headline`, `bio`.

### Search Members

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members/search?community_id=$CIRCLE_COMMUNITY_ID&query=SEARCH_TERM"
```

Search matches against name and email. Replace `SEARCH_TERM` with the search string (URL-encoded).

### Get Single Member

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members/MEMBER_ID?community_id=$CIRCLE_COMMUNITY_ID"
```

### Invite Member

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "email": "user@example.com",
    "name": "Display Name",
    "space_ids": [SPACE_ID_1, SPACE_ID_2]
  }' \
  "https://app.circle.so/api/admin/v2/community_members"
```

Optional fields:
- `name` — display name
- `space_ids` — array of space IDs to add them to on invite
- `skip_invitation` — set `true` to create without sending email

### Update Member

```bash
curl -s -X PUT \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "headline": "New headline"
  }' \
  "https://app.circle.so/api/admin/v2/community_members/MEMBER_ID"
```

### Remove Member

```bash
curl -s -X DELETE \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members/MEMBER_ID?community_id=$CIRCLE_COMMUNITY_ID"
```

Returns HTTP 204 on success (no body).

## Space Membership Operations

### List Spaces

Fetch all spaces to find space IDs:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/spaces?community_id=$CIRCLE_COMMUNITY_ID&per_page=100"
```

### List Members in a Space

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/space_members?community_id=$CIRCLE_COMMUNITY_ID&space_id=SPACE_ID&per_page=100&page=1"
```

### Add Member to Space

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": '"$CIRCLE_COMMUNITY_ID"',
    "space_id": SPACE_ID,
    "community_member_id": MEMBER_ID
  }' \
  "https://app.circle.so/api/admin/v2/space_members"
```

### Remove Member from Space

```bash
curl -s -X DELETE \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/space_members?community_id=$CIRCLE_COMMUNITY_ID&space_id=SPACE_ID&community_member_id=MEMBER_ID"
```

### List a Member's Spaces

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_member_spaces?community_id=$CIRCLE_COMMUNITY_ID&community_member_id=MEMBER_ID"
```

## Pagination

Circle returns max 100 records per page. To collect all records:

1. Start with `page=1&per_page=100`
2. Check `has_next_page` in response
3. If `true`, increment page and repeat
4. Collect all `records` arrays

For member listing, pipe through jq to extract useful fields:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1" \
  | jq '[.records[] | {id, name, email, created_at}]'
```

## Common Workflows

### Bulk Invite from a List

When given a list of emails (or names + emails):
1. For each person, call the invite endpoint
2. Optionally include `space_ids` to add them to specific spaces
3. Set `skip_invitation: true` if the user doesn't want emails sent
4. Report successes and failures

### Find a Member by Name or Email

1. Use the search endpoint with the query string
2. Present matching results with id, name, email
3. If no results, try partial matches or suggest checking spelling

### Show Member's Space Memberships

1. Search for the member to get their `id`
2. Call the member spaces endpoint
3. Present the list of spaces they belong to

### Move Member Between Spaces

1. Search for the member to get their `id`
2. List spaces to get source and destination space IDs
3. Remove from source space
4. Add to destination space

## Error Handling

| Status | Meaning | Recovery |
|--------|---------|----------|
| 400 | Bad request (missing field) | Check required fields |
| 401 | Invalid API key | Re-check CIRCLE_API_KEY |
| 404 | Member or space not found | Verify IDs |
| 409 | Duplicate (member already exists) | Search for existing member |
| 422 | Validation error | Check field values |
| 429 | Rate limited | Wait and retry |

## Bulk Space Membership

To add multiple members to a space at once (e.g., after importing from CourtReserve):

1. Fetch the target space ID from `/spaces`
2. For each member, call `POST /space_members` with their `community_member_id`
3. Pause briefly (~1s) between calls to respect rate limits
4. Track successes, already-in-space (409), and failures

```bash
# Example: Add members 123, 456, 789 to space 1718302
for MID in 123 456 789; do
  curl -s -X POST \
    -H "Authorization: Token $CIRCLE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"community_id": '"$CIRCLE_COMMUNITY_ID"', "space_id": 1718302, "community_member_id": '"$MID"'}' \
    "https://app.circle.so/api/admin/v2/space_members"
  sleep 1
done
```

## Headless Member API

Circle offers a **Headless API** for member-impersonated actions — useful for building custom member experiences outside the Circle web app.

**Auth flow:**
1. Generate a member JWT via `POST /api/v1/headless/auth_token` (requires the admin API key as Bearer token)
2. Use the JWT for member-scoped API calls

```bash
# Generate JWT for a member by email
curl -s -X POST \
  -H "Authorization: Bearer $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email": "member@example.com"}' \
  "https://app.circle.so/api/v1/headless/auth_token"
```

Response includes `access_token` (JWT), `refresh_token`, and expiration timestamps.

**Use cases**: Building custom member portals, SSO integration, member-facing apps that read/write Circle data on behalf of members.

**Limitations**: Headless API requires an eligible Circle plan. If your community isn't eligible, the endpoint returns 403: "Your community isn't eligible for headless API access."

**Note**: The Headless API does NOT support DM/chat operations — it covers posts, comments, events, and notifications only.

## Safety Notes

- **Always confirm before removing members** — removal is reversible only by re-inviting
- **Ban and permanent delete are destructive** — ban endpoint: `PUT /community_members/{id}/ban_member`; permanent delete: `PUT /community_members/{id}/delete_member`. Always ask for explicit confirmation before these operations.
- **Bulk operations** — pause briefly between API calls to avoid rate limiting
