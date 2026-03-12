---
description: Guide survey completers back to Circle community discovery via a comment on the original survey post
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Bash(python3:*), Read
argument-hint: "[session name] [post ID] — adds a welcome-back comment for voters who completed the survey"
---

Guide players who completed the Play Date pairwise rating survey back to the Circle community. Adds a comment on the original survey post to prevent the survey-Circle redirect loop.

## Parse Arguments

From `$ARGUMENTS`, identify:

- **Session name** (required) — the rating session name (e.g., "Link & Dink Round Robin — Mar 8")
- **Post ID** (optional) — the Circle post ID where the survey links were shared. If not provided, search for the post by title.

## Step 1: Validate Environment

Check that `$CIRCLE_API_KEY`, `$CIRCLE_COMMUNITY_ID`, and `$ADMIN_SECRET` are set.

## Step 2: Find the Original Survey Post

If the user provided a post ID, use it directly. Otherwise, search for the survey post:

```bash
# Search recent posts across spaces for the survey post
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/posts?space_id=SPACE_ID&per_page=20&page=1&status=published" \
  | jq '[.records[] | select(.name | test("SESSION_NAME_PATTERN"; "i")) | {id, name, space_id, created_at}]'
```

If multiple matches, ask the user to clarify. If no match, ask the user for the post ID.

## Step 3: Check Who Has Voted

For each player in the session, check submission status:

```bash
curl -s "https://player-rating-survey-three.vercel.app/api/vote?session=SESSION_NAME_URL_ENCODED&voter=VOTER_NAME_URL_ENCODED"
```

Response: `{ "submitted": true }` or `{ "submitted": false }`

Collect the list of players who have submitted votes.

## Step 4: Find Voters in Circle

For each voter who submitted, search Circle by name or email:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members/search?community_id=$CIRCLE_COMMUNITY_ID&query=VOTER_NAME_OR_EMAIL" \
  | jq '[.records[] | {id, name, email}]'
```

Build a list of confirmed completers who are also Circle members.

## Step 5: Compose the Welcome-Back Comment

Create a comment on the original survey post thanking completers and guiding them to community discovery:

```html
<p><strong>Survey complete — welcome to Link &amp; Dink!</strong></p>
<p>Thanks to everyone who rated their playing partners! Your responses help us build better groups and match you with great partners for future events.</p>
<p><strong>What to explore next:</strong></p>
<ul>
  <li>Check out <strong>upcoming events</strong> in this space — join one that fits your schedule</li>
  <li>Browse <strong>partner-finding posts</strong> in the Tournaments space to connect with players at your level</li>
  <li>Reply to this post and <strong>introduce yourself</strong> — share your skill level and what you enjoy playing!</li>
</ul>
<p>You'll start seeing personalized match suggestions based on your survey responses soon.</p>
```

## Step 6: Confirm and Post Comment

**Always show the user the comment preview before posting.** Include:
- The original post name and ID
- Number of confirmed completers
- The comment body preview

After user confirms, create the comment:

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "post_id": POST_ID,
    "body": "HTML_BODY_HERE"
  }' \
  "https://app.circle.so/api/admin/v2/comments"
```

**Important:** Do NOT include `community_id` in comment creation requests.

## Step 7: Report

Show:
- Number of voters who completed the survey
- Number of those who are Circle members
- The comment URL (or post URL where the comment was added)
- Any voters who completed but are NOT Circle members (potential invite opportunities)

## Notes

- **Why a comment, not a new post**: Keeps the welcome-back content in the same thread as the original survey links. Members see the natural progression: survey invite → completion → community discovery. Avoids post clutter.
- **No survey links in this comment**: This is intentionally the EXIT from the survey flow. Do not include any Play Date URLs.
- **Non-Circle voters**: If a voter completed the survey but is not a Circle member, note them as potential Circle invite candidates but do not auto-invite (let the user decide).
- **Timing**: Best run after most voters have submitted (check with `/post-event-survey status SESSION_NAME` first).
