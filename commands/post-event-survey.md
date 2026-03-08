---
description: Create a pairwise rating survey for a CourtReserve event — full pipeline from registrants to voter links
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Bash(base64:*), Bash(python3:*), Read
argument-hint: "[event name, date, or 'status SESSION_NAME'] — creates pairwise rating session with voter links"
---

Run the full post-event pairwise rating survey pipeline using the `post-event-workflow` skill.

## Parse Arguments

From `$ARGUMENTS`, determine the intent:

- **Event name or date** → full pipeline (Steps 1-6)
- **`status SESSION_NAME`** → check vote status + results (Steps 5 + 7 only)
- **`resend SESSION_NAME`** → re-send links to non-voters (Steps 5 + 6)
- **No arguments** → search recent CR events (Step 1) and ask user to pick

## Environment Check

Verify required env vars are set:
- `COURTRESERVE_ROCKVILLE_USERNAME` (or `NORTHBETHESDA`)
- `COURTRESERVE_ROCKVILLE_PASSWORD`
- `COURTRESERVE_ROCKVILLE_ORG_ID`
- `ADMIN_SECRET`

If missing, report which ones are needed and stop.

## Execute Pipeline

Follow the `post-event-workflow` skill steps. Key decision points where you must pause for user input:

1. **After Step 1**: Confirm which event
2. **After Step 2**: Confirm player list (especially if >12 need subsetting)
3. **After Step 5**: Ask whether to post to Circle or show copy-paste table
4. **Before any Circle post**: Always preview and confirm

## Examples

```
/post-event-survey Round Robin
/post-event-survey March 8
/post-event-survey status "Link & Dink Round Robin — Mar 8"
/post-event-survey resend "Link & Dink Round Robin — Mar 8"
```
