---
description: Sync CourtReserve events to Circle — pull tournaments and Next Gen events from CR and create them in Circle
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Bash(base64:*), Bash(sed:*), Read
argument-hint: "[location] [days] — location: rockville|nb|both (default both), days: lookahead (default 30)"
---

Sync relevant CourtReserve events to Circle.so. Use the cr-to-circle skill for field mapping, category filters, description templates, and dedup logic.

## Parse Arguments

From `$ARGUMENTS`, extract:
- **location**: `rockville`, `nb`/`northbethesda`, or `both` (default: `both`)
- **days**: number of days to look ahead (default: `30`)

If arguments are empty, use defaults (both locations, 30 days).

## Step 1: Validate Environment

Check that ALL required env vars are set:

**CourtReserve** (per location being synced):
- `COURTRESERVE_ROCKVILLE_USERNAME`, `COURTRESERVE_ROCKVILLE_PASSWORD`, `COURTRESERVE_ROCKVILLE_ORG_ID`
- `COURTRESERVE_NORTHBETHESDA_USERNAME`, `COURTRESERVE_NORTHBETHESDA_PASSWORD`, `COURTRESERVE_NORTHBETHESDA_ORG_ID`

**Circle**:
- `CIRCLE_API_KEY`, `CIRCLE_COMMUNITY_ID`

If any are missing, report which ones and stop.

## Step 2: Fetch CourtReserve Events

For each selected location, fetch the event list:

```bash
TODAY=$(date +%Y-%m-%d)
END=$(date -d "+DAYS days" +%Y-%m-%d)

for LOC in ROCKVILLE NORTHBETHESDA; do
  U_VAR="COURTRESERVE_${LOC}_USERNAME"
  P_VAR="COURTRESERVE_${LOC}_PASSWORD"
  O_VAR="COURTRESERVE_${LOC}_ORG_ID"
  AUTH=$(echo -n "${!U_VAR}:${!P_VAR}" | base64)
  curl -s -H "Authorization: Basic $AUTH" -H "Content-Type: application/json" \
    "https://api.courtreserve.com/api/v1/eventcalendar/eventlist?OrgId=${!O_VAR}&StartDate=$TODAY&EndDate=$END"
done
```

## Step 3: Filter by Category

From the CR response `.Data[]`, keep only events matching these categories (case-insensitive):

1. **Tournaments**: `EventCategoryName` contains "Competitive Events" or "Tournament" OR `EventName` matches "Link & Dink" or "Tournament"
2. **Next Gen**: `EventCategoryName` or `EventName` contains "Next Gen" or "Kids Program"

Skip cancelled events (`.IsCanceled == true`).

Use jq to filter:
```bash
jq '[.Data[] | select(.IsCanceled == false) | select(
  (.EventCategoryName | test("competitive events|tournament"; "i")) or
  (.EventName | test("link.+dink|tournament|next gen|kids program"; "i")) or
  (.EventCategoryName | test("next gen|kids program"; "i"))
)]'
```

Present the filtered events to the user and ask for confirmation before creating Circle events.

## Step 4: Fetch Existing Circle Events (Dedup)

Fetch ALL Circle events (paginate if needed) to check for duplicates:

```bash
curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
  "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=1"
```

Paginate through all pages. A CR event is a **duplicate** if a Circle event exists with:
- **Normalized name match** — before comparing, normalize both names: lowercase, replace `&` with `and`, strip all punctuation (dashes, colons, commas, parentheses, etc.), collapse multiple spaces to single space, trim
- Same start date (compare date portion `YYYY-MM-DD` only, not exact time)

**Normalization example**: "Link & Dink Tournament – Women's Only (3.0–3.5)" and "Link and Dink Tournament: Women's ONLY 3.0-3.5" both normalize to "link and dink tournament womens only 303.5"

## Step 5: Create Circle Events

For each non-duplicate CR event, create a Circle event using the field mapping and description templates from the cr-to-circle skill.

**Space routing:**
- Tournaments / Competitive Events → space_id `1916764` (Tournaments space)
- Next Gen → space_id `1718302` (Link and Dink Events space)

**Location mapping:**
- OrgId 10869 (Rockville) → `{"formatted_address":"40 Southlawn Ct, Rockville, MD 20850, USA","geometry":{"location":{"lat":39.1024421,"lng":-77.1294295}},"name":"Dill Dinkers Rockville"}`
- OrgId 10483 (North Bethesda) → `{"formatted_address":"4942 Boiling Brook Pkwy, North Bethesda, MD 20852, USA","name":"Dill Dinkers North Bethesda"}`

Use the Circle event creation API (nested `event` + `event_setting_attributes` pattern) from the circle-events skill. Generate the event body using the appropriate description template from the cr-to-circle skill.

Pause briefly (~1s) between API calls to avoid rate limiting.

## Step 6: Report Summary

Present a summary table:

```
CR → Circle Sync Results
════════════════════════
Location:  [location(s)]
Lookahead: [days] days ([start] to [end])
────────────────────────
Created:   [N] events
Skipped:   [N] (already in Circle)
Failed:    [N]
────────────────────────
```

Then list each event with its status:
- **Created**: event name, Circle URL
- **Skipped**: event name, reason (duplicate)
- **Failed**: event name, error details
