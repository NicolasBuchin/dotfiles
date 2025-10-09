#!/bin/bash

CONFIG_DIR="$HOME/.config/nvim"
OUTPUT_FILE="conf_dump.txt"

echo "" > "$OUTPUT_FILE"  # clear previous content

# Dump init.lua
if [[ -f "$CONFIG_DIR/init.lua" ]]; then
    echo "init.lua:" >> "$OUTPUT_FILE"
    cat "$CONFIG_DIR/init.lua" >> "$OUTPUT_FILE"
    echo -e "\n" >> "$OUTPUT_FILE"
fi

# Recursively find all .lua files under lua/ and dump them
find "$CONFIG_DIR/lua" -type f -name "*.lua" | while read -r file; do
    rel_path="${file#$CONFIG_DIR/}"
    echo "$rel_path:" >> "$OUTPUT_FILE"
    cat "$file" >> "$OUTPUT_FILE"
    echo -e "\n" >> "$OUTPUT_FILE"
done

echo "Dump complete"

