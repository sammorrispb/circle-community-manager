# Circle Community Manager

A Claude Code plugin for managing your Circle.so community directly from conversations. Invite members, create events, check RSVPs, and analyze engagement — all without leaving the terminal.

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
| `/circle-health` | Community snapshot: spaces, member count, recent events |

### Examples

```
/circle-members search john
/circle-members invite john@example.com
/circle-events upcoming
/circle-events create Thursday mixer at 6pm at Rockville
/circle-health
```

## Skills

Skills activate automatically when Claude detects relevant context:

- **circle-setup** — Validates environment and tests API connectivity
- **circle-members** — Member CRUD, search, space management patterns
- **circle-events** — Event CRUD, attendee management patterns

## Agent

The **circle-manager** agent handles multi-step operations that span multiple API calls:

- "Invite these 5 people and add them to the Events space"
- "Add everyone from last week's mixer to next Thursday's event"
- "Show me members in Rockville but not in Events space"

## Architecture

This plugin uses **skills-over-MCP**: skills teach Claude the Circle API patterns, and Claude executes them via `curl` in Bash. No separate server process, no runtime dependencies, fully portable.

## API Coverage

| Domain | Operations |
|--------|-----------|
| Members | List, search, get, invite, update, remove, ban |
| Spaces | List, get, list members, add/remove members |
| Events | List, get, create, update, delete |
| Attendees | List, add, remove |
