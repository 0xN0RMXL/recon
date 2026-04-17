#!/bin/bash
# ============================================================
# RECON Framework — Integration Test: Resume integrity checks
# Validates partial-artifact checkpoint behavior
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh
source lib/state.sh
source lib/core.sh

ERRORS=0
TARGET="resume.example.com"
TARGET_MODE="single"
OUTPUT_BASE="/tmp/recon_test_resume_integrity_$$"
VERSION="1.0.0"
FORCE="false"
NO_NOTIFY="true"
LOG_FILE="/tmp/test_resume_integrity_$$.log"

init_workspace

mkdir -p "$WORKDIR/01_subdomains"
echo "api.resume.example.com" > "$WORKDIR/01_subdomains/all_subdomains.txt"
state_mark_done "subdomains"

if state_should_skip "subdomains"; then
  echo "PASS: done + valid artifact is skipped"
else
  echo "FAIL: expected phase skip before partial marker"
  ((ERRORS++))
fi

state_mark_running "subdomains" "1"
if ! state_should_skip "subdomains"; then
  echo "PASS: partial checkpoint forces rerun"
else
  echo "FAIL: phase was skipped despite partial checkpoint"
  ((ERRORS++))
fi

state_clear_running "subdomains"
if [ ! -f "$WORKDIR/meta/.phase_subdomains.inprogress" ]; then
  echo "PASS: partial checkpoint cleanup works"
else
  echo "FAIL: partial checkpoint was not cleared"
  ((ERRORS++))
fi

rm -rf "$OUTPUT_BASE"
rm -f "$LOG_FILE"

exit $ERRORS
