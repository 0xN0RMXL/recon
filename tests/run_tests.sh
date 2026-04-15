#!/bin/bash
# ============================================================
# RECON Framework — Test Suite Runner
# ============================================================
echo "=============================="
echo " RECON Framework Test Suite   "
echo "=============================="

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

PASS=0; FAIL=0

run_test() {
  local test_file="$1"
  echo ""
  echo "--- Running: $test_file ---"
  if bash "$test_file"; then
    ((PASS++))
  else
    ((FAIL++))
  fi
}

# Unit tests
for f in unit/test_*.sh; do
  [ -f "$f" ] && run_test "$f"
done

# Integration tests
for f in integration/test_*.sh; do
  [ -f "$f" ] && run_test "$f"
done

echo ""
echo "=============================="
echo " Total: $PASS passed, $FAIL failed"
echo "=============================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
