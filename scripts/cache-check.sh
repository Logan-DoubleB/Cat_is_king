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

# Extract stored hash (env var, no shell interpolation into Python)
export SCOUT_MAP="$MAP"
STORED_HASH=$(python3 - <<'PYEOF'
import json, os
with open(os.environ['SCOUT_MAP']) as f:
    print(json.load(f).get('cache_hash', 'none'))
PYEOF
) || STORED_HASH="none"

# Recompute hash from file list (names only, same algorithm as scan-system.sh)
HASH_INPUT=""
for dir in "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/plugins"; do
    if [ -d "$dir" ]; then
        HASH_INPUT+="$(find "$dir" -name '*.md' -type f 2>/dev/null | sort)"
    fi
done
# Cross-platform SHA256
compute_sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | cut -d' ' -f1
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum | cut -d' ' -f1
    else
        python3 -c 'import hashlib,sys;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'
    fi
}
CURRENT_HASH="sha256:$(echo "$HASH_INPUT" | compute_sha256)"

if [ "$STORED_HASH" = "$CURRENT_HASH" ]; then
    echo "VALID"
else
    echo "STALE"
fi
