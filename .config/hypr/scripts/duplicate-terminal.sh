#!/bin/bash

active_window=$(hyprctl activewindow -j 2>/dev/null)

if echo "$active_window" | jq -e '.class == "Alacritty"' >/dev/null 2>&1; then
    title=$(echo "$active_window" | jq -r '.title')
    
    # Try to extract the directory from the title
    # Alacritty titles often follow the pattern: "user@host: /current/directory"
    if [[ "$title" =~ :[[:space:]]*(.+) ]]; then
        cwd="${BASH_REMATCH[1]}"
        
        # Handle tilde expansion for home directory
        if [[ "$cwd" == "~"* ]]; then
            cwd="${cwd/#~/$HOME}"
        fi
        
        if [ -d "$cwd" ]; then
            alacritty --working-directory "$cwd"
            exit 0
        fi
    fi
    
    # If we couldn't extract from title, try a different approach
    # Get the PID of the active terminal
    pid=$(echo "$active_window" | jq -r '.pid')
    
    if [ -d "/proc/$pid" ]; then
        # Try to get the current working directory
        cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null)
        
        if [ -d "$cwd" ]; then
            alacritty --working-directory "$cwd"
            exit 0
        fi
    fi
fi
