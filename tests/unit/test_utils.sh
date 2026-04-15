#!/bin/bash
# ============================================================
# RECON Framework — Unit Test: Utils (log, banner, sanitize)
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh

ERRORS=0
LOG_FILE="/tmp/test_utils_log_$$.txt"
touch "$LOG_FILE"

# Test 1: log function writes to file
log info "Test message"
if grep -q "Test message" "$LOG_FILE"; then
  echo "PASS: log writes to file"
else
  echo "FAIL: log did not write to file"
  ((ERRORS++))
fi

# Test 2: log levels
log success "Success msg"
log warn "Warn msg"
log error "Error msg"

if grep -q "success" "$LOG_FILE" && grep -q "warn" "$LOG_FILE" && grep -q "error" "$LOG_FILE"; then
  echo "PASS: all log levels work"
else
  echo "FAIL: log levels missing"
  ((ERRORS++))
fi

# Test 3: sanitize_target
result=$(sanitize_target "*.example.com")
if [ "$result" = "example.com" ]; then
  echo "PASS: sanitize_target strips wildcard"
else
  echo "FAIL: sanitize_target (got: $result)"
  ((ERRORS++))
fi

result=$(sanitize_target "test.example.com")
if [ "$result" = "test.example.com" ]; then
  echo "PASS: sanitize_target preserves normal domain"
else
  echo "FAIL: sanitize_target (got: $result)"
  ((ERRORS++))
fi

# Test 4: require_tool
if require_tool "bash"; then
  echo "PASS: require_tool finds bash"
else
  echo "FAIL: require_tool can't find bash"
  ((ERRORS++))
fi

if ! require_tool "nonexistent_tool_xyz_$RANDOM" 2>/dev/null; then
  echo "PASS: require_tool returns 1 for missing tool"
else
  echo "FAIL: require_tool returned 0 for missing tool"
  ((ERRORS++))
fi

# Test 5: check_output
echo "content" > /tmp/test_output_$$.txt
if check_output "/tmp/test_output_$$.txt" "test"; then
  echo "PASS: check_output returns 0 for non-empty file"
else
  echo "FAIL: check_output"
  ((ERRORS++))
fi

touch /tmp/test_empty_$$.txt
if ! check_output "/tmp/test_empty_$$.txt" "test" 2>/dev/null; then
  echo "PASS: check_output returns 1 for empty file"
else
  echo "FAIL: check_output didn't detect empty file"
  ((ERRORS++))
fi

# Cleanup
rm -f "$LOG_FILE" /tmp/test_output_$$.txt /tmp/test_empty_$$.txt

exit $ERRORS
