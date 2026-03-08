---
name: Circle Setup
description: >-
  This skill should be used when the user asks to "connect to Circle",
  "test Circle connection", "set up Circle", "check Circle API",
  "configure Circle", or when any Circle operation is attempted for the
  first time in a session. Validates environment variables and tests
  API connectivity.
version: 1.0.0
---

# Circle.so Connection Setup

Validate the Circle.so API environment and test connectivity before performing any community operations.

## Environment Requirements

Two environment variables must be set in the shell:

| Variable | Purpose |
|----------|---------|
| `CIRCLE_API_KEY` | Token for Circle Admin API v2 |
| `CIRCLE_COMMUNITY_ID` | Numeric community ID |

## Validation Procedure

### Step 1: Check Environment Variables

Run this validation:

```bash
if [ -z "$CIRCLE_API_KEY" ]; then echo "MISSING: CIRCLE_API_KEY"; else echo "OK: CIRCLE_API_KEY is set (${#CIRCLE_API_KEY} chars)"; fi
if [ -z "$CIRCLE_COMMUNITY_ID" ]; then echo "MISSING: CIRCLE_COMMUNITY_ID"; else echo "OK: CIRCLE_COMMUNITY_ID=$CIRCLE_COMMUNITY_ID"; fi
```

If either variable is missing, guide the user:

**To get CIRCLE_API_KEY:**
1. Log into Circle.so as an admin
2. Go to Settings > API (or visit `https://<community>.circle.so/settings/api`)
3. Generate a new Admin API v2 token
4. Export it: `export CIRCLE_API_KEY="your-token-here"`

**To get CIRCLE_COMMUNITY_ID:**
1. In Circle admin, the community ID appears in API responses or URL patterns
2. Alternatively, the connection test below returns it
3. Export it: `export CIRCLE_COMMUNITY_ID="12345"`

### Step 2: Test API Connection

Fetch community info to verify credentials work:

```bash
curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members?community_id=$CIRCLE_COMMUNITY_ID&per_page=1"
```

**Interpret the response:**
- **200**: Connection successful. Parse the response to report member count info.
- **401**: API key is invalid or expired. Regenerate the token.
- **403**: API key lacks admin permissions. Check the token scope.
- **404**: Community ID is incorrect. Verify the ID.
- **429**: Rate limited. Wait and retry.

### Step 3: Report Community Summary

On successful connection, fetch a community snapshot:

```bash
# Get spaces (shows community structure)
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/spaces?community_id=$CIRCLE_COMMUNITY_ID&per_page=100" | jq '{
    space_count: (.records | length),
    spaces: [.records[] | {id, name, slug}]
  }'
```

```bash
# Get member count (first page tells us total via has_next_page)
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members?community_id=$CIRCLE_COMMUNITY_ID&per_page=1" | jq '{
    has_members: (.records | length > 0),
    has_next_page: .has_next_page
  }'
```

Present results as a summary table:
- Connection status
- Number of spaces
- Space names and IDs
- Whether community has members

## Error Handling

| HTTP Status | Meaning | Action |
|-------------|---------|--------|
| 401 | Bad API key | Regenerate token in Circle settings |
| 403 | Insufficient permissions | Ensure token has admin scope |
| 404 | Bad community ID | Check community ID in Circle admin |
| 429 | Rate limited | Wait 60 seconds, retry |
| 5xx | Circle server error | Retry after a few minutes |

## API Reference

- **Base URL**: `https://app.circle.so/api/admin/v2`
- **Auth header**: `Authorization: Token $CIRCLE_API_KEY`
- **Content-Type**: `application/json` (for POST/PUT/PATCH)
- **Community scoping**: Admin API v2 tokens are community-scoped. Behavior varies by endpoint:
  - Members, Events, Spaces: accept `community_id` as optional param (works with or without)
  - Posts, Comments: do NOT include `community_id` — it causes 401 errors
  - When in doubt, omit `community_id` — the token already implies the community
- **Rate limit**: Circle enforces per-token limits. Important behaviors:
  - After bulk writes (100+ calls), reads may return 401 "API token not found" for 5-10 minutes
  - Rapid-fire requests to non-existent endpoints (e.g., probing `/chat_rooms`) can trigger token revocation
  - **Safe probing cadence**: Max 1 request every 3 seconds when testing unknown endpoints; max 3 unknown endpoints per session
  - If 401 persists after 10+ minutes on known-good endpoints, the token was likely revoked — regenerate in Circle settings
