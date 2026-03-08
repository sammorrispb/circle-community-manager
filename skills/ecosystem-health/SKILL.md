---
name: Ecosystem Health
description: >-
  This skill should be used when the user asks for "ecosystem health",
  "full dashboard", "ecosystem status", "system overview", "daily briefing",
  "how's everything looking", "community stats", "cross-system health",
  or any operation that provides a combined health check across Circle,
  CourtReserve, Play Date, and The Hub.
version: 1.0.0
---

# Ecosystem Health Dashboard

Combined health check and metrics across the entire Dill Dinkers ecosystem: Circle (community), CourtReserve (facilities), Play Date (intake), and funnel analytics.

## Prerequisites

Check which credentials are available and report on configured systems:

| System | Required Env Vars |
|--------|-------------------|
| Circle | `CIRCLE_API_KEY`, `CIRCLE_COMMUNITY_ID` |
| CR Rockville | `COURTRESERVE_ROCKVILLE_USERNAME`, `_PASSWORD`, `_ORG_ID` |
| CR North Bethesda | `COURTRESERVE_NORTHBETHESDA_USERNAME`, `_PASSWORD`, `_ORG_ID` |

Run the health check for every system with valid credentials. Skip systems with missing credentials and note them in the report.

## Step 1: Circle Health

### Member Count

Paginate through all members to get total count:

```bash
TOTAL=0
PAGE=1
while true; do
  RESPONSE=$(curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
    "https://app.circle.so/api/admin/v2/community_members?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=$PAGE")
  COUNT=$(echo "$RESPONSE" | jq '.records | length')
  TOTAL=$((TOTAL + COUNT))
  HAS_NEXT=$(echo "$RESPONSE" | jq -r '.has_next_page')
  [ "$HAS_NEXT" = "true" ] || break
  PAGE=$((PAGE + 1))
  sleep 0.5
done
echo "Total members: $TOTAL"
```

### Spaces

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/spaces?community_id=$CIRCLE_COMMUNITY_ID&per_page=100" \
  | jq '[.records[] | {id, name, slug}]'
```

### Upcoming Events

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100" \
  | jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '[.records[] | select(.starts_at > $now)] | length'
```

### Recent Posts (last 7 days)

For each space, check recent post activity:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/posts?space_id=SPACE_ID&per_page=10&status=published" \
  | jq --arg cutoff "$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
    '[.records[] | select(.published_at > $cutoff)] | length'
```

Limit to 3-5 most active spaces to avoid rate limiting.

## Step 2: CourtReserve Health

For each configured location (`ROCKVILLE`, `NORTHBETHESDA`):

### Today's Activity

```bash
U_VAR="COURTRESERVE_${LOC}_USERNAME"
P_VAR="COURTRESERVE_${LOC}_PASSWORD"
O_VAR="COURTRESERVE_${LOC}_ORG_ID"
AUTH=$(echo -n "${!U_VAR}:${!P_VAR}" | base64)
TODAY=$(date +%Y-%m-%d)

# Today's reservations
curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/reservations/getbydate?OrgId=${!O_VAR}&Date=$TODAY" \
  | jq '.Data | length'
```

### Upcoming Events (next 14 days)

```bash
END=$(date -d "+14 days" +%Y-%m-%d)
curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/eventcalendar/eventlist?OrgId=${!O_VAR}&StartDate=$TODAY&EndDate=$END" \
  | jq '[.Data[] | select(.IsCanceled == false)] | length'
```

### Member Count

```bash
curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/member/get?OrgId=${!O_VAR}&pageSize=1&pageNumber=1" \
  | jq '.Data.TotalPages'
```

Multiply TotalPages by pageSize (default 50) for approximate count, or just report TotalPages.

## Step 3: Play Date Metrics

Play Date doesn't have a public API for stats. Report what's known:
- **Survey URL**: `https://play-date-five.vercel.app/`
- **Status**: Note that Play Date completion data is available in The Hub's Supabase
- **Link generation**: Remind that Play Date links follow the pattern `https://play-date-five.vercel.app/#survey-{email}`

## Step 4: Funnel Analysis

Compute cross-system funnel metrics based on available data:

```
Ecosystem Funnel (approximate)
──────────────────────────────
Circle Members:     [count]     ← Community reach
CR Members (RV):    [count]     ← Facility engagement (Rockville)
CR Members (NB):    [count]     ← Facility engagement (North Bethesda)
Play Date Profiles: [check Hub] ← Intake completion
Hub Active:         [check Hub] ← Full engagement
```

The funnel shows the conversion from community awareness to facility use to full platform engagement.

## Step 5: Present Dashboard

Format the complete health report:

```
Ecosystem Health Dashboard
══════════════════════════════════════════
Date: [today's date]

CIRCLE (Community)
  Members:         [count]
  Spaces:          [count] ([top space names])
  Upcoming Events: [count] (next: [name] on [date])
  Posts (7d):      [count] across [n] spaces
  Status:          [OK / Issues]

COURTRESERVE (Facilities)
  Rockville
    Today:         [n] reservations
    Events (14d):  [n] upcoming
    Members:       ~[estimate]
    Status:        [OK / Issues]

  North Bethesda
    Today:         [n] reservations
    Events (14d):  [n] upcoming
    Members:       ~[estimate]
    Status:        [OK / Issues]

PLAY DATE (Intake)
    Status:        [Active — check Hub for completion rates]

FUNNEL
  Circle → CR:     [overlap estimate or "check Hub"]
  CR → Play Date:  [check Hub for conversion]

──────────────────────────────────────────
Systems checked: [list]
Systems skipped: [list + reason]
Last updated:    [timestamp]
```

## Performance Notes

- **Rate limiting**: This skill makes many API calls. Space them 0.5-1s apart.
- **Circle pagination**: Member count requires full pagination — can take 10-20 seconds for large communities.
- **CR calls**: Two locations = double the API calls. If one location's credentials are missing, skip it.
- **Caching**: Consider running this once per day rather than repeatedly. The `/ecosystem-report` command is designed for daily use.

## Error Handling

| System | Error | Recovery |
|--------|-------|----------|
| Circle 401 | Bad API key or rate limited | Note in report, continue with other systems |
| Circle 429 | Rate limited | Wait 30s and retry once |
| CR 401 | Bad credentials | Note in report, continue |
| CR timeout | API slow | Note in report, continue |
| Partial data | One system down | Present available data, note gaps |

Always produce a report even if some systems fail — partial visibility is better than none.
