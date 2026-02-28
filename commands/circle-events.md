---
description: Quick Circle.so event operations — list, create, RSVPs, attendee management
allowed-tools: Bash(curl:*), Bash(jq:*), Bash(echo:*), Bash(date:*), Read
argument-hint: [action] [details...]
---

Perform Circle.so event operations. Use the circle-events skill for API endpoint patterns and curl templates.

First, validate that `$CIRCLE_API_KEY` and `$CIRCLE_COMMUNITY_ID` environment variables are set. If either is missing, activate the circle-setup skill to guide configuration.

Interpret the user's request from the arguments: $ARGUMENTS

Common actions to recognize:
- **list** / **upcoming** — List upcoming events
- **past** — List past events
- **create [details]** — Create a new event (parse natural language for date, time, location)
- **rsvps [event name/id]** — Show who RSVPed to an event
- **add-attendee [member] to [event]** — Add a member as an attendee
- **update [event] [changes]** — Update event details
- **delete [event]** — Delete an event (requires confirmation)

If no arguments provided, list upcoming events by default.

For event creation from natural language (e.g., "Thursday mixer at 6pm at Rockville"):
1. Parse the date and convert to ISO 8601
2. List spaces to find the appropriate space_id
3. Confirm the interpreted details with the user before creating
4. Create the event and report the result

For all API calls, use curl with the patterns from the circle-events skill. Parse responses with jq and present results in clean, readable format.

Always confirm before deleting events.
