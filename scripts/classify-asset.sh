#!/bin/bash
# classify-asset.sh — Detect asset type from fetched content
# Input: path to fetched content
# Output: JSON with type and confidence
set -euo pipefail

TARGET="$1"

# Handle single file input
if [ -f "$TARGET" ] && [ ! -d "$TARGET" ]; then
    FILENAME=$(basename "$TARGET")
    if [[ "$FILENAME" == "SKILL.md" ]]; then
        echo '{"type":"skill","confidence":0.95,"evidence":"Single SKILL.md file"}'
    elif grep -q "^allowed_tools:" "$TARGET" 2>/dev/null || grep -q "^command:" "$TARGET" 2>/dev/null; then
        echo '{"type":"command","confidence":0.9,"evidence":"frontmatter with allowed_tools or command"}'
    elif grep -q "^tools:" "$TARGET" 2>/dev/null && grep -q "^model:" "$TARGET" 2>/dev/null; then
        echo '{"type":"agent","confidence":0.9,"evidence":"frontmatter with tools and model"}'
    else
        echo '{"type":"unknown","confidence":0.0,"evidence":"single file, no recognized pattern"}'
    fi
    exit 0
fi

# Directory input — check patterns in priority order

# 1. Plugin check
if [ -f "$TARGET/.claude-plugin/plugin.json" ] || [ -f "$TARGET/plugin.json" ]; then
    echo '{"type":"plugin","confidence":1.0,"evidence":".claude-plugin/plugin.json found"}'
    exit 0
fi

# 2. SKILL.md check
SKILL_FILES=$(find "$TARGET" -name "SKILL.md" -type f 2>/dev/null || true)
if [ -n "$SKILL_FILES" ]; then
    COUNT=$(echo "$SKILL_FILES" | wc -l | tr -d ' ')
    if [ "$COUNT" -eq 1 ]; then
        echo "{\"type\":\"skill\",\"confidence\":0.95,\"evidence\":\"Single SKILL.md found\",\"path\":\"$SKILL_FILES\"}"
    else
        echo "{\"type\":\"skill_bundle\",\"confidence\":0.9,\"evidence\":\"${COUNT} SKILL.md files found\",\"count\":$COUNT}"
    fi
    exit 0
fi

# 3. Command check — frontmatter with allowed_tools
CMD_FILES=$(grep -rl "^allowed_tools:" "$TARGET"/*.md 2>/dev/null || grep -rl "^command:" "$TARGET"/*.md 2>/dev/null || true)
if [ -n "$CMD_FILES" ]; then
    COUNT=$(echo "$CMD_FILES" | wc -l | tr -d ' ')
    echo "{\"type\":\"command\",\"confidence\":0.9,\"evidence\":\"${COUNT} command file(s) with allowed_tools\",\"count\":$COUNT}"
    exit 0
fi

# 4. Agent check — frontmatter with tools: and model:
AGENT_FILES=""
for f in "$TARGET"/*.md; do
    [ -f "$f" ] || continue
    if grep -q "^tools:" "$f" 2>/dev/null && grep -q "^model:" "$f" 2>/dev/null; then
        AGENT_FILES="$AGENT_FILES $f"
    fi
done
if [ -n "$AGENT_FILES" ]; then
    echo '{"type":"agent","confidence":0.9,"evidence":"frontmatter with tools and model fields"}'
    exit 0
fi

# 5. Rules directory structure
if [ -d "$TARGET/common" ] || [ -d "$TARGET/rules" ]; then
    echo '{"type":"rule_set","confidence":0.8,"evidence":"rules directory structure detected"}'
    exit 0
fi

# 6. Check for nested skills in subdirectories
NESTED_SKILLS=$(find "$TARGET" -mindepth 2 -name "SKILL.md" -type f 2>/dev/null || true)
if [ -n "$NESTED_SKILLS" ]; then
    COUNT=$(echo "$NESTED_SKILLS" | wc -l | tr -d ' ')
    echo "{\"type\":\"skill_bundle\",\"confidence\":0.85,\"evidence\":\"${COUNT} nested SKILL.md files\",\"count\":$COUNT}"
    exit 0
fi

# 7. Fallback
echo '{"type":"unknown","confidence":0.0,"evidence":"no recognized patterns — ask user"}'
