#!/bin/bash
# install.sh — One-click installer for Scout skill
# Usage: curl -fsSL https://raw.githubusercontent.com/Logan-DoubleB/Cat_is_king/main/install.sh | bash
#   or:  git clone https://github.com/Logan-DoubleB/Cat_is_king.git && cd Cat_is_king && bash install.sh
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SKILL_DIR="$CLAUDE_DIR/skills/scout"
CMD_DIR="$CLAUDE_DIR/commands"
SCRIPT_DIR="$SKILL_DIR/scripts"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[scout]${NC} $1"; }
warn()  { echo -e "${YELLOW}[scout]${NC} $1"; }
error() { echo -e "${RED}[scout]${NC} $1" >&2; }

# Check prerequisites
MISSING=""
command -v python3 >/dev/null 2>&1 || MISSING="$MISSING python3"
command -v jq >/dev/null 2>&1 || MISSING="$MISSING jq"
command -v gh >/dev/null 2>&1 || MISSING="$MISSING gh"
command -v git >/dev/null 2>&1 || MISSING="$MISSING git"

if [ -n "$MISSING" ]; then
    error "필수 도구가 설치되어 있지 않습니다:$MISSING"
    echo ""
    echo "  macOS:  brew install$MISSING"
    echo "  Ubuntu: sudo apt install$MISSING"
    echo "  Arch:   sudo pacman -S$MISSING"
    echo ""
    echo "  gh (GitHub CLI) 설치 후: gh auth login"
    exit 1
fi

# Check gh auth
if ! gh auth status >/dev/null 2>&1; then
    warn "gh가 로그인되어 있지 않습니다. 먼저 실행하세요: gh auth login"
    warn "로그인 없이도 설치는 가능하지만 GitHub metrics 수집이 제한됩니다."
fi

# Determine source directory (where this script lives)
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

# If running via curl pipe, clone to temp dir first
if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
    info "Cloning Cat_is_king..."
    TMPDIR=$(mktemp -d)
    git clone --depth 1 https://github.com/Logan-DoubleB/Cat_is_king.git "$TMPDIR/Cat_is_king" 2>/dev/null
    SOURCE_DIR="$TMPDIR/Cat_is_king"
    CLEANUP_TMP=true
else
    CLEANUP_TMP=false
fi

# Check for existing installation
if [ -d "$SKILL_DIR" ]; then
    warn "Scout가 이미 설치되어 있습니다: $SKILL_DIR"
    read -p "덮어쓸까요? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "취소되었습니다."
        exit 0
    fi
fi

info "Scout 스킬 설치 중..."

# Create directories
mkdir -p "$SKILL_DIR" "$SCRIPT_DIR" "$CMD_DIR"

# Copy skill definition
cp "$SOURCE_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
info "  SKILL.md -> $SKILL_DIR/"

# Copy command
cp "$SOURCE_DIR/scout.md" "$CMD_DIR/scout.md"
info "  scout.md -> $CMD_DIR/"

# Copy scripts
for script in "$SOURCE_DIR"/scripts/*.sh; do
    cp "$script" "$SCRIPT_DIR/"
    chmod +x "$SCRIPT_DIR/$(basename "$script")"
done
info "  scripts/ -> $SCRIPT_DIR/scripts/"

# Copy default trust list (only if not already present)
if [ ! -f "$SKILL_DIR/scout-trusted.json" ]; then
    cp "$SOURCE_DIR/scout-trusted.json" "$SKILL_DIR/scout-trusted.json"
    info "  scout-trusted.json -> $SKILL_DIR/ (default)"
else
    info "  scout-trusted.json 이미 존재 — 기존 trust list 유지"
fi

# Generate initial system-map.json
info "system-map.json 생성 중..."
bash "$SCRIPT_DIR/scan-system.sh" >/dev/null 2>&1 && \
    info "  system-map.json 생성 완료" || \
    warn "  system-map.json 생성 실패 (나중에 /scout --init 실행하세요)"

# Cleanup temp dir if needed
if [ "$CLEANUP_TMP" = true ] && [ -n "${TMPDIR:-}" ]; then
    rm -rf "$TMPDIR"
fi

echo ""
info "설치 완료!"
echo ""
echo "  사용법:"
echo "    /scout <github-url>           # 평가 + 설치"
echo "    /scout <github-url> --dry-run # 평가만"
echo "    /scout --init                 # 시스템 맵 재생성"
echo "    /scout --undo                 # 최근 설치 롤백"
echo "    /scout --status               # 설치 이력"
echo ""
