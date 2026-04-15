#!/bin/bash
# ============================================================
# RECON Framework — Unit Test: State Machine
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

# Source required libraries
source lib/utils.sh
source lib/state.sh

WORKDIR="/tmp/recon_test_$$"
mkdir -p "$WORKDIR/meta" "$WORKDIR/01_subdomains"
LOG_FILE="/tmp/test_log_$$.txt"
touch "$LOG_FILE"

ERRORS=0

# Test 1: state_init creates state file
state_init
if [ -f "$WORKDIR/meta/state.json" ]; then
  echo "PASS: state_init creates file"
else
  echo "FAIL: state_init"
  ((ERRORS++))
fi

# Test 2: state_mark_done sets status
state_mark_done "subdomains"
status=$(state_get_status "subdomains")
if [ "$status" = "done" ]; then
  echo "PASS: state_mark_done"
else
  echo "FAIL: state_mark_done (got: $status)"
  ((ERRORS++))
fi

# Test 3: state_should_skip returns 0 when done + file exists
mkdir -p "$WORKDIR/01_subdomains"
echo "test.com" > "$WORKDIR/01_subdomains/all_subdomains.txt"
if state_should_skip "subdomains"; then
  echo "PASS: state_should_skip skips done phase"
else
  echo "FAIL: state_should_skip"
  ((ERRORS++))
fi

# Test 4: state_mark_failed
state_mark_failed "dns" "connection refused"
status=$(state_get_status "dns")
if [ "$status" = "failed" ]; then
  echo "PASS: state_mark_failed"
else
  echo "FAIL: state_mark_failed (got: $status)"
  ((ERRORS++))
fi

# Test 5: state_should_skip returns 1 for failed phase
if ! state_should_skip "dns"; then
  echo "PASS: state_should_skip does NOT skip failed phase"
else
  echo "FAIL: state_should_skip skipped failed phase"
  ((ERRORS++))
fi

# Test 6: state_get_status returns pending for unknown phase
status=$(state_get_status "unknown_phase")
if [ "$status" = "pending" ]; then
  echo "PASS: state_get_status returns pending for unknown"
else
  echo "FAIL: state_get_status (got: $status)"
  ((ERRORS++))
fi

# Cleanup
rm -rf "$WORKDIR" "$LOG_FILE"

exit $ERRORS
