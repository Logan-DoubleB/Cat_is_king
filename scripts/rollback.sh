#!/bin/bash
# rollback.sh — Restore from backup including settings.json
# Input: backup directory path (optional, defaults to most recent)
# Output: rollback result
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="${1:-}"

# Find most recent backup if none specified
if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR=$(ls -td "$CLAUDE_DIR/backups/scout"/*/ 2>/dev/null | head -1)
fi

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: 백업 디렉토리를 찾을 수 없습니다." >&2
    exit 1
fi

MANIFEST="$BACKUP_DIR/manifest.json"

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: manifest.json이 없습니다: $BACKUP_DIR" >&2
    exit 1
fi

echo "롤백 시작: $BACKUP_DIR"

# Execute rollback safely via environment variables (no shell interpolation into Python)
export SCOUT_MANIFEST="$MANIFEST"
export SCOUT_BACKUP_DIR="$BACKUP_DIR"

python3 - <<'PYEOF'
import json, sys, shutil, os

ALLOWED_PREFIX = os.path.realpath(os.path.expanduser('~/.claude/'))
manifest_path = os.environ['SCOUT_MANIFEST']
backup_dir = os.environ['SCOUT_BACKUP_DIR']

with open(manifest_path) as f:
    m = json.load(f)

print(f"  대상: {m.get('asset_name', 'unknown')} ({m.get('asset_type', 'unknown')})")
print(f"  소스: {m.get('source_url', 'unknown')}")
print()

errors = 0

# Remove installed paths (safe: only within ~/.claude/)
for path_rel in m.get('installed_paths', []):
    abs_path = os.path.realpath(os.path.expanduser(path_rel))
    if not abs_path.startswith(ALLOWED_PREFIX):
        print(f'  거부: {path_rel} — ~/.claude/ 범위 외 경로', file=sys.stderr)
        errors += 1
        continue
    if os.path.isdir(abs_path):
        shutil.rmtree(abs_path)
        print(f'  삭제: {path_rel}')
    elif os.path.isfile(abs_path):
        os.remove(abs_path)
        print(f'  삭제: {path_rel}')

# Restore settings.json if snapshot exists
settings_snap = m.get('settings_snapshot', '')
if settings_snap:
    snap_path = os.path.join(backup_dir, settings_snap)
    settings_path = os.path.expanduser('~/.claude/settings.json')
    if os.path.exists(snap_path):
        shutil.copy2(snap_path, settings_path)
        print('  settings.json 복원 완료')

# Restore backed up files (safe: only within ~/.claude/)
for src_rel in m.get('backed_up_files', []):
    dst = os.path.realpath(os.path.expanduser(src_rel))
    if not dst.startswith(ALLOWED_PREFIX):
        print(f'  거부: {src_rel} — ~/.claude/ 범위 외 경로', file=sys.stderr)
        errors += 1
        continue
    src = os.path.join(backup_dir, os.path.basename(src_rel))
    if os.path.exists(src):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
        print(f'  복원: {src_rel}')

if errors == 0:
    print()
    print('롤백 완료.')
else:
    print()
    print(f'롤백 완료 (경고 {errors}건)')
    sys.exit(1)
PYEOF
