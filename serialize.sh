#!/bin/bash
# Serialize Lua mod files into URL-safe base64 strings for BAR lobby commands.
# Usage: ./serialize.sh [file.lua]  (defaults to mod.lua)
# Output can be used with: !bset tweakdefs0 <base64_string>
#
# Requires: npm install -g luamin

FILE="${1:-mod.lua}"

if [ ! -f "$FILE" ]; then
    echo "Error: $FILE not found" >&2
    exit 1
fi

if ! command -v luamin &> /dev/null; then
    echo "Error: luamin not found. Install with: npm install -g luamin" >&2
    exit 1
fi

HEADERS=$(sed -n '/^--/p; /^--/!q' "$FILE")
BODY=$(luamin -c < "$FILE")

printf '%s\n%s' "$HEADERS" "$BODY" | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='
echo
