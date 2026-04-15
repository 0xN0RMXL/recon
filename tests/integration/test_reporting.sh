#!/bin/bash
# ============================================================
# RECON Framework — Integration Test: Reporting
# Uses fixture data to generate and validate reports
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh
source lib/state.sh
source lib/core.sh
source lib/burp.sh
source lib/reporting.sh

TARGET="test-fixture.example.com"
LOG_FILE="/tmp/test_report_log_$$.txt"
touch "$LOG_FILE"
SCRIPT_DIR="$(pwd)"
OUTPUT_BASE="/tmp/recon_test_report_$$"
VERSION="1.0.0"
BURP_ENABLED="false"
FORCE="false"

init_workspace

# Set up fixture workspace
cp tests/fixtures/sample_subdomains.txt "$WORKDIR/01_subdomains/all_subdomains.txt" 2>/dev/null
cp tests/fixtures/sample_live.txt "$WORKDIR/03_live_hosts/live.txt" 2>/dev/null
cp tests/fixtures/sample_urls.txt "$WORKDIR/05_urls/all_urls.txt" 2>/dev/null

# Create required empty files
touch "$WORKDIR/07_js/js_urls.txt"
touch "$WORKDIR/08_params/all_params.txt"
touch "$WORKDIR/09_vulns/nuclei_critical.txt"
touch "$WORKDIR/09_vulns/nuclei_high.txt"
touch "$WORKDIR/09_vulns/takeovers_nuclei.txt"
touch "$WORKDIR/11_secrets/regex_secrets.txt"

ERRORS=0

generate_report

# Validate all report files exist
for f in summary.md summary.json summary.html h1_report_template.md; do
  if [ -f "$WORKDIR/reports/$f" ]; then
    echo "PASS: $f generated"
  else
    echo "FAIL: $f missing"
    ((ERRORS++))
  fi
done

# Validate JSON is valid
if jq empty "$WORKDIR/reports/summary.json" 2>/dev/null; then
  echo "PASS: summary.json is valid JSON"
else
  echo "FAIL: summary.json invalid"
  ((ERRORS++))
fi

# Validate HTML contains expected elements
if grep -q "RECON Report" "$WORKDIR/reports/summary.html" 2>/dev/null; then
  echo "PASS: summary.html contains expected content"
else
  echo "FAIL: summary.html missing expected content"
  ((ERRORS++))
fi

rm -rf "$OUTPUT_BASE" "$LOG_FILE"
exit $ERRORS
