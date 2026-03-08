#!/usr/bin/env bash
set -eo pipefail

# Fix incorrect Circle event times caused by treating Eastern time as UTC.
# The original sync used `date -d "$dt" -u` which on a UTC system treats
# input as UTC. This script re-fetches CR times and updates Circle events
# with correctly converted UTC values.
#
# Usage:
#   export CIRCLE_API_KEY=... CIRCLE_COMMUNITY_ID=...
#   export COURTRESERVE_ROCKVILLE_USERNAME=... COURTRESERVE_ROCKVILLE_PASSWORD=...
#   export COURTRESERVE_NORTHBETHESDA_USERNAME=... COURTRESERVE_NORTHBETHESDA_PASSWORD=...
#   ./fix-event-times.sh           # dry run (default)
#   ./fix-event-times.sh --apply   # actually update Circle events

APPLY=false
[ "${1:-}" = "--apply" ] && APPLY=true

# --- Validate env vars ---
for var in CIRCLE_API_KEY CIRCLE_COMMUNITY_ID \
           COURTRESERVE_ROCKVILLE_USERNAME COURTRESERVE_ROCKVILLE_PASSWORD \
           COURTRESERVE_NORTHBETHESDA_USERNAME COURTRESERVE_NORTHBETHESDA_PASSWORD; do
  [ -n "${!var}" ] || { echo "ERROR: $var not set"; exit 1; }
done

RV_ORG=10869
NB_ORG=10483
TOURNAMENT_SPACE=1916764
NEXTGEN_SPACE=1718302
START_DATE="2026-03-07"
END_DATE="2026-05-31"

# --- Helper functions ---

normalize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/&/and/g' | sed 's/[^a-z0-9 ]//g' | tr -s ' ' | sed 's/^ *//;s/ *$//'
}

eastern_to_utc() {
  local dt="$1"
  local epoch
  epoch=$(TZ=America/New_York date -d "$dt" +%s)
  date -u -d "@$epoch" +"%Y-%m-%dT%H:%M:%S.000Z"
}

# --- Fetch CourtReserve events ---

echo "=== Fetching CourtReserve events ==="

RV_AUTH=$(echo -n "$COURTRESERVE_ROCKVILLE_USERNAME:$COURTRESERVE_ROCKVILLE_PASSWORD" | base64)
NB_AUTH=$(echo -n "$COURTRESERVE_NORTHBETHESDA_USERNAME:$COURTRESERVE_NORTHBETHESDA_PASSWORD" | base64)

RV_RAW=$(curl -s -H "Authorization: Basic $RV_AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/eventcalendar/eventlist?OrgId=$RV_ORG&StartDate=$START_DATE&EndDate=$END_DATE")

NB_RAW=$(curl -s -H "Authorization: Basic $NB_AUTH" -H "Content-Type: application/json" \
  "https://api.courtreserve.com/api/v1/eventcalendar/eventlist?OrgId=$NB_ORG&StartDate=$START_DATE&EndDate=$END_DATE")

echo "  Rockville raw: $(echo "$RV_RAW" | jq '.Data | length') events"
echo "  North Bethesda raw: $(echo "$NB_RAW" | jq '.Data | length') events"

# Filter: not canceled AND (Next Gen/Kids Program OR Tournament/Competitive/Link&Dink)
FILTER='[.Data[] | select(.IsCanceled != true) |
  select(
    ((.EventCategoryName // "" | test("next gen|kids program"; "i")) or
     (.EventName // "" | test("next gen|kids program"; "i"))) or
    ((.EventCategoryName // "" | test("competitive events|tournament"; "i")) or
     (.EventName // "" | test("link.*(and|&).*dink|tournament"; "i")))
  ) |
  {EventName, StartDateTime, EndDateTime, EventId, EventCategoryName}
]'

RV_FILTERED=$(echo "$RV_RAW" | jq "$FILTER")
NB_FILTERED=$(echo "$NB_RAW" | jq "$FILTER")

echo "  Rockville filtered: $(echo "$RV_FILTERED" | jq 'length') events"
echo "  North Bethesda filtered: $(echo "$NB_FILTERED" | jq 'length') events"

# --- Fetch all Circle events (paginated) ---

echo "=== Fetching Circle events ==="

ALL_CIRCLE="[]"
PAGE=1
while true; do
  RESP=$(curl -s -H "Authorization: Token $CIRCLE_API_KEY" \
    "https://app.circle.so/api/admin/v2/events?community_id=$CIRCLE_COMMUNITY_ID&per_page=100&page=$PAGE")
  RECORDS=$(echo "$RESP" | jq '.records // []')
  COUNT=$(echo "$RECORDS" | jq 'length')
  ALL_CIRCLE=$(echo "$ALL_CIRCLE" "$RECORDS" | jq -s '.[0] + .[1]')
  HAS_NEXT=$(echo "$RESP" | jq -r '.has_next_page // false')
  echo "  Page $PAGE: $COUNT events (has_next=$HAS_NEXT)"
  [ "$HAS_NEXT" = "true" ] || break
  PAGE=$((PAGE + 1))
done

# Only keep events in the two relevant spaces
CIRCLE_RELEVANT=$(echo "$ALL_CIRCLE" | jq "[.[] | select(.space.id == $TOURNAMENT_SPACE or .space.id == $NEXTGEN_SPACE)]")
echo "  Circle relevant (Tournament + NextGen spaces): $(echo "$CIRCLE_RELEVANT" | jq 'length') events"

# --- Build Circle lookup: normalized_name|date -> id|space_id|starts_at|ends_at ---

echo "=== Building Circle lookup ==="

declare -A CIRCLE_LOOKUP

circle_count=$(echo "$CIRCLE_RELEVANT" | jq 'length')
for i in $(seq 0 $((circle_count - 1))); do
  c_name=$(echo "$CIRCLE_RELEVANT" | jq -r ".[$i].name")
  c_starts=$(echo "$CIRCLE_RELEVANT" | jq -r ".[$i].starts_at")
  c_ends=$(echo "$CIRCLE_RELEVANT" | jq -r ".[$i].ends_at")
  c_id=$(echo "$CIRCLE_RELEVANT" | jq -r ".[$i].id")
  c_space=$(echo "$CIRCLE_RELEVANT" | jq -r ".[$i].space.id")
  c_date="${c_starts:0:10}"
  c_norm=$(normalize_name "$c_name")

  # Extract location from in_person_location to disambiguate same-name events
  c_loc_raw=$(echo "$CIRCLE_RELEVANT" | jq -r ".[$i].in_person_location // \"\"")
  if echo "$c_loc_raw" | grep -qi "rockville"; then
    c_loc="rv"
  elif echo "$c_loc_raw" | grep -qi "bethesda"; then
    c_loc="nb"
  else
    c_loc="unknown"
  fi

  CIRCLE_LOOKUP["${c_norm}|${c_date}|${c_loc}"]="${c_id}|${c_space}|${c_starts}|${c_ends}"
done

echo "  Indexed ${#CIRCLE_LOOKUP[@]} Circle events"

# --- Match CR events to Circle events ---

echo "=== Matching events ==="

declare -A UPDATES  # key = circle_id, value = "space_id|correct_start|correct_end|name|current_start"
UNMATCHED=()
MATCH_COUNT=0

process_cr_events() {
  local cr_events="$1"
  local cr_loc="$2"  # "rv" or "nb"
  local count
  count=$(echo "$cr_events" | jq 'length')

  for i in $(seq 0 $((count - 1))); do
    local cr_name cr_start cr_end norm_name cr_date correct_start correct_end
    cr_name=$(echo "$cr_events" | jq -r ".[$i].EventName")
    cr_start=$(echo "$cr_events" | jq -r ".[$i].StartDateTime")
    cr_end=$(echo "$cr_events" | jq -r ".[$i].EndDateTime")

    norm_name=$(normalize_name "$cr_name")
    # Parse CR date (M/D/YYYY format) to YYYY-MM-DD for lookup
    cr_date=$(date -d "$cr_start" +"%Y-%m-%d")

    correct_start=$(eastern_to_utc "$cr_start")
    correct_end=$(eastern_to_utc "$cr_end")

    local key="${norm_name}|${cr_date}|${cr_loc}"
    if [ -n "${CIRCLE_LOOKUP[$key]+x}" ]; then
      IFS='|' read -r c_id c_space c_cur_start c_cur_end <<< "${CIRCLE_LOOKUP[$key]}"

      # Only update if times actually differ
      if [ "$c_cur_start" != "$correct_start" ] || [ "$c_cur_end" != "$correct_end" ]; then
        UPDATES["$c_id"]="${c_space}|${correct_start}|${correct_end}|${cr_name}|${c_cur_start}"
        MATCH_COUNT=$((MATCH_COUNT + 1))
      fi
    else
      UNMATCHED+=("$cr_name ($cr_date)")
    fi
  done
}

process_cr_events "$RV_FILTERED" "rv"
process_cr_events "$NB_FILTERED" "nb"

echo "  Matched (needing update): $MATCH_COUNT"
echo "  Unmatched: ${#UNMATCHED[@]}"

# --- Report ---

echo ""
echo "================================================================"
echo "  DRY RUN REPORT: ${#UPDATES[@]} events to update"
echo "================================================================"
echo ""

idx=0
for c_id in "${!UPDATES[@]}"; do
  idx=$((idx + 1))
  IFS='|' read -r space_id correct_start correct_end name current_start <<< "${UPDATES[$c_id]}"
  printf "[%3d] Circle#%s \"%s\"\n" "$idx" "$c_id" "$name"
  printf "       Current starts_at: %s\n" "$current_start"
  printf "       Correct starts_at: %s  ends_at: %s\n\n" "$correct_start" "$correct_end"
done

if [ ${#UNMATCHED[@]} -gt 0 ]; then
  echo "=== UNMATCHED CR EVENTS ==="
  for u in "${UNMATCHED[@]}"; do
    echo "  - $u"
  done
  echo ""
fi

echo "Summary: ${#UPDATES[@]} to update, ${#UNMATCHED[@]} unmatched"
echo ""

if [ "$APPLY" != "true" ]; then
  echo "This was a DRY RUN. To apply changes, run:"
  echo "  $0 --apply"
  exit 0
fi

# --- Apply updates ---

echo "=== Applying updates ==="

update_ok=0
update_fail=0
total=${#UPDATES[@]}

for c_id in "${!UPDATES[@]}"; do
  IFS='|' read -r space_id correct_start correct_end name current_start <<< "${UPDATES[$c_id]}"

  # Compute duration_in_seconds (Circle ignores ends_at in nested attrs on PUT)
  start_epoch=$(date -d "$correct_start" +%s)
  end_epoch=$(date -d "$correct_end" +%s)
  duration=$((end_epoch - start_epoch))

  HTTP_CODE=$(curl -s -o /tmp/circle_update_resp.json -w "%{http_code}" -X PUT \
    -H "Authorization: Token $CIRCLE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "community_id": '"$CIRCLE_COMMUNITY_ID"',
      "space_id": '"$space_id"',
      "event": {
        "ends_at": "'"$correct_end"'",
        "event_setting_attributes": {
          "starts_at": "'"$correct_start"'",
          "duration_in_seconds": '"$duration"'
        }
      }
    }' \
    "https://app.circle.so/api/admin/v2/events/$c_id")

  if [ "$HTTP_CODE" = "200" ]; then
    # Verify ends_at in response
    resp_ends=$(jq -r '.ends_at // empty' /tmp/circle_update_resp.json)
    if [ -n "$resp_ends" ] && [ "$resp_ends" != "$correct_end" ]; then
      echo "[$((update_ok + 1))/$total] WARN Circle#$c_id ends_at mismatch: got $resp_ends, expected $correct_end"
    fi
    update_ok=$((update_ok + 1))
    echo "[$update_ok/$total] OK  Circle#$c_id \"$name\" -> start=$correct_start end=$correct_end (${duration}s)"
  elif [ "$HTTP_CODE" = "401" ]; then
    echo "[$((update_ok + update_fail + 1))/$total] GOT 401 — Circle API cooldown. Pausing 5 minutes..."
    sleep 300
    # Retry once
    HTTP_CODE=$(curl -s -o /tmp/circle_update_resp.json -w "%{http_code}" -X PUT \
      -H "Authorization: Token $CIRCLE_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "community_id": '"$CIRCLE_COMMUNITY_ID"',
        "space_id": '"$space_id"',
        "event": {
          "ends_at": "'"$correct_end"'",
          "event_setting_attributes": {
            "starts_at": "'"$correct_start"'",
            "duration_in_seconds": '"$duration"'
          }
        }
      }' \
      "https://app.circle.so/api/admin/v2/events/$c_id")
    if [ "$HTTP_CODE" = "200" ]; then
      update_ok=$((update_ok + 1))
      echo "  RETRY OK Circle#$c_id"
    else
      update_fail=$((update_fail + 1))
      echo "  RETRY FAILED Circle#$c_id HTTP $HTTP_CODE: $(cat /tmp/circle_update_resp.json)"
    fi
  elif [ "$HTTP_CODE" = "429" ]; then
    echo "  Rate limited — pausing 60s..."
    sleep 60
    # Retry once (not shown for brevity, same pattern as 401)
    update_fail=$((update_fail + 1))
  else
    update_fail=$((update_fail + 1))
    echo "[$((update_ok + update_fail))/$total] FAIL Circle#$c_id HTTP $HTTP_CODE: $(cat /tmp/circle_update_resp.json)"
  fi

  sleep 1  # 1s spacing between writes
done

echo ""
echo "=== Complete: $update_ok updated, $update_fail failed out of $total ==="
