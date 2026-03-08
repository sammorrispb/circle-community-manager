---
name: Ecosystem Lookup
description: >-
  This skill should be used when the user asks to "look up a player",
  "find someone across systems", "who is this person", "player profile",
  "ecosystem lookup", "cross-system search", "tell me about this player",
  or any operation that requires searching for a person across Circle,
  CourtReserve, Play Date, and/or The Hub.
version: 1.0.0
---

# Cross-System Player Lookup

Search for a player across the Dill Dinkers ecosystem by email or name. Presents a unified profile card combining data from Circle (community), CourtReserve (facilities), and Play Date (intake surveys).

**Email is the universal join key** across all systems.

## Prerequisites

**Required** (at least one):
- `CIRCLE_API_KEY` + `CIRCLE_COMMUNITY_ID` — Circle community
- `COURTRESERVE_ROCKVILLE_USERNAME` + `_PASSWORD` + `_ORG_ID` — CR Rockville
- `COURTRESERVE_NORTHBETHESDA_USERNAME` + `_PASSWORD` + `_ORG_ID` — CR North Bethesda

Check which credentials are available and search whichever systems are configured. Report which systems were skipped due to missing credentials.

## Step 1: Parse Search Input

Accept either:
- **Email**: Direct lookup (most precise)
- **Name**: Search by name (may return multiple matches)

If the user provides a name, search Circle first (it supports text search), then use any matched email to look up CR.

## Step 2: Search Circle

Use the circle-members skill search endpoint:

```bash
# By name or email
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members/search?community_id=$CIRCLE_COMMUNITY_ID&query=SEARCH_TERM" \
  | jq '[.records[] | {id, name, email, headline, bio, avatar_url, created_at, last_seen_at}]'
```

If searching by email and no search results, try listing members and filtering:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_members?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1" \
  | jq --arg email "EMAIL" '[.records[] | select(.email == $email) | {id, name, email, headline, bio, created_at, last_seen_at}]'
```

If a Circle member is found, also fetch their space memberships:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/community_member_spaces?community_id=$CIRCLE_COMMUNITY_ID&community_member_id=MEMBER_ID"
```

## Step 3: Search CourtReserve

CR API only supports email-based member lookup (no free-text search). If you only have a name from Circle, use the email found there.

For each configured location:

```bash
U_VAR="COURTRESERVE_${LOC}_USERNAME"
P_VAR="COURTRESERVE_${LOC}_PASSWORD"
O_VAR="COURTRESERVE_${LOC}_ORG_ID"
AUTH=$(echo -n "${!U_VAR}:${!P_VAR}" | base64)

curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/member/get?OrgId=${!O_VAR}&email=EMAIL" \
  | jq '[.Data.Members[] | {
    Id: .OrganizationMemberId,
    Name: "\(.FirstName) \(.LastName)",
    Email,
    Phone: .PhoneNumber,
    Membership: .MembershipTypeName,
    Status: .MembershipStatus,
    Gender,
    City,
    State
  }]'
```

Run for both `ROCKVILLE` and `NORTHBETHESDA` if credentials exist.

## Step 4: Check Play Date Status

Generate the Play Date survey URL for the player's email:

```
https://play-date-five.vercel.app/#survey-{URL_ENCODED_EMAIL}
```

Note: There's no public API to check Play Date completion status. Report the survey link and note "check Hub for completion status" if Hub access is available.

## Step 5: Hub Status (Manual Check)

The Hub stores unified player profiles in Supabase but requires authentication. Note for the user:
- Hub profile can be checked via The Hub admin UI or Supabase dashboard
- Key Hub data: XP score, engagement level, group memberships, peer ratings, onboarding status

## Step 6: Present Unified Profile Card

Format results as a clean profile card:

```
Player Profile: [Name]
═══════════════════════════════════════════

Circle (Community)
  Status:     [Member / Not Found]
  Email:      [email]
  Joined:     [created_at]
  Last Seen:  [last_seen_at]
  Spaces:     [list of space names]
  Headline:   [headline]

CourtReserve (Facilities)
  Rockville:      [Member / Not Found]
  North Bethesda: [Member / Not Found]
  Membership:     [type + status]
  Phone:          [phone]

Play Date (Intake)
  Survey Link: [URL]
  Status:      [Check Hub for completion]

Hub (Intelligence)
  Status:      [Check Hub admin for XP, ratings, groups]

───────────────────────────────────────────
Systems searched: [list]
Systems skipped:  [list + reason]
```

## Cross-System Insights

After presenting the profile, note any gaps or opportunities:
- **In Circle but not CR**: "This person is in the community but hasn't been to a facility — consider inviting to an event"
- **In CR but not Circle**: "Active at facilities but not in the community — consider a Circle invite"
- **No Play Date profile**: "No survey on file — generate an invite link"
- **In all systems**: "Fully connected member — check Hub for engagement score"

## Error Handling

| System | Error | Recovery |
|--------|-------|----------|
| Circle 401 | Bad API key | Re-check CIRCLE_API_KEY |
| Circle 429 | Rate limited | Wait and retry |
| CR 401 | Bad credentials | Check CR username/password |
| CR empty | No members found | Email may not match (case-sensitive) |

- If one system fails, continue with the remaining systems
- A partial profile is better than no profile
- Always report which systems were searched vs skipped
