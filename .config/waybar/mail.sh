#!/bin/bash
# Unread SU inbox count for waybar. The tooltip shows the newest few; clicking
# the module opens aerc (see on-click in config.jsonc).

QUERY='folder:su/INBOX and tag:unread'
COUNT=$(notmuch count "$QUERY" 2>/dev/null) || COUNT=0

if [ "$COUNT" -gt 0 ]; then
    TEXT="  $COUNT"
    CLASS="unread"
    TOOLTIP=$(notmuch search --sort=newest-first --limit=5 --format=json "$QUERY" 2>/dev/null |
        jq -r '.[] | "\(.authors | @html) — \(.subject | @html)"')
    [ "$COUNT" -gt 5 ] && TOOLTIP="$TOOLTIP"$'\n'"…and $((COUNT - 5)) more"
else
    TEXT=""
    CLASS="read"
    TOOLTIP="No unread mail"
fi

jq -nc --arg text "$TEXT" --arg tooltip "$TOOLTIP" --arg class "$CLASS" \
    '{text: $text, tooltip: $tooltip, class: $class}'
