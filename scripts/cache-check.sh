#!/bin/bash
# cache-check.sh — Check if system-map.json is still valid
# Output: "VALID" or "STALE"
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
MAP="$CLAUDE_DIR/skills/scout/system-map.json"

if [ ! -f "$MAP" ]; then
    echo "STALE"
    exit 0
fi

# Extract stored hash
STORED_HASH=$(python3 -c "
import json
with open('$MAP') as f:
    print(json.load(f).get('cache_hash', 'none'))
" 2>/dev/null || echo "none")

# Recompute hash from file list (names only, same algorithm as scan-system.sh)
HASH_INPUT=""
for dir in "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/plugins"; do
    if [ -d "$dir" ]; then
        HASH_INPUT+="$(find "$dir" -name '*.md' -type f 2>/dev/null | sort)"
    fi
done
CURRENT_HASH="sha256:$(echo "$HASH_INPUT" | shasum -a 256 | cut -d' ' -f1)"

if [ "$STORED_HASH" = "$CURRENT_HASH" ]; then
    echo "VALID"
else
    echo "STALE"
fi
