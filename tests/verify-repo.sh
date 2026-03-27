#!/bin/bash
# verify-repo.sh — Scout repo 배포 전 검증 테스트
set -uo pipefail
# Note: -e disabled because grep returns 1 on no-match, which is expected in tests

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

check() {
    local name="$1"
    local result="$2"
    TOTAL=$((TOTAL + 1))
    if [ "$result" = "PASS" ]; then
        PASS=$((PASS + 1))
        echo "  ✅ $name"
    else
        FAIL=$((FAIL + 1))
        echo "  ❌ $name"
    fi
}

echo ""
echo "═══════════════════════════════════════"
echo "  Scout Repo 검증 테스트"
echo "═══════════════════════════════════════"
echo ""

# ── 1. 파일 존재 검사 ──
echo "[1] 필수 파일 존재"
for f in SKILL.md scout.md install.sh README.md README.ko.md LICENSE .gitignore scout-trusted.json; do
    [ -f "$REPO_DIR/$f" ] && check "$f" "PASS" || check "$f" "FAIL"
done
for f in cache-check.sh classify-asset.sh fetch-target.sh rollback.sh scan-system.sh verify-install.sh; do
    [ -f "$REPO_DIR/scripts/$f" ] && check "scripts/$f" "PASS" || check "scripts/$f" "FAIL"
done

# ── 2. 스크립트 실행 권한 ──
echo ""
echo "[2] 스크립트 실행 권한"
for f in "$REPO_DIR"/scripts/*.sh "$REPO_DIR/install.sh"; do
    [ -x "$f" ] && check "$(basename "$f") +x" "PASS" || check "$(basename "$f") +x" "FAIL"
done

# ── 3. SKILL.md 프론트매터 ──
echo ""
echo "[3] SKILL.md 프론트매터"
head -1 "$REPO_DIR/SKILL.md" | grep -q "^---" && check "프론트매터 시작 (---)" "PASS" || check "프론트매터 시작 (---)" "FAIL"
grep -q "^name:" "$REPO_DIR/SKILL.md" && check "name 필드" "PASS" || check "name 필드" "FAIL"
grep -q "^description:" "$REPO_DIR/SKILL.md" && check "description 필드" "PASS" || check "description 필드" "FAIL"
grep -q "^version:" "$REPO_DIR/SKILL.md" && check "version 필드" "PASS" || check "version 필드" "FAIL"

# ── 4. 개인정보 없음 ──
echo ""
echo "[4] 개인정보 미포함"
PERSONAL=$(grep -ri "bbangsang\|황상욱\|sangwook\|telegram\|TELEGRAM\|affaan\|AnT_\|Obsidian\|antlab\|ANT.LAB\|antigravity\|api.key\|@gmail\|@naver" "$REPO_DIR" --include="*.md" --include="*.sh" --include="*.json" --exclude-dir=tests 2>/dev/null || true)
[ -z "$PERSONAL" ] && check "개인정보 없음" "PASS" || check "개인정보 발견: $PERSONAL" "FAIL"

# ── 5. 보안 패턴 검사 ──
echo ""
echo "[5] 보안 패턴"
# eval 금지
EVAL_COUNT=$(grep -rn "eval " "$REPO_DIR/scripts/" 2>/dev/null | wc -l | tr -d ' ' || true)
[ "$EVAL_COUNT" -eq 0 ] && check "eval 사용 없음" "PASS" || check "eval 사용 발견 (${EVAL_COUNT}건)" "FAIL"

# shell=True 금지
SHELL_TRUE=$(grep -rn "shell=True" "$REPO_DIR/scripts/" 2>/dev/null | wc -l | tr -d ' ' || true)
[ "$SHELL_TRUE" -eq 0 ] && check "shell=True 없음" "PASS" || check "shell=True 발견 (${SHELL_TRUE}건)" "FAIL"

# GitHub host allowlist 존재
grep -q "github\.com\|raw\.githubusercontent\.com\|gist\.github\.com" "$REPO_DIR/scripts/fetch-target.sh" && check "URL host allowlist" "PASS" || check "URL host allowlist" "FAIL"

# rollback 경로 제한
grep -q "ALLOWED_PREFIX" "$REPO_DIR/scripts/rollback.sh" && check "rollback 경로 제한" "PASS" || check "rollback 경로 제한" "FAIL"

# fetch-target.sh trap 존재
grep -q "trap.*EXIT" "$REPO_DIR/scripts/fetch-target.sh" && check "fetch-target.sh temp 정리 trap" "PASS" || check "fetch-target.sh temp 정리 trap" "FAIL"

# Python 인라인에 $VAR 직접 삽입 금지 (python3 -c "..." 안에 $가 있으면 위험)
# 허용 패턴: python3 - <<'PYEOF' (heredoc) 또는 python3 -c '...' (single quote)
UNSAFE_PY=$(grep -n 'python3 -c "' "$REPO_DIR/scripts/verify-install.sh" "$REPO_DIR/scripts/cache-check.sh" "$REPO_DIR/scripts/rollback.sh" "$REPO_DIR/scripts/scan-system.sh" 2>/dev/null | wc -l | tr -d ' ' || true)
[ "${UNSAFE_PY:-0}" -eq 0 ] && check "Python 인라인 셸보간 없음" "PASS" || check "Python 인라인 셸보간 발견 (${UNSAFE_PY}건)" "FAIL"

# install.sh EXIT trap 존재
grep -q "trap.*EXIT\|trap cleanup" "$REPO_DIR/install.sh" && check "install.sh EXIT trap" "PASS" || check "install.sh EXIT trap 누락" "FAIL"

# scan-system.sh atomic write (mv 패턴)
grep -q 'mv.*OUTPUT' "$REPO_DIR/scripts/scan-system.sh" && check "scan-system.sh atomic write" "PASS" || check "scan-system.sh atomic write 없음" "FAIL"

# ── 6. 크로스플랫폼 호환성 ──
echo ""
echo "[6] 크로스플랫폼"
grep -q "sha256sum" "$REPO_DIR/scripts/cache-check.sh" && check "cache-check: sha256sum 분기" "PASS" || check "cache-check: sha256sum 분기" "FAIL"
grep -q "sha256sum" "$REPO_DIR/scripts/scan-system.sh" && check "scan-system: sha256sum 분기" "PASS" || check "scan-system: sha256sum 분기" "FAIL"
grep -q "mktemp" "$REPO_DIR/scripts/fetch-target.sh" && check "fetch-target: mktemp 사용" "PASS" || check "fetch-target: mktemp 사용" "FAIL"

# ── 7. trusted.json 유효성 ──
echo ""
echo "[7] scout-trusted.json 유효성"
python3 -c "import json; json.load(open('$REPO_DIR/scout-trusted.json'))" 2>/dev/null && check "유효한 JSON" "PASS" || check "유효한 JSON" "FAIL"
# anthropic 오타 검사 (anthropics ≠ anthropic)
if grep -q '"anthropics"' "$REPO_DIR/scout-trusted.json" 2>/dev/null; then
    check "anthropics 오타 발견" "FAIL"
else
    check "anthropic 오타 없음" "PASS"
fi
# auto_trust default = false
grep -q '"auto_trust_after_install": false' "$REPO_DIR/scout-trusted.json" && check "auto_trust 기본값 false" "PASS" || check "auto_trust 기본값 true (위험)" "FAIL"

# ── 8. README 일관성 ──
echo ""
echo "[8] README 일관성"
grep -q "auto_trust_after_install.*false" "$REPO_DIR/README.md" && check "README.md auto_trust=false" "PASS" || check "README.md auto_trust 불일치" "FAIL"
# README.ko.md anthropics 오타 검사
if grep -q '"anthropics"' "$REPO_DIR/README.ko.md" 2>/dev/null; then
    check "README.ko.md anthropics 오타" "FAIL"
else
    check "README.ko.md anthropic 정상" "PASS"
fi
grep -q 'README.ko.md' "$REPO_DIR/README.md" && check "한국어 README 링크" "PASS" || check "한국어 README 링크 누락" "FAIL"

# ── 9. install.sh TMPDIR 충돌 없음 ──
echo ""
echo "[9] install.sh 변수명"
TMPDIR_COUNT=$(grep -c 'TMPDIR' "$REPO_DIR/install.sh" 2>/dev/null || echo "0")
SCOUT_TMPDIR_COUNT=$(grep -c 'SCOUT_TMPDIR' "$REPO_DIR/install.sh" 2>/dev/null || echo "0")
[ "$TMPDIR_COUNT" -eq "$SCOUT_TMPDIR_COUNT" ] && check "TMPDIR 충돌 없음 (SCOUT_TMPDIR 사용)" "PASS" || check "TMPDIR 변수명 충돌" "FAIL"

# ── 10. 스크립트 문법 검사 ──
echo ""
echo "[10] bash 문법 검사"
for f in "$REPO_DIR"/scripts/*.sh "$REPO_DIR/install.sh"; do
    bash -n "$f" 2>/dev/null && check "$(basename "$f") 문법" "PASS" || check "$(basename "$f") 문법 오류" "FAIL"
done

# ── 결과 ──
echo ""
echo "═══════════════════════════════════════"
echo "  결과: ${PASS}/${TOTAL} 통과 (실패: ${FAIL})"
echo "═══════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
