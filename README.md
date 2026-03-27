# Scout -- Universal Asset Installer for Claude Code

[한국어 설명서 (Korean)](./README.ko.md)

Evaluate, analyze, and safely install Claude Code assets (skills, commands, agents, plugins, rules) from GitHub.

### Quick Install (in Claude Code)

Just paste this in Claude Code:

```
Install Scout from https://github.com/Logan-DoubleB/Cat_is_king — clone the repo, run bash install.sh, then verify with /scout --init
```

Scout checks compatibility with your current system, detects conflicts, provides backup/rollback, and gives a clear recommendation before installing anything.

## Features

- **3-phase workflow**: SCOUT (fetch + analyze) -> JUDGE (6-point check) -> INSTALL (backup + verify)
- **Traffic light verdict**: GREEN / YELLOW / RED with detailed reasoning
- **6 automated checks**: name collision, hook conflict, dependency, size, structure, overlap
- **Safe by default**: full backup with one-command rollback (`/scout --undo`)
- **Trust management**: trusted orgs/repos list, auto-trust after successful install
- **System map**: scans your entire Claude Code setup for conflict detection

## Installation

### Option 1: Clone and install

```bash
git clone https://github.com/Logan-DoubleB/Cat_is_king.git
cd Cat_is_king
bash install.sh
```

### Option 2: One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/Logan-DoubleB/Cat_is_king/main/install.sh | bash
```

### Option 3: Use Scout to install Scout

If you already have Scout installed:

```
/scout Logan-DoubleB/Cat_is_king
```

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `python3`, `jq`, `git`
- `gh` (GitHub CLI) — run `gh auth login` after install

```bash
# macOS
brew install python3 jq gh git

# Ubuntu/Debian
sudo apt install python3 jq gh git

# After installing gh:
gh auth login
```

## Usage

```
/scout <github-url>              # Evaluate + install
/scout <github-url> --dry-run    # Evaluate only, no install
/scout --init                    # Generate system-map.json
/scout --undo                    # Rollback most recent install
/scout --status                  # Show install history
```

### Example

```
/scout https://github.com/someone/awesome-skill
```

Output:

```
════════════════════════════════════════════
  SCOUT: awesome-skill
  Source: github.com/someone/awesome-skill
════════════════════════════════════════════

WHAT IT DOES
  Automates file organization with smart tagging.

YOUR CURRENT SETUP
  No similar functionality found.

GITHUB
  Stars: 42 | Forks: 8 | Last commit: 2026-03-20
  Issues: 3 open / 12 closed

FIT
  GREEN — No conflicts, all checks passed

CHECKS
  ✅ No name collision
  ✅ No hook conflict
  ✅ Dependencies satisfied
  ✅ Under size limit
  ✅ Valid structure
  ✅ No overlap

RECOMMEND: INSTALL
Reason: New functionality not present in current system, no conflicts
════════════════════════════════════════════
```

## What gets installed

```
~/.claude/
├── skills/scout/
│   ├── SKILL.md              # Skill definition
│   ├── scout-trusted.json    # Trust list
│   ├── system-map.json       # Auto-generated system inventory
│   └── scripts/
│       ├── cache-check.sh    # System map cache validator
│       ├── classify-asset.sh # Asset type detector
│       ├── fetch-target.sh   # GitHub URL fetcher
│       ├── rollback.sh       # Backup restorer
│       ├── scan-system.sh    # System inventory scanner
│       └── verify-install.sh # Post-install verifier
└── commands/
    └── scout.md              # /scout command registration
```

## How it works

### Phase 1: SCOUT

Fetches the target from GitHub (supports repos, subdirectories, single files, gists), classifies the asset type, collects GitHub metrics (stars, forks, activity), and checks against your trust list.

### Phase 2: JUDGE

Runs 6 automated checks against your system-map.json:

| # | Check | What it does |
|---|-------|-------------|
| 1 | Name collision | Same name already exists? |
| 2 | Hook conflict | Same event+matcher combo? |
| 3 | Dependencies | Referenced assets installed? |
| 4 | Size | Under 800 lines? |
| 5 | Structure | Standard directory layout? |
| 6 | Overlap | 50%+ functional overlap? |

Verdict: GREEN (all pass), YELLOW (1-2 minor), RED (3+ or critical)

### Phase 3: INSTALL

Creates a full backup (files + settings.json snapshot), installs the asset, runs 5-point verification, and auto-rolls back on failure.

## Rollback

Every installation creates a backup at `~/.claude/backups/scout/`. To undo:

```
/scout --undo
```

Backups auto-expire after 7 days.

## Configuration

### Trust list

Edit `~/.claude/skills/scout/scout-trusted.json`:

```json
{
    "trusted_orgs": ["anthropic"],
    "trusted_repos": ["anthropic/claude-code"],
    "blocked_repos": [],
    "auto_trust_after_install": false
}
```

## License

MIT
