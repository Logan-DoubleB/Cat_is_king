#!/bin/bash
# fetch-target.sh — Fetch a GitHub asset to a local temp directory
# Input: GitHub URL (various patterns supported)
# Output: local path to fetched content
set -euo pipefail

URL="$1"
WORKDIR=$(mktemp -d /tmp/scout-XXXXXXXXXX)

# Normalize URL
URL="${URL%.git}"
URL="${URL%/}"

# Add https://github.com/ prefix if short form (user/repo)
if [[ "$URL" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ ]]; then
    URL="https://github.com/$URL"
fi

# Security: only allow GitHub hosts
if [[ ! "$URL" =~ ^https://(github\.com|raw\.githubusercontent\.com|gist\.github\.com)/ ]]; then
    echo "ERROR: GitHub URL만 허용됩니다 (github.com / raw.githubusercontent.com / gist.github.com)" >&2
    rm -rf "$WORKDIR"
    exit 1
fi

# Detect URL type and fetch
if [[ "$URL" =~ gist\.github\.com ]]; then
    # Gist
    gh gist clone "$URL" "$WORKDIR/repo" 2>/dev/null || \
    git clone --depth 1 "$URL.git" "$WORKDIR/repo" 2>/dev/null || \
    { echo "ERROR: gist clone 실패" >&2; exit 1; }
    echo "$WORKDIR/repo"

elif [[ "$URL" =~ /blob/ ]]; then
    # Single file — convert to raw URL
    RAW_URL=$(echo "$URL" | sed 's|github.com|raw.githubusercontent.com|' | sed 's|/blob/|/|')
    FILENAME=$(basename "$URL")
    curl -fsSL "$RAW_URL" -o "$WORKDIR/$FILENAME" 2>/dev/null || \
    { echo "ERROR: 파일 다운로드 실패" >&2; exit 1; }
    echo "$WORKDIR/$FILENAME"

elif [[ "$URL" =~ /tree/ ]]; then
    # Subdirectory — sparse checkout
    REPO=$(echo "$URL" | sed -E 's|(https://github.com/[^/]+/[^/]+)/tree/[^/]+/(.*)|\1|')
    SUBPATH=$(echo "$URL" | sed -E 's|https://github.com/[^/]+/[^/]+/tree/[^/]+/(.*)|\1|')
    git clone --depth 1 --filter=blob:none --sparse "$REPO.git" "$WORKDIR/repo" 2>/dev/null && \
    cd "$WORKDIR/repo" && \
    git sparse-checkout set "$SUBPATH" 2>/dev/null || \
    { echo "ERROR: sparse checkout 실패" >&2; exit 1; }
    echo "$WORKDIR/repo/$SUBPATH"

elif [[ "$URL" =~ raw\.githubusercontent\.com ]]; then
    # Raw URL
    FILENAME=$(basename "$URL")
    curl -fsSL "$URL" -o "$WORKDIR/$FILENAME" 2>/dev/null || \
    { echo "ERROR: raw 다운로드 실패" >&2; exit 1; }
    echo "$WORKDIR/$FILENAME"

else
    # Full repo
    git clone --depth 1 "$URL.git" "$WORKDIR/repo" 2>/dev/null || \
    gh repo clone "$URL" "$WORKDIR/repo" -- --depth 1 2>/dev/null || \
    { echo "ERROR: repo clone 실패 — gh auth login 필요할 수 있습니다" >&2; exit 1; }
    echo "$WORKDIR/repo"
fi
