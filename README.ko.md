# Scout -- Claude Code 범용 자산 설치기

GitHub에서 Claude Code 자산(스킬, 커맨드, 에이전트, 플러그인, 룰)을 평가하고 안전하게 설치합니다.

현재 시스템과의 호환성을 자동 분석하고, 충돌을 감지하며, 백업/롤백을 지원합니다. 설치 전에 항상 명확한 추천을 제공합니다.

## 주요 기능

- **3단계 워크플로우**: SCOUT (가져오기 + 분석) -> JUDGE (6가지 검사) -> INSTALL (백업 + 검증)
- **신호등 판정**: GREEN / YELLOW / RED + 상세 이유
- **6가지 자동 검사**: 이름 충돌, 훅 충돌, 의존성, 크기, 구조, 기능 중복
- **안전 기본값**: 전체 백업 + 한 줄 롤백 (`/scout --undo`)
- **신뢰 관리**: 신뢰 조직/레포 목록, 설치 후 자동 신뢰 추가
- **시스템 맵**: Claude Code 전체 환경을 스캔해서 충돌 감지

## 설치 방법

### 방법 1: Clone 후 설치 (권장)

```bash
git clone https://github.com/Logan-DoubleB/Cat_is_king.git
cd Cat_is_king
bash install.sh
```

### 방법 2: 한 줄 설치

```bash
curl -fsSL https://raw.githubusercontent.com/Logan-DoubleB/Cat_is_king/main/install.sh | bash
```

### 방법 3: Scout로 Scout 설치

이미 Scout가 설치되어 있다면:

```
/scout Logan-DoubleB/Cat_is_king
```

### 사전 요구사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `python3`, `jq`, `gh` (GitHub CLI)

## 사용법

```
/scout <github-url>              # 평가 + 설치
/scout <github-url> --dry-run    # 평가만 (설치 안 함)
/scout --init                    # system-map.json 생성
/scout --undo                    # 가장 최근 설치 롤백
/scout --status                  # 설치 이력 조회
```

### 사용 예시

```
/scout https://github.com/someone/awesome-skill
```

출력 예시:

```
════════════════════════════════════════════
  SCOUT: awesome-skill
  Source: github.com/someone/awesome-skill
════════════════════════════════════════════

기능 설명
  스마트 태깅으로 파일 정리를 자동화합니다.

현재 시스템 상태
  유사한 기능이 없습니다.

GITHUB
  Stars: 42 | Forks: 8 | 최근 커밋: 2026-03-20
  Issues: 3 open / 12 closed

적합도
  GREEN — 충돌 없음, 모든 검사 통과

검사 결과
  ✅ 이름 충돌 없음
  ✅ 훅 충돌 없음
  ✅ 의존성 충족
  ✅ 크기 기준 이내
  ✅ 구조 정상
  ✅ 기능 중복 없음

추천: 설치
이유: 현재 시스템에 없는 새로운 기능, 충돌 없음
════════════════════════════════════════════
```

## 설치되는 파일

```
~/.claude/
├── skills/scout/
│   ├── SKILL.md              # 스킬 정의
│   ├── scout-trusted.json    # 신뢰 목록
│   ├── system-map.json       # 자동 생성되는 시스템 인벤토리
│   └── scripts/
│       ├── cache-check.sh    # 시스템 맵 캐시 검증
│       ├── classify-asset.sh # 자산 타입 감지
│       ├── fetch-target.sh   # GitHub URL 가져오기
│       ├── rollback.sh       # 백업 복원
│       ├── scan-system.sh    # 시스템 인벤토리 스캔
│       └── verify-install.sh # 설치 후 5점 검증
└── commands/
    └── scout.md              # /scout 커맨드 등록
```

## 작동 원리

### Phase 1: SCOUT — 이게 뭐지?

GitHub에서 대상을 가져오고(레포, 하위 디렉토리, 단일 파일, gist 지원), 자산 타입을 분류하고, GitHub 지표(stars, forks, 활동)를 수집하고, 신뢰 목록과 대조합니다.

### Phase 2: JUDGE — 설치해도 되나?

system-map.json 기반으로 6가지 자동 검사를 실행합니다:

| # | 검사 항목 | 내용 |
|---|----------|------|
| 1 | 이름 충돌 | 같은 이름이 이미 존재하는가? |
| 2 | 훅 충돌 | 같은 이벤트+매처 조합이 있는가? |
| 3 | 의존성 | 참조하는 자산이 설치되어 있는가? |
| 4 | 크기 | 800줄 이하인가? |
| 5 | 구조 | 표준 디렉토리 구조인가? |
| 6 | 중복 | 기존 자산과 50% 이상 기능이 겹치는가? |

판정: GREEN (전부 통과), YELLOW (1-2개 경미), RED (3개 이상 또는 치명적)

### Phase 3: INSTALL — 설치 + 검증

전체 백업(파일 + settings.json 스냅샷)을 생성하고, 자산을 설치하고, 5점 검증을 실행합니다. 실패 시 자동 롤백됩니다.

## 롤백

모든 설치는 `~/.claude/backups/scout/`에 백업을 생성합니다. 되돌리려면:

```
/scout --undo
```

백업은 7일 후 자동 만료됩니다.

## 설정

### 신뢰 목록

`~/.claude/skills/scout/scout-trusted.json`을 편집하세요:

```json
{
    "trusted_orgs": ["anthropics"],
    "trusted_repos": ["anthropics/claude-code"],
    "blocked_repos": [],
    "auto_trust_after_install": false
}
```

- `trusted_orgs`: 신뢰하는 GitHub 조직 (평가 시 확인 생략)
- `trusted_repos`: 신뢰하는 개별 레포
- `blocked_repos`: 차단할 레포
- `auto_trust_after_install`: 설치 성공 후 자동으로 신뢰 목록에 추가할지 여부

## 라이선스

MIT
