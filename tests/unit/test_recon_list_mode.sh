#!/bin/bash
# ============================================================
# RECON Framework — Unit Test: List mode hard-stop behavior
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

export RECON_NO_MAIN=1
source ./recon.sh

ERRORS=0
FORCE="false"
OUTPUT_BASE="/tmp/recon_test_list_mode_$$"

processed_count=0
run_phase_calls=""

init_workspace() {
  WORKDIR="/tmp/recon_test_list_mode_$$/${TARGET}"
  mkdir -p "$WORKDIR/meta"
  : > "$WORKDIR/meta/state.json"
}

run_all_phases() {
  processed_count=$((processed_count + 1))
  if [ "$TARGET" = "second.example.com" ]; then
    return 1
  fi
  return 0
}

print_dashboard() { return 0; }

LOG_FILE="/tmp/test_recon_list_mode_$$.log"
: > "$LOG_FILE"

list_file="/tmp/recon_list_mode_targets_$$.txt"
cat > "$list_file" <<EOF
first.example.com
second.example.com
third.example.com
EOF

if run_for_list "$list_file"; then
  echo "FAIL: run_for_list should fail when a domain run fails"
  ((ERRORS++))
else
  echo "PASS: run_for_list fails fast on domain failure"
fi

if [ "$processed_count" -eq 2 ]; then
  echo "PASS: list mode stopped at failing domain"
else
  echo "FAIL: list mode processed unexpected domain count ($processed_count)"
  ((ERRORS++))
fi

rm -f "$list_file" "$LOG_FILE"
rm -rf "$OUTPUT_BASE" "/tmp/recon_test_list_mode_$$"
unset RECON_NO_MAIN

exit $ERRORS
