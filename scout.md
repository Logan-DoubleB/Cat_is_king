---
description: "GitHub에서 스킬/커맨드/에이전트/플러그인/룰을 평가하고 안전하게 설치. 현재 시스템 호환성 분석, 충돌 감지, 백업/롤백 포함."
---

# Scout -- Universal Asset Installer

GitHub에서 새로운 Claude Code 자산을 발견했을 때 사용합니다.
현재 시스템과의 호환성을 평가하고, 안전하게 설치합니다.

## Usage

```
/scout <github-url>              # 평가 + 설치
/scout <github-url> --dry-run    # 평가만
/scout --init                    # system-map.json 최초 생성
/scout --undo                    # 가장 최근 설치 롤백
/scout --status                  # 설치 이력 조회
```

## Workflow

1. **SCOUT** -- repo fetch + 자산 타입 감지 + 목적 분석
2. **JUDGE** -- 6가지 체크 + 신호등 판정 + 이유 출력
3. **INSTALL** -- 백업 + 설치 + 5점 검증 + 롤백 테스트

봇 모드에서는 Phase 1-2만 실행 (평가 리포트만 출력).

## Related

- Skill: `skills/scout/`
- Skill: `skills/skill-stocktake/`
- Command: `/skill-create`
- Command: `/skill-health`
