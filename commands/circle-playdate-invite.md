---
description: Create a Circle post with Play Date invite links for event attendees
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Bash(base64:*), Bash(python3:*), Read
argument-hint: "[event name or ID] — creates a post with personalized Play Date survey links"
---

Create a Circle post containing Play Date invite links for attendees of a specific event. Since Circle's Admin API does not support DMs, this uses a post-based approach.

## Parse Arguments

From `$ARGUMENTS`, identify the event (by name or ID).

## Step 1: Validate Environment

Check that `$CIRCLE_API_KEY` and `$CIRCLE_COMMUNITY_ID` are set.

## Step 2: Find the Event

Search for the event in Circle:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100" \
  | jq '[.records[] | select(.name | test("SEARCH_TERM"; "i")) | {id, name, starts_at, space: .space.name}]'
```

If multiple matches, ask the user to clarify.

## Step 3: Get Event Attendees

Fetch all attendees for the matched event:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events/EVENT_ID/event_attendees?community_id=$CIRCLE_COMMUNITY_ID&per_page=100"
```

For each attendee, get their email from the member record.

## Step 4: Generate Play Date Links

For each attendee email, generate the personalized Play Date URL:

```
https://play-date-five.vercel.app/#survey-{URL_ENCODED_EMAIL}
```

URL-encode the email (replace `@` with `%40`, etc.).

## Step 5: Compose the Post

Create a post in the event's space with the invite links. Use this template:

```html
<h2>🎾 Play Date Survey — Rate Your Experience!</h2>
<p>Thanks for attending <strong>{EVENT_NAME}</strong>! Help us match you with great playing partners by completing a quick Play Date survey.</p>
<p>Click your personalized link below:</p>
<ul>
{FOR EACH ATTENDEE}
  <li><strong>{NAME}</strong>: <a href="{PLAY_DATE_URL}">Take the Survey</a></li>
{END FOR}
</ul>
<p>The survey takes about 2 minutes and helps us build better groups for future events.</p>
```

## Step 6: Confirm and Create

**Always show the user the post preview before creating it.** Include:
- Target space name
- Number of attendees with links
- The post title and body preview

After user confirms, create the post:

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": SPACE_ID,
    "name": "Play Date Survey — {EVENT_NAME}",
    "body": "HTML_BODY_HERE",
    "status": "published"
  }' \
  "https://app.circle.so/api/admin/v2/posts"
```

## Step 7: Report

Show the created post URL and attendee count.

## Alternative: Generate Links Only

If the user just wants the links without creating a post (e.g., to send via email or other channels), generate and display the links in a table format:

```
| Name | Email | Play Date Link |
|------|-------|----------------|
| ... | ... | https://play-date-five.vercel.app/#survey-... |
```

## Notes

- **Why posts, not DMs**: Circle's Admin API v2 does not expose DM/chat endpoints. Posts in a space are the programmatic alternative.
- **Privacy consideration**: Personalized links contain encoded emails. Consider whether attendee emails should be visible in a community post, or if a private/admin-only space is more appropriate.
- **The cr-recruit command** in the courtreserve-ops plugin already generates Play Date links from CourtReserve registrations — use that for CR-sourced events, and this command for Circle-sourced events.
