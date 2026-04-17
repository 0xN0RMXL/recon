#!/bin/bash
# ============================================================
# RECON Framework — Unit Test: Config Loading
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh

ERRORS=0
LOG_FILE="/dev/null"
SCRIPT_DIR="$(pwd)"

# Test with example config
CONFIG="config.yaml.example"

load_config

# Verify BURP_ENABLED defaults to false
if [ "$BURP_ENABLED" = "false" ]; then
  echo "PASS: BURP_ENABLED default is false"
else
  echo "FAIL: BURP_ENABLED (got: $BURP_ENABLED)"
  ((ERRORS++))
fi

# Verify HTTPX_THREADS has a value
if [ -n "$HTTPX_THREADS" ]; then
  echo "PASS: HTTPX_THREADS set ($HTTPX_THREADS)"
else
  echo "FAIL: HTTPX_THREADS empty"
  ((ERRORS++))
fi

# Verify NUCLEI_RATE has a value
if [ -n "$NUCLEI_RATE" ]; then
  echo "PASS: NUCLEI_RATE set ($NUCLEI_RATE)"
else
  echo "FAIL: NUCLEI_RATE empty"
  ((ERRORS++))
fi

# Verify BURP_PROXY has a default
if [ -n "$BURP_PROXY" ]; then
  echo "PASS: BURP_PROXY has default ($BURP_PROXY)"
else
  echo "FAIL: BURP_PROXY empty"
  ((ERRORS++))
fi

# Verify OUTPUT_BASE has a value
if [ -n "$OUTPUT_BASE" ]; then
  echo "PASS: OUTPUT_BASE set ($OUTPUT_BASE)"
else
  echo "FAIL: OUTPUT_BASE empty"
  ((ERRORS++))
fi

# Verify new sampling/concurrency controls are loaded
for var_name in ANALYZER_MAX_HOSTS CONTENT_MAX_HOSTS VULNS_MAX_HOSTS PARAMS_MAX_HOSTS WAYMORE_FALLBACK_MAX_HOSTS HYPOTHESIS_MAX_PER_PATTERN SQLMAP_MAX_TARGETS SQLMAP_MAX_CONCURRENT; do
  value="${!var_name}"
  if [ -n "$value" ]; then
    echo "PASS: $var_name set ($value)"
  else
    echo "FAIL: $var_name empty"
    ((ERRORS++))
  fi
done

exit $ERRORS
