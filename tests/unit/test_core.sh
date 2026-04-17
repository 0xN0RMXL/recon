#!/bin/bash
# ============================================================
# RECON Framework — Unit Test: Core run_phase fail-fast logic
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh
source lib/state.sh
source lib/core.sh

ERRORS=0
TARGET="example.com"
TARGET_MODE="single"
OUTPUT_BASE="/tmp/recon_test_core_$$"
VERSION="1.0.0"
FORCE="false"
NO_NOTIFY="true"
SKIP_PHASES=""
ONLY_PHASE=""
PHASE_RETRY_COUNT=2
PHASE_RETRY_SLEEP=0

init_workspace

attempt_bad=0
bad_phase() {
  attempt_bad=$((attempt_bad + 1))
  echo "invalid domain entry" > "$WORKDIR/01_subdomains/all_subdomains.txt"
  return 0
}

if run_phase "subdomains" "bad_phase"; then
  echo "FAIL: run_phase succeeded with invalid foundational output"
  ((ERRORS++))
else
  echo "PASS: run_phase fails when foundational output is invalid"
fi

if [ "$attempt_bad" -eq 2 ]; then
  echo "PASS: run_phase retried according to PHASE_RETRY_COUNT"
else
  echo "FAIL: run_phase attempts mismatch (got: $attempt_bad)"
  ((ERRORS++))
fi

status=$(state_get_status "subdomains")
if [ "$status" = "failed" ]; then
  echo "PASS: failed phase is recorded in state"
else
  echo "FAIL: failed phase status mismatch (got: $status)"
  ((ERRORS++))
fi

if [ ! -f "$WORKDIR/meta/.phase_subdomains.inprogress" ]; then
  echo "PASS: in-progress marker cleared after failure"
else
  echo "FAIL: in-progress marker not cleared after failure"
  ((ERRORS++))
fi

attempt_good=0
good_phase() {
  attempt_good=$((attempt_good + 1))
  echo "api.example.com" > "$WORKDIR/01_subdomains/all_subdomains.txt"
  return 0
}

if run_phase "subdomains" "good_phase"; then
  echo "PASS: run_phase succeeds with valid foundational output"
else
  echo "FAIL: run_phase failed with valid foundational output"
  ((ERRORS++))
fi

if [ "$attempt_good" -eq 1 ]; then
  echo "PASS: successful phase completes in one attempt"
else
  echo "FAIL: successful phase attempt count mismatch (got: $attempt_good)"
  ((ERRORS++))
fi

status=$(state_get_status "subdomains")
if [ "$status" = "done" ]; then
  echo "PASS: successful phase is recorded as done"
else
  echo "FAIL: successful phase status mismatch (got: $status)"
  ((ERRORS++))
fi

if state_should_skip "subdomains"; then
  echo "PASS: completed valid phase is skipped on resume"
else
  echo "FAIL: completed valid phase was not skipped"
  ((ERRORS++))
fi

rm -rf "$OUTPUT_BASE"
exit $ERRORS
