---
name: scout
description: "Evaluate and safely install skills, commands, agents, plugins, and rules from GitHub. Analyzes compatibility with current system, detects conflicts, provides backup/rollback. Use when: (1) evaluating GitHub assets before install, (2) checking system compatibility, (3) safe install with backup."
version: 1.0.0
tags:
  - system
  - installer
  - evaluation
  - safety
---

# Scout -- Universal Asset Installer

## When to Activate

- User provides a GitHub URL wanting to evaluate/install a skill, plugin, command, agent, or rule
- User says "/scout", "check this skill", "should I install this"
- A Claude Code related GitHub link is pasted

## Usage

```
/scout <github-url>              # Evaluate + interactive install
/scout <github-url> --dry-run    # Evaluate only, no install
/scout --init                    # Generate system-map.json (first run)
/scout --undo                    # Rollback most recent install
/scout --status                  # Show install history
```

## Phase 0: Internal Prep (invisible to user)

### 0.1 Acquire lock

```bash
LOCK_DIR="$HOME/.claude/.scout.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "ERROR: another /scout process is running" >&2
    exit 1
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
```

### 0.2 Cleanup expired backups

```bash
find "$HOME/.claude/backups/scout" -maxdepth 1 -type d -mtime +7 \
    -exec rm -rf {} + 2>/dev/null || true
```

### 0.3 Load system-map.json

Run: `bash ~/.claude/skills/scout/scripts/cache-check.sh`

- Output "VALID" → read system-map.json
- Output "STALE" or missing → run `bash ~/.claude/skills/scout/scripts/scan-system.sh`
- `--init` flag → force regeneration

### 0.4 Load trust list

Read `~/.claude/skills/scout/scout-trusted.json`. Create with defaults if missing.

---

## Phase 1: SCOUT -- What is this?

### 1.1 URL parse and fetch

Run: `bash ~/.claude/skills/scout/scripts/fetch-target.sh "<URL>"`

Supported URL patterns:
| Pattern | Action |
|---------|--------|
| `github.com/user/repo` | `git clone --depth 1` |
| `github.com/user/repo/tree/main/path` | sparse checkout |
| `github.com/user/repo/blob/main/file.md` | raw download |
| `gist.github.com/...` | `gh gist clone` |
| `user/repo` (short form) | prepend `https://github.com/` |

### 1.2 Collect GitHub metrics

```bash
gh api repos/{owner}/{repo} --jq '{
    stars: .stargazers_count,
    forks: .forks_count,
    watchers: .watchers_count,
    updated: .updated_at,
    open_issues: .open_issues_count,
    license: .license.spdx_id,
    archived: .archived
}'
```

Display metrics for trust evaluation. Stars, forks, recency, and issue ratio inform reliability.

### 1.3 Classify asset type

Run: `bash ~/.claude/skills/scout/scripts/classify-asset.sh "<fetched_path>"`

Detection priority:
1. `.claude-plugin/plugin.json` → **PLUGIN**
2. `SKILL.md` → **SKILL** (multiple → SKILL_BUNDLE)
3. `allowed_tools:` frontmatter → **COMMAND**
4. `tools:` + `model:` frontmatter → **AGENT**
5. `rules/` directory structure → **RULE_SET**
6. Unrecognized → ask user

Monorepo (multiple assets):
> List all assets with numbers, let user select which to evaluate.

### 1.4 Trust verification

```
Repo in trusted list?
├─ YES → proceed to Phase 2
└─ NO  → show GitHub metrics + file list + request confirmation
```

### 1.5 Purpose analysis output

All user-facing output in Korean:
> "이 스킬은 ___을 자동화합니다."
> "현재 시스템에는 이 기능이 [있음/없음]."

---

## Phase 2: JUDGE -- Should I install?

### 2.1 Checklist (6 checks, all automated)

Use `name_registry` from system-map.json:

| # | Check | Method | Pass/Fail |
|---|-------|--------|-----------|
| 1 | Name collision | Same name in `name_registry.all_names`? | No match = PASS |
| 2 | Hook conflict | Same event+matcher hook combo exists? | No match = PASS |
| 3 | Dependencies | Referenced skills/commands installed? | All present = PASS |
| 4 | Size | Under 800 lines? | Under = PASS |
| 5 | Structure | Standard directory layout? | Valid = PASS |
| 6 | Overlap | 50%+ functional overlap with existing? (AI judgment) | No overlap = PASS |

### 2.2 Traffic light verdict

| Signal | Condition |
|--------|-----------|
| GREEN | All 6 PASS |
| YELLOW | 1-2 FAIL (minor: size, slight overlap) |
| RED | 3+ FAIL or name/hook collision |

### 2.3 Recommendation + reason

ALWAYS output a single recommendation WITH reason in Korean:

```
RECOMMEND: INSTALL
이유: 기존에 없는 기능 (파일 자동 정리), 충돌 없음, GREEN

RECOMMEND: SKIP
이유: 기존 copywriting 스킬과 기능 85% 겹침
     (AIDA, PAS, BAB 프레임워크 이미 보유)
     새로운 건 A/B 헤드라인 테스트뿐

RECOMMEND: PARTIAL (2/4 설치 추천)
✅ social-listening — 기존에 없는 기능, GREEN
✅ trend-tracker — news_digest와 시너지, GREEN
❌ copywriting-pro — 기존 copywriting과 85% 겹침
❌ email-blast — 기존 cold-email과 기능 동일
```

### 2.4 CLI only: worktree simulation

1. **Name collision test**: query name_registry via `jq`
2. **Hook conflict test**: compare new asset hooks vs existing hooks
3. **File write conflict test**: `cp -rn` (no-clobber) to detect overwrites
4. **Dependency satisfaction test**: check referenced skill existence

### 2.5 `--dry-run` check

If `--dry-run` flag is set:
- Output the report from Phase 1-2
- Clean up fetched temp directory (`rm -rf $WORKDIR`)
- Release lock, exit — **do NOT proceed to Phase 3**

### 2.6 Await user decision

> "설치하시겠습니까? [YES / NO]"

YES → Phase 3
NO → clean up fetched temp directory, release lock, exit

---

## Phase 3: INSTALL -- Install + verify (CLI mode only)

After Phase 3 completes (success or rollback), clean up the fetched temp directory:
```bash
rm -rf "$WORKDIR"  # /tmp/scout-XXXXXXXXXX created by fetch-target.sh
```

### 3.1 Create backup

```bash
BACKUP_DIR="$HOME/.claude/backups/scout/$(date +%Y-%m-%d)_${ASSET_NAME}"
mkdir -p "$BACKUP_DIR"
```

Backup targets:
- Copy affected existing files
- Snapshot `settings.json` (including hooks)
- Copy current `system-map.json`
- Generate `manifest.json` (checksums + rollback commands)

manifest.json structure:
```json
{
    "created_at": "2026-03-27T10:00:00Z",
    "asset_name": "new-skill",
    "asset_type": "skill",
    "source_url": "https://github.com/user/repo",
    "backed_up_files": ["path1", "path2"],
    "hooks_modified": false,
    "settings_snapshot": "settings.json.bak",
    "rollback_commands": ["rm -rf ~/.claude/skills/new-skill"]
}
```

### 3.2 Apply installation

**Allowed files**: `.md` files only
**Blocked files**: `.sh`, `.py`, `.js`, `.json` (executables) → warn + require user confirmation

If SKILL.md contains bash code blocks:
> "이 스킬은 bash 실행 명령을 포함합니다:"
> (list commands)
> "계속하시겠습니까? [Y/N]"

If hook registration needed:
- Add hook to `settings.json`
- Record in manifest.json (for rollback removal)

### 3.3 Verify (5-point)

Run: `bash ~/.claude/skills/scout/scripts/verify-install.sh "${ASSET_NAME}"`

| # | Check | Method |
|---|-------|--------|
| 1 | No errors | Installed files exist + readable |
| 2 | Functional | Asset type-specific structure validation |
| 3 | Integration | New asset appears in refreshed system-map |
| 4 | Rollback capability | Backup manifest valid + test rollback |
| 5 | No hook conflicts | Parse settings.json, no duplicate hooks |

On failure:
```
Run: bash ~/.claude/skills/scout/scripts/rollback.sh "$BACKUP_DIR"
```
→ Auto-restore including settings.json → report failure to user

### 3.4 Final user confirmation

After verification passes:
> "검증 5점 모두 통과. 최종 설치를 확정하시겠습니까? [YES / NO]"

YES:
- Refresh system-map.json (re-run scan-system.sh)
- Append to install-log.jsonl
- Auto-add repo to trusted list (if `auto_trust_after_install: true`)
- Release lock

NO:
- Execute rollback
- Release lock

---

## Output Formats

### CLI report (Korean output)

```
════════════════════════════════════════════
  SCOUT: {asset-name}
  Source: github.com/{owner}/{repo}
════════════════════════════════════════════

WHAT IT DOES
  {한 문장 설명}

YOUR CURRENT SETUP
  {현재 시스템에서 이 기능의 상태}

GITHUB
  Stars: {n} | Forks: {n} | 최근 커밋: {date}
  Issues: {open} open / {closed} closed

FIT
  {GREEN/YELLOW/RED} — {판정 이유}

CHECKS
  ✅ 이름 충돌 없음
  ✅ 훅 충돌 없음
  ✅ 의존성 충족
  ⚠️ 크기 초과 (920줄 > 800줄 기준)
  ✅ 구조 정상
  ✅ 중복 없음

RECOMMEND: {INSTALL / SKIP / PARTIAL}
이유: {구체적 이유 1-2줄}
════════════════════════════════════════════
```

## /scout --undo

Rollback from most recent backup:

```bash
LATEST=$(ls -td "$HOME/.claude/backups/scout"/*/ 2>/dev/null | head -1)
```

Read manifest.json and execute rollback commands.
Restore settings.json from snapshot.

---

## /scout --status

Read `install-log.jsonl` and display last 10 entries:

```
최근 설치 이력
─────────────
1. 2026-03-27 | social-listening (skill) | GREEN | github.com/user/repo
2. 2026-03-25 | code-formatter (command) | YELLOW | github.com/user/repo2
```

---

## Safety Checklist

Applied automatically on every execution:

- [ ] `.scout.lock` acquired
- [ ] Expired backups cleaned (7-day)
- [ ] system-map.json hash validated
- [ ] Trust list checked
- [ ] Only .md files installed
- [ ] Bash code blocks disclosed before install
- [ ] settings.json included in backup/rollback transaction
- [ ] Rollback test passed
- [ ] Concurrent execution prevented

## Related

- Skill: `skills/skill-stocktake/` -- existing skill portfolio audit
- Command: `/skill-create` -- create skills from git history
- Command: `/skill-health` -- skill health dashboard
- Command: `/evolve` -- evolve instincts to skills
