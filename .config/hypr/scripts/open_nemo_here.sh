#!/bin/bash

active_window=$(hyprctl activewindow -j 2>/dev/null)

# Only proceed if it's Alacritty
if echo "$active_window" | jq -e '.class == "Alacritty"' >/dev/null 2>&1; then
    title=$(echo "$active_window" | jq -r '.title')

    # Extract directory from title (same logic as your working script)
    if [[ "$title" =~ :[[:space:]]*(.+) ]]; then
        cwd="${BASH_REMATCH[1]}"

        # Expand ~ to $HOME
        if [[ "$cwd" == "~"* ]]; then
            cwd="${cwd/#~/$HOME}"
        fi

        if [ -d "$cwd" ]; then
            nemo "$cwd" &
            exit 0
        fi
    fi

    # Fallback: PID method
    pid=$(echo "$active_window" | jq -r '.pid')

    if [ -d "/proc/$pid" ]; then
        cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null)

        if [ -d "$cwd" ]; then
            nemo "$cwd" &
            exit 0
        fi
    fi
fi

# Final fallback (optional): open default
nemo &
