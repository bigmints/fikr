#!/bin/bash
# validate.sh — Flutter pre-commit validation
# Must pass before every git commit. Exit 0 = pass. Exit non-zero = blocked.

set -euo pipefail
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
NC=$(printf '\033[0m')

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "${GREEN}✓${NC} $label"
    PASS=$((PASS + 1))
  else
    echo "${RED}✗${NC} $label"
    FAIL=$((FAIL + 1))
  fi
}

check_output() {
  local label="$1"
  shift
  local out
  out=$("$@" 2>&1) || true
  if echo "$out" | grep -qE "^No issues found"; then
    echo "${GREEN}✓${NC} $label"
    PASS=$((PASS + 1))
  else
    echo "${RED}✗${NC} $label"
    echo "$out" | grep -v "^Analyzing" | head -20
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Agent Validation (Flutter) ==="
echo ""

# ── Task gate
TODO=".agents/skills/task-manager/todo.toon"
if [ -f "$TODO" ]; then
  IN_PROGRESS=$(grep -A2 "^  in_progress:" "$TODO" | grep -v "^  in_progress:" | grep -v "^$" | head -1 || true)
  if [ -z "$IN_PROGRESS" ]; then
    echo "${RED}✗${NC} Active task — none found in todo.toon"
    echo ""
    echo "  Fix: .agents/skills/task-manager/manage.sh start <task_id>"
    echo ""
    FAIL=$((FAIL + 1))
  else
    echo "${GREEN}✓${NC} Active task — found in todo.toon"
    PASS=$((PASS + 1))
  fi
fi

echo ""
echo "=== Code Checks ==="
echo ""

check "pub get" flutter pub get
check_output "flutter analyze" flutter analyze
check "tests" flutter test

echo ""
echo "=== Result ==="
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "${RED}FAILED${NC} — $FAIL check(s) failed, $PASS passed."
  echo "Fix all failures before committing."
  exit 1
fi

echo "${GREEN}ALL PASSED${NC} — $PASS checks."
exit 0
