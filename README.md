# Circle Community Manager

A Claude Code plugin for managing your Circle.so community directly from conversations. Invite members, create events, publish posts, check RSVPs, and analyze engagement — all without leaving the terminal.

## Prerequisites

Set these environment variables before use:

```bash
export CIRCLE_API_KEY="your-circle-admin-api-v2-token"
export CIRCLE_COMMUNITY_ID="your-numeric-community-id"
```

**Getting your API key:** Circle Admin Settings > API > Generate Admin API v2 token

**Getting your Community ID:** Visible in Circle admin API responses or URL patterns

## Installation

```bash
claude --plugin-dir /path/to/circle-community-manager
```

Or add to `~/.claude/settings.json`:

```json
{
  "plugins": ["/path/to/circle-community-manager"]
}
```

## Commands

| Command | Description |
|---------|-------------|
| `/circle-members` | List, search, invite members, manage space memberships |
| `/circle-events` | List, create, update events, manage RSVPs |
| `/circle-posts` | List, create, comment on posts in spaces |
| `/circle-health` | Community snapshot: spaces, member count, recent events |
| `/cr-to-circle` | Sync CourtReserve events to Circle (tournaments + Next Gen) |
| `/circle-playdate-invite` | Create a post with Play Date invite links for event attendees |

### Examples

```
/circle-members search john
/circle-members invite john@example.com
/circle-events upcoming
/circle-events create Thursday mixer at 6pm at Rockville
/circle-posts list in Events
/circle-posts announce "Spring Tournament Results" in Tournaments
/circle-playdate-invite Thursday Round Robin
/circle-health
/cr-to-circle both 30
```

## Skills

Skills activate automatically when Claude detects relevant context:

- **circle-setup** — Validates environment and tests API connectivity
- **circle-members** — Member CRUD, search, space management, bulk operations, Headless API
- **circle-events** — Event CRUD, attendee management patterns
- **circle-posts** — Post/comment CRUD, announcements, Play Date invite links
- **cr-to-circle** — CourtReserve → Circle event sync with dedup

## Agent

The **circle-manager** agent handles multi-step operations that span multiple API calls:

- "Invite these 5 people and add them to the Events space"
- "Add everyone from last week's mixer to next Thursday's event"
- "Show me members in Rockville but not in Events space"
- "Post the tournament results in the Tournaments space"
- "Create Play Date invite links for Thursday's event attendees"

## Architecture

This plugin uses **skills-over-MCP**: skills teach Claude the Circle API patterns, and Claude executes them via `curl` in Bash. No separate server process, no runtime dependencies, fully portable.

## API Coverage

| Domain | Operations | Status |
|--------|-----------|--------|
| Members | List, search, get, invite, update, remove, ban | ✅ Full |
| Spaces | List, get, list members, add/remove members | ✅ Full |
| Events | List, get, create, update, delete | ✅ Full |
| Attendees | List, add, remove | ✅ Full |
| Posts | List, get, create, update, delete | ✅ Full |
| Comments | List, create, delete | ✅ Full |
| Topics | List (via space object) | ✅ Read-only |
| CR → Circle Sync | Event sync with dedup | ✅ Full |
| Headless Auth | JWT token generation for member-level APIs | 📝 Documented |
| DMs / Chat | Not available in Admin API v2 | ❌ Not supported |

### API Endpoint Reference

| Resource | Endpoint Path |
|----------|--------------|
| Members | `/community_members` |
| Spaces | `/spaces` |
| Space Members | `/space_members` |
| Events | `/events` |
| Attendees | `/event_attendees` |
| Posts | `/posts` ⚠️ (do NOT include `community_id`) |
| Comments | `/comments` ⚠️ (do NOT include `community_id`) |

### Authentication

- **Admin API v2**: `Authorization: Token $CIRCLE_API_KEY`
- **Headless API**: `Authorization: Bearer $CIRCLE_API_KEY` (for JWT generation)

### Known Limitations

- **No DM/Chat API**: The Admin API v2 does not expose endpoints for direct messages, chat rooms, or chat room messages. These return 404.
- **Topics are read-only**: Topic IDs can be read from space objects and attached to posts, but topics cannot be created/deleted via API — use the Circle web UI.
- **Rate limiting**: Circle enforces per-token rate limits. After bulk writes (100+ calls), the API may return 401 "API token not found" on subsequent reads for 5-10 minutes. Rapid-fire requests to non-existent endpoints can trigger permanent token revocation — probe unknown endpoints at max 1 request per 3 seconds, max 3 per session.
- **Post body is HTML**: The `body` field in posts accepts HTML content, not plain text or Markdown.
