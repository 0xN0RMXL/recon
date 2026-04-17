#!/bin/bash
# ============================================================
# RECON Framework — Unit Test: Orchestration fail-fast policy
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

export RECON_NO_MAIN=1
source ./recon.sh

ERRORS=0

# Keep behavior deterministic and isolated.
BURP_ENABLED="false"
NO_BURP="true"
TARGET="example.com"
CALL_LOG=""

run_phase() {
  local phase_name="$1"
  CALL_LOG="$CALL_LOG $phase_name"

  case "$phase_name" in
    dns)
      return 1
      ;;
    analyzer)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

diff_assets() { return 0; }
burp_send_interesting() { return 0; }

# Test 1: critical phase failure (dns) stops orchestration.
CALL_LOG=""
if run_all_phases; then
  echo "FAIL: run_all_phases should fail when critical phase fails"
  ((ERRORS++))
else
  echo "PASS: run_all_phases fails on critical phase failure"
fi

if echo "$CALL_LOG" | grep -qw "probe"; then
  echo "FAIL: orchestration continued after critical failure"
  ((ERRORS++))
else
  echo "PASS: orchestration stopped before downstream critical phases"
fi

# Test 2: analyzer failure is non-blocking.
run_phase() {
  local phase_name="$1"
  CALL_LOG="$CALL_LOG $phase_name"

  case "$phase_name" in
    analyzer)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

CALL_LOG=""
if run_all_phases; then
  echo "PASS: analyzer failure does not stop orchestration"
else
  echo "FAIL: orchestration should continue after analyzer failure"
  ((ERRORS++))
fi

if echo "$CALL_LOG" | grep -qw "content"; then
  echo "PASS: orchestration continued after analyzer failure"
else
  echo "FAIL: content phase was not reached after analyzer failure"
  ((ERRORS++))
fi

unset RECON_NO_MAIN

exit $ERRORS
