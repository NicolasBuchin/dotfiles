#!/bin/bash

COUNT=$(swaync-client --count)

if [ "$COUNT" -gt 0 ]; then
    ICON=" "
else
    ICON=" "
fi

if [ "$COUNT" -eq 0 ]; then
    TOOLTIP="No notifications"
elif [ "$COUNT" -eq 1 ]; then
    TOOLTIP="1 notification"
else
    TOOLTIP="$COUNT notifications"
fi

echo "{\"text\":\"$ICON\", \"tooltip\":\"$TOOLTIP\"}"
