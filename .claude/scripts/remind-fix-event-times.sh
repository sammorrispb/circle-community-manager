#!/usr/bin/env bash
# One-time reminder to run the event time fix script.
# This hook self-deletes after displaying the reminder once.

cat <<'MSG'

╔══════════════════════════════════════════════════════════════╗
║  REMINDER: Run the Circle event time fix script!            ║
║                                                             ║
║  139 Circle events have incorrect times (Eastern stored     ║
║  as UTC, off by 4-5 hours). Run from a machine with        ║
║  internet access:                                           ║
║                                                             ║
║    cd circle-community-manager                              ║
║    # export CIRCLE_API_KEY, CIRCLE_COMMUNITY_ID,            ║
║    # COURTRESERVE_*_USERNAME, COURTRESERVE_*_PASSWORD       ║
║    ./scripts/fix-event-times.sh          # dry run          ║
║    ./scripts/fix-event-times.sh --apply  # apply fixes      ║
║                                                             ║
║  After running successfully, delete this reminder:          ║
║    rm .claude/scripts/remind-fix-event-times.sh             ║
║    and remove the SessionStart hook from                    ║
║    .claude/settings.json                                    ║
╚══════════════════════════════════════════════════════════════╝

MSG
