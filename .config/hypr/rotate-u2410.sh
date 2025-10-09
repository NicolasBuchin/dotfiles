#!/bin/bash

TARGET_SERIAL="F525M1B7ANNL"

hyprctl monitors -j | jq -c '.[]' | while read -r monitor; do
    serial=$(echo "$monitor" | jq -r '.serial')
    name=$(echo "$monitor" | jq -r '.name')

    if [ "$serial" == "$TARGET_SERIAL" ]; then
        hyprctl keyword monitor "$name,1920x1200,auto,1,transform,1"
    fi
done

