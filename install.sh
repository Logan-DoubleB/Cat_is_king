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
command -v python3 >/dev/null 2>&1 || { error "python3 is required"; exit 1; }
command -v jq >/dev/null 2>&1 || { error "jq is required (brew install jq)"; exit 1; }
command -v gh >/dev/null 2>&1 || { error "gh (GitHub CLI) is required (brew install gh)"; exit 1; }

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
    warn "Scout is already installed at $SKILL_DIR"
    read -p "Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled."
        exit 0
    fi
fi

info "Installing Scout skill..."

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
    info "  scout-trusted.json already exists, skipping (preserving your trust list)"
fi

# Generate initial system-map.json
info "Generating system-map.json..."
bash "$SCRIPT_DIR/scan-system.sh" >/dev/null 2>&1 && \
    info "  system-map.json generated" || \
    warn "  system-map.json generation failed (run /scout --init later)"

# Cleanup temp dir if needed
if [ "$CLEANUP_TMP" = true ] && [ -n "${TMPDIR:-}" ]; then
    rm -rf "$TMPDIR"
fi

echo ""
info "Installation complete!"
echo ""
echo "  Usage:"
echo "    /scout <github-url>           # Evaluate + install"
echo "    /scout <github-url> --dry-run # Evaluate only"
echo "    /scout --init                 # Regenerate system map"
echo "    /scout --undo                 # Rollback last install"
echo "    /scout --status               # Install history"
echo ""
