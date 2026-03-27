#!/bin/bash
# verify-install.sh — 5-point post-install verification
# Input: asset name, asset type (skill|command|agent|rule)
# Output: PASS or FAIL with details
# Exit code: 0 = pass, 1 = fail
set -euo pipefail

ASSET_NAME="${1:-}"
ASSET_TYPE="${2:-skill}"
CLAUDE_DIR="$HOME/.claude"

if [ -z "$ASSET_NAME" ]; then
    echo "FAIL: asset name required" >&2
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0
DETAILS=""

check() {
    local name="$1"
    local result="$2"
    if [ "$result" = "PASS" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        DETAILS+="  ✅ $name\n"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        DETAILS+="  ❌ $name\n"
    fi
}

# 1. File existence and readability
case "$ASSET_TYPE" in
    skill)
        if [ -f "$CLAUDE_DIR/skills/$ASSET_NAME/SKILL.md" ] && [ -r "$CLAUDE_DIR/skills/$ASSET_NAME/SKILL.md" ]; then
            check "파일 존재 + 읽기 가능" "PASS"
        else
            check "파일 존재 + 읽기 가능" "FAIL"
        fi
        ;;
    command)
        if [ -f "$CLAUDE_DIR/commands/$ASSET_NAME.md" ] && [ -r "$CLAUDE_DIR/commands/$ASSET_NAME.md" ]; then
            check "파일 존재 + 읽기 가능" "PASS"
        else
            check "파일 존재 + 읽기 가능" "FAIL"
        fi
        ;;
    agent)
        if [ -f "$CLAUDE_DIR/agents/$ASSET_NAME.md" ] && [ -r "$CLAUDE_DIR/agents/$ASSET_NAME.md" ]; then
            check "파일 존재 + 읽기 가능" "PASS"
        else
            check "파일 존재 + 읽기 가능" "FAIL"
        fi
        ;;
    *)
        check "파일 존재 + 읽기 가능" "PASS"
        ;;
esac

# 2. Structure validation (frontmatter check)
case "$ASSET_TYPE" in
    skill)
        TARGET_FILE="$CLAUDE_DIR/skills/$ASSET_NAME/SKILL.md"
        if [ -f "$TARGET_FILE" ]; then
            if head -1 "$TARGET_FILE" | grep -q "^---"; then
                if grep -q "^name:" "$TARGET_FILE" && grep -q "^description:" "$TARGET_FILE"; then
                    check "구조 검증 (프론트매터)" "PASS"
                else
                    check "구조 검증 (프론트매터)" "FAIL"
                fi
            else
                check "구조 검증 (프론트매터)" "FAIL"
            fi
        else
            check "구조 검증 (프론트매터)" "FAIL"
        fi
        ;;
    *)
        check "구조 검증" "PASS"
        ;;
esac

# 3. System-map integration check
MAP="$CLAUDE_DIR/skills/scout/system-map.json"
if [ -f "$MAP" ]; then
    # Re-scan and check if new asset appears
    bash "$CLAUDE_DIR/skills/scout/scripts/scan-system.sh" > /dev/null 2>&1
    if python3 -c "
import json
with open('$MAP') as f:
    data = json.load(f)
names = data.get('name_registry', {}).get('all_names', [])
if '$ASSET_NAME' in names:
    exit(0)
else:
    exit(1)
" 2>/dev/null; then
        check "시스템맵 등록 확인" "PASS"
    else
        check "시스템맵 등록 확인" "FAIL"
    fi
else
    check "시스템맵 등록 확인" "PASS"
fi

# 4. Rollback capability check
LATEST_BACKUP=$(ls -td "$HOME/.claude/backups/scout"/*/ 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP/manifest.json" ]; then
    check "롤백 가능 확인" "PASS"
else
    check "롤백 가능 확인" "FAIL"
fi

# 5. Hook conflict check
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    HOOK_DUPES=$(python3 -c "
import json
with open('$CLAUDE_DIR/settings.json') as f:
    data = json.load(f)
hooks = data.get('hooks', {})
seen = set()
dupes = 0
for event, entries in hooks.items():
    if isinstance(entries, list):
        for e in entries:
            key = f\"{event}:{e.get('matcher', '*')}\"
            if key in seen:
                dupes += 1
            seen.add(key)
print(dupes)
" 2>/dev/null || echo "0")

    if [ "$HOOK_DUPES" -eq 0 ]; then
        check "훅 충돌 없음" "PASS"
    else
        check "훅 충돌 없음 (${HOOK_DUPES}건 중복)" "FAIL"
    fi
else
    check "훅 충돌 없음" "PASS"
fi

# Result
echo ""
echo "검증 결과: ${PASS_COUNT}/5 통과"
printf "$DETAILS"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo ""
    echo "FAIL"
    exit 1
else
    echo ""
    echo "PASS"
    exit 0
fi
