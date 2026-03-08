---
name: Next Gen Circle Integration
description: >-
  This skill should be used when the user asks to "post Next Gen recap",
  "invite Next Gen parents to Circle", "Next Gen schedule", "youth program
  update", "Next Gen Circle", "kids program post", "academy recap",
  or any operation bridging Next Gen PB Academy with the Circle
  community.
version: 1.0.0
---

# Next Gen Academy - Circle Integration

Bridge Next Gen PB Academy operations with the Circle community. Post session recaps, invite parents, announce schedules, and cross-reference rosters.

## Context

- **Next Gen PB Academy** (nextgenpbacademy.com) = Sam's youth coaching program
- Next Gen ops data lives in **Notion** (roster, attendance, payments) — managed via the `next-gen-crm` skill
- Next Gen events appear in **CourtReserve** as events with "Next Gen" or "Kids Program" in the name
- **Circle** is the community platform where parents and adult players connect
- The goal: bring Next Gen families into the Link & Dink community to grow the adult pipeline

## Prerequisites

**Required**:
- `CIRCLE_API_KEY` + `CIRCLE_COMMUNITY_ID` — for posting and inviting

**Optional**:
- CR credentials — for fetching Next Gen event data from CourtReserve
- Notion access — for roster data (use the `next-gen-crm` skill or Notion MCP tools)

## Circle Space for Next Gen

Next Gen content goes in the **Link and Dink Events** space:
- **Space ID**: `1718302`
- This is the same space used by CR to Circle sync for Next Gen events

To verify or find the space:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/spaces?community_id=$CIRCLE_COMMUNITY_ID&per_page=100" \
  | jq '[.records[] | select(.name | test("event"; "i")) | {id, name}]'
```

## Workflow 1: Post Session Recap

Create a recap post after a Next Gen coaching session.

### Gather Session Info

Ask the user for (or pull from Notion/CR):
- Session date
- Program level (Red Ball, Orange Ball, Green Ball, Yellow Ball)
- Attendance count
- Drills covered
- Highlights / notable moments
- Any photos (URLs)

### Compose Recap Post

```html
<h2>Next Gen Academy Recap - {LEVEL} ({DATE})</h2>
<p><strong>Attendance</strong>: {COUNT} players</p>

<h3>What We Worked On</h3>
<ul>
{FOR EACH DRILL}
  <li>{DRILL_NAME}: {BRIEF_DESCRIPTION}</li>
{END FOR}
</ul>

{IF HIGHLIGHTS}
<h3>Highlights</h3>
<p>{HIGHLIGHTS_TEXT}</p>
{END IF}

<p>Learn more about Next Gen PB Academy at <a href="https://www.nextgenpbacademy.com">nextgenpbacademy.com</a></p>
<hr>
<p><em>Next Gen PB Academy - Building the next generation of players</em></p>
```

### Create the Post

**Preview first**, then create after user confirmation:

```bash
curl -s -X POST \
  -H "Authorization: Token $CIRCLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": 1718302,
    "name": "Next Gen Recap - LEVEL (DATE)",
    "body": "HTML_BODY",
    "status": "published"
  }' \
  "https://app.circle.so/api/admin/v2/posts"
```

Do NOT include `community_id` in post creation.

## Workflow 2: Invite Next Gen Parents to Circle

Bulk invite parent emails to the Circle community.

### Gather Parent Emails

Source parent emails from:
1. **User provides a list** - most common
2. **Notion roster** - use `next-gen-crm` skill to pull parent contact info
3. **CR event registrations** - fetch Next Gen event registrations from CR

### Invite Each Parent

```bash
for EMAIL in "${PARENT_EMAILS[@]}"; do
  curl -s -X POST \
    -H "Authorization: Token $CIRCLE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "community_id": '"$CIRCLE_COMMUNITY_ID"',
      "email": "'"$EMAIL"'",
      "name": "'"$NAME"'",
      "space_ids": [1718302]
    }' \
    "https://app.circle.so/api/admin/v2/community_members"
  sleep 1
done
```

This adds them to the **Link and Dink Events** space automatically.

### Report Results

Track and report:
- Successfully invited (new members)
- Already members (409 duplicate)
- Failed invites (with error details)

## Workflow 3: Announce Upcoming Schedule

Post the Next Gen schedule for the upcoming week/month.

### Fetch Next Gen Events from CR

If CR credentials are available:

```bash
TODAY=$(date +%Y-%m-%d)
END=$(date -d "+30 days" +%Y-%m-%d)

for LOC in ROCKVILLE NORTHBETHESDA; do
  U_VAR="COURTRESERVE_${LOC}_USERNAME"
  P_VAR="COURTRESERVE_${LOC}_PASSWORD"
  O_VAR="COURTRESERVE_${LOC}_ORG_ID"
  [ -z "${!U_VAR}" ] && continue
  AUTH=$(echo -n "${!U_VAR}:${!P_VAR}" | base64)

  curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
    "https://api.courtreserve.com/api/v1/eventcalendar/eventlist?OrgId=${!O_VAR}&StartDate=$TODAY&EndDate=$END" \
    | jq '[.Data[] | select(.IsCanceled == false) |
      select((.EventCategoryName | test("next gen|kids program"; "i")) or
             (.EventName | test("next gen|kids program"; "i"))) |
      {EventName, StartDateTime, EndDateTime, MaxRegistrants, RegisteredCount, PublicEventUrl}]'
done
```

### Compose Schedule Post

```html
<h2>Next Gen Academy - Upcoming Schedule</h2>
<p>Here's what's coming up for our youth players:</p>

<table>
<tr><th>Date</th><th>Program</th><th>Location</th><th>Spots</th><th>Register</th></tr>
{FOR EACH EVENT}
<tr>
  <td>{DATE}</td>
  <td>{EVENT_NAME}</td>
  <td>{LOCATION}</td>
  <td>{SPOTS_REMAINING}/{MAX}</td>
  <td><a href="{PUBLIC_EVENT_URL}">Sign Up</a></td>
</tr>
{END FOR}
</table>

<p>Questions? Visit <a href="https://www.nextgenpbacademy.com">nextgenpbacademy.com</a> or email sam@linkanddink.com</p>
```

## Workflow 4: Roster to Circle Cross-Reference

Compare the Next Gen roster (from Notion) with Circle membership to find parents who haven't joined the community.

### Steps

1. Get Next Gen parent emails from Notion (via `next-gen-crm` or Notion MCP tools)
2. For each email, search Circle:
   ```bash
   curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
     "https://app.circle.so/api/admin/v2/community_members/search?community_id=$CIRCLE_COMMUNITY_ID&query=EMAIL"
   ```
3. Categorize:
   - **In both**: Already connected
   - **In Notion, not Circle**: Invite opportunity
   - **In Circle, not Notion**: May be alumni or non-Next Gen parent

4. Present results and offer to bulk-invite the "not in Circle" group

## Error Handling

| Error | Recovery |
|-------|----------|
| Circle 401 | Check API key; may be rate limited after bulk invites |
| Circle 409 | Member already exists - not an error, track as "already member" |
| CR no Next Gen events | Location may not have youth programs scheduled |
| Notion access fails | Fall back to manual parent email list |

## Related Skills

- **circle-posts** - Post creation patterns and HTML body format
- **circle-members** - Member invite and space management
- **cr-to-circle** - CR event sync patterns (Next Gen filter logic)
- **ecosystem-lookup** - Individual cross-system player lookup
- **next-gen-crm** - Notion-based Next Gen roster and session management
