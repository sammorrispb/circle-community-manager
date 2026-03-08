---
name: Circle Posts
description: >-
  This skill should be used when the user asks to "create a post",
  "list posts", "add comment", "post in a space", "announce something",
  "publish a post", "delete post", "show comments", or any operation
  involving Circle.so community posts and comments.
version: 1.0.0
---

# Circle.so Post & Comment Management

Create, manage, and moderate posts and comments in Circle spaces via the Admin API v2.

## Prerequisites

Ensure `$CIRCLE_API_KEY` is set. If not, activate the circle-setup skill first.

**Note**: The API token is community-scoped — `community_id` is NOT required for post endpoints (unlike members/events). Including it may cause 401 errors.

## Core API Endpoints

All requests use base URL `https://app.circle.so/api/admin/v2` with header `Authorization: Token $CIRCLE_API_KEY`.

### List Posts in a Space (paginated)

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/posts?space_id=SPACE_ID&per_page=20&page=1&status=published"
```

Response: `{ "records": [...], "has_next_page": true|false, "count": N }`

Each post record contains: `id`, `name`, `slug`, `status`, `body` (object with `id`, `body` HTML string), `tiptap_body` (rich text), `url`, `space_name`, `space_id`, `user_name`, `user_email`, `comments_count`, `likes_count`, `published_at`, `created_at`, `updated_at`, `topics` (array of topic IDs).

Query parameters:
- `space_id` — required: filter to a specific space
- `status` — `"published"`, `"draft"`, or omit for all
- `per_page` — max 100
- `page` — pagination

### Get Single Post

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/posts/POST_ID"
```

Returns full post with HTML body, TipTap rich text body, mentions, embeds, engagement counts, and topics.

### Create Post

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": SPACE_ID,
    "name": "Post Title",
    "body": "<p>Post body in HTML</p>",
    "status": "published"
  }' \
  "https://app.circle.so/api/admin/v2/posts"
```

Response: `{ "message": "Post created.", "post": { ... } }`

Required fields:
- `space_id` — which space to post in (must be a space with `is_post_disabled: false`)
- `name` — post title
- `body` — HTML content

Optional fields:
- `status` — `"published"` (default) or `"draft"`
- `is_pinned` — boolean, pin to top of space
- `topic_ids` — array of topic IDs to tag the post

**Important**: Do NOT include `community_id` — the token is community-scoped and adding it may cause auth errors.

### Update Post

```bash
curl -s -X PUT \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Title",
    "body": "<p>Updated body</p>"
  }' \
  "https://app.circle.so/api/admin/v2/posts/POST_ID"
```

### Delete Post

```bash
curl -s -X DELETE \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/posts/POST_ID"
```

Returns: `{ "success": true, "message": "This post has been removed from the space." }`

**Always confirm with user before deleting.**

## Comments

### List Comments on a Post

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/comments?post_id=POST_ID&per_page=20&page=1"
```

### Create Comment

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "post_id": POST_ID,
    "body": "<p>Comment text</p>"
  }' \
  "https://app.circle.so/api/admin/v2/comments"
```

### Delete Comment

```bash
curl -s -X DELETE \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/comments/COMMENT_ID"
```

## Topics

Topics are tags that can be attached to posts. Each space can define its own set of topics.

### List Topics for a Space

Topics are returned as part of the space object when fetching spaces:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/spaces/SPACE_ID" \
  | jq '.topics'
```

Topics are returned as an array of topic IDs. Use these IDs when creating posts with `topic_ids`.

**Note**: Topic IDs are integers, not names. You must look up the space to find the available topic IDs. The Admin API v2 does not expose a standalone topics CRUD endpoint — topics are managed via the Circle web UI.

## Pagination

Same pattern as other Circle endpoints — max 100 per page:

1. Start with `page=1&per_page=20` (or up to 100)
2. Check `has_next_page` in response
3. If `true`, increment page and repeat

## Common Workflows

### Post an Announcement in a Space

1. List spaces to find the right `space_id`
2. Create a published post with the announcement content
3. Optionally pin it (`is_pinned: true`)
4. Report the post URL

### List Recent Posts with Engagement

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/posts?space_id=SPACE_ID&per_page=10&status=published" \
  | jq '[.records[] | {id, name, comments_count, likes_count, published_at}]'
```

### Post Play Date Invite Links

Create a post in a relevant space with personalized Play Date invite links for event attendees. See the circle-events skill for fetching attendees, then compose a post with invite URLs:

Format: `https://play-date-five.vercel.app/#survey-{URL_ENCODED_EMAIL}`

## community_id Behavior

Post endpoints do NOT require `community_id` — the Admin API v2 token is scoped to a single community. Other endpoints (members, events, spaces) may accept it optionally. For posts, omit it entirely.

## Error Handling

| Status | Meaning | Recovery |
|--------|---------|----------|
| 400 | Missing required field | Check name, space_id, body |
| 401 | Invalid API key or rate limited | Re-check key or wait 5-10 min; do NOT include community_id |
| 404 | Post not found | Verify post ID |
| 422 | Validation error | Check field values |
| 429 | Rate limited | Wait and retry |

## Safety Notes

- **Always confirm before deleting posts** — deletion is permanent
- **Rate limiting**: After a write (POST/PUT/DELETE), subsequent reads may return 401 for several minutes. Space out write+read operations.
- **Bulk operations** — pause 3+ seconds between API calls to respect rate limits
- **HTML in body** — the body field accepts HTML; sanitize any user-provided content

## Verified API Behavior (2026-03-08)

| Operation | Endpoint | Status |
|-----------|----------|--------|
| List posts | `GET /posts?space_id=ID` | ✅ Confirmed |
| Get post | `GET /posts/ID` | ✅ Confirmed |
| Create post | `POST /posts` | ✅ Confirmed (draft + published) |
| Delete post | `DELETE /posts/ID` | ✅ Confirmed |
| Comments | `GET/POST/DELETE /comments` | ⏳ Not yet tested (rate limited) |
