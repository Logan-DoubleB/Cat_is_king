#!/bin/bash
# scan-system.sh — Generate system-map.json by scanning all asset directories
# Output: path to generated system-map.json
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
OUTPUT="$CLAUDE_DIR/skills/scout/system-map.json"

# Compute cache hash from file list (names only, not mtimes)
HASH_INPUT=""
for dir in "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/plugins"; do
    if [ -d "$dir" ]; then
        HASH_INPUT+="$(find "$dir" -name '*.md' -type f 2>/dev/null | sort)"
    fi
done
# Cross-platform SHA256 (macOS: shasum, Linux: sha256sum)
if command -v shasum >/dev/null 2>&1; then
    SHA_CMD="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
    SHA_CMD="sha256sum"
else
    SHA_CMD="python3 -c 'import hashlib,sys;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'"
fi
CACHE_HASH="sha256:$(echo "$HASH_INPUT" | eval $SHA_CMD | cut -d' ' -f1)"

# --- Skills: local + plugin sources, deduplicated ---
SKILL_NAMES=$(
{
    # Local skills
    find "$CLAUDE_DIR/skills" -name "SKILL.md" -type f 2>/dev/null | while read -r f; do
        basename "$(dirname "$f")"
    done
    # Plugin cache skills
    find "$CLAUDE_DIR/plugins/cache" -path "*/skills/*/SKILL.md" -type f 2>/dev/null | while read -r f; do
        basename "$(dirname "$f")"
    done
    # Marketplace plugin skills
    find "$CLAUDE_DIR/plugins/marketplaces" -path "*/skills/*/SKILL.md" -type f 2>/dev/null | while read -r f; do
        basename "$(dirname "$f")"
    done
} | sort -u | jq -R . | jq -s .
)
SKILL_COUNT=$(echo "$SKILL_NAMES" | jq 'length')

# --- Commands: local + plugin sources, deduplicated ---
COMMAND_NAMES=$(
{
    # Local commands
    find "$CLAUDE_DIR/commands" -name "*.md" -type f 2>/dev/null | while read -r f; do
        basename "$f" .md
    done
    # Plugin cache commands
    find "$CLAUDE_DIR/plugins/cache" -path "*/commands/*.md" -type f 2>/dev/null | while read -r f; do
        basename "$f" .md
    done
    # Marketplace plugin commands
    find "$CLAUDE_DIR/plugins/marketplaces" -path "*/commands/*.md" -type f 2>/dev/null | while read -r f; do
        basename "$f" .md
    done
} | sort -u | jq -R . | jq -s .
)
COMMAND_COUNT=$(echo "$COMMAND_NAMES" | jq 'length')

# --- Agents: local + plugin sources, deduplicated ---
AGENT_NAMES=$(
{
    # Local agents
    find "$CLAUDE_DIR/agents" -name "*.md" -type f 2>/dev/null | while read -r f; do
        basename "$f" .md
    done
    # Plugin cache agents
    find "$CLAUDE_DIR/plugins/cache" -path "*/agents/*.md" -type f 2>/dev/null | while read -r f; do
        basename "$f" .md
    done
    # Marketplace plugin agents
    find "$CLAUDE_DIR/plugins/marketplaces" -path "*/agents/*.md" -type f 2>/dev/null | while read -r f; do
        basename "$f" .md
    done
} | sort -u | jq -R . | jq -s .
)
AGENT_COUNT=$(echo "$AGENT_NAMES" | jq 'length')

# --- Rules ---
RULE_COUNT=$(find "$CLAUDE_DIR/rules" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

# --- Plugins: count from installed_plugins.json ---
PLUGIN_COUNT=0
if [ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ]; then
    PLUGIN_COUNT=$(python3 -c "
import json
with open('$CLAUDE_DIR/plugins/installed_plugins.json') as f:
    data = json.load(f)
# v2 format has {version, plugins: {name: [...]}}
plugins = data.get('plugins', data) if isinstance(data, dict) else data
if isinstance(plugins, dict):
    # Skip non-plugin keys like 'version'
    count = sum(1 for k, v in plugins.items() if isinstance(v, list) and len(v) > 0)
    print(count)
else:
    print(0)
" 2>/dev/null || echo "0")
fi

# All names combined for collision detection
ALL_NAMES=$(echo "$SKILL_NAMES $COMMAND_NAMES $AGENT_NAMES" | jq -s 'add | unique')

# --- Hooks: settings.json + hooks.json + standalone hook files ---
HOOKS_SUMMARY=$(python3 -c "
import json, os, glob

result = []
claude_dir = os.path.expanduser('~/.claude')

# 1. settings.json hooks
settings_path = os.path.join(claude_dir, 'settings.json')
if os.path.isfile(settings_path):
    with open(settings_path) as f:
        data = json.load(f)
    for event, entries in data.get('hooks', {}).items():
        if isinstance(entries, list):
            for e in entries:
                for h in e.get('hooks', []):
                    cmd = h.get('command', '')[:80]
                    result.append({'event': event, 'matcher': e.get('matcher', '*'), 'command_snippet': cmd, 'source': 'settings.json'})

# 2. ~/.claude/hooks/hooks.json (ECC)
ecc_hooks = os.path.join(claude_dir, 'hooks', 'hooks.json')
if os.path.isfile(ecc_hooks):
    with open(ecc_hooks) as f:
        data = json.load(f)
    for event, entries in data.get('hooks', {}).items():
        if isinstance(entries, list):
            for e in entries:
                for h in e.get('hooks', []):
                    cmd = h.get('command', '')[:80]
                    result.append({'event': event, 'matcher': e.get('matcher', '*'), 'command_snippet': cmd, 'source': 'hooks.json'})

# 3. Standalone hook files in ~/.claude/hooks/ (not .json, not .py, not .sh helper scripts)
hooks_dir = os.path.join(claude_dir, 'hooks')
if os.path.isdir(hooks_dir):
    for f in os.listdir(hooks_dir):
        fpath = os.path.join(hooks_dir, f)
        if os.path.isfile(fpath) and not f.endswith(('.json', '.py', '.sh', '.md')):
            result.append({'event': f, 'matcher': '*', 'command_snippet': f'standalone:{f}', 'source': 'hook-file'})

# 4. Plugin hooks
for hooks_file in glob.glob(os.path.join(claude_dir, 'plugins', 'marketplaces', '*', 'plugin', 'hooks', 'hooks.json')):
    plugin_name = hooks_file.split('/marketplaces/')[1].split('/')[0] if '/marketplaces/' in hooks_file else 'unknown'
    with open(hooks_file) as f:
        data = json.load(f)
    for event, entries in data.get('hooks', {}).items():
        if isinstance(entries, list):
            for e in entries:
                for h in e.get('hooks', []):
                    cmd = h.get('command', '')[:80]
                    result.append({'event': event, 'matcher': e.get('matcher', '*'), 'command_snippet': cmd, 'source': f'plugin:{plugin_name}'})

print(json.dumps(result))
" 2>/dev/null || echo "[]")

# --- MCP servers: deduplicated by server name ---
MCP_COUNT=$(python3 -c "
import json, os, glob
seen = set()
claude_dir = os.path.expanduser('~/.claude')

# Check ~/.claude.json (global MCP config)
for p in [os.path.join(claude_dir, '.mcp.json'), os.path.expanduser('~/.claude.json')]:
    if os.path.isfile(p):
        with open(p) as f:
            data = json.load(f)
        for name in data.get('mcpServers', {}):
            seen.add(name)

# Check plugin .mcp.json files (dedup by server name, skip empty)
for mcp_file in glob.glob(os.path.join(claude_dir, 'plugins', '**', '.mcp.json'), recursive=True):
    with open(mcp_file) as f:
        data = json.load(f)
    for name in data.get('mcpServers', {}):
        seen.add(name)

print(len(seen))
" 2>/dev/null || echo "0")

# Assemble JSON
cat > "$OUTPUT" <<ENDJSON
{
    "version": "1.0.0",
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "cache_hash": "$CACHE_HASH",
    "stats": {
        "total_skills": $SKILL_COUNT,
        "total_commands": $COMMAND_COUNT,
        "total_agents": $AGENT_COUNT,
        "total_rules": $RULE_COUNT,
        "total_plugins": $PLUGIN_COUNT,
        "total_mcp_servers": $MCP_COUNT
    },
    "name_registry": {
        "skills": $SKILL_NAMES,
        "commands": $COMMAND_NAMES,
        "agents": $AGENT_NAMES,
        "all_names": $ALL_NAMES
    },
    "hooks": $HOOKS_SUMMARY
}
ENDJSON

echo "$OUTPUT"
