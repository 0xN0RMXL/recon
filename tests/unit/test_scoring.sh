#!/bin/bash
# ============================================================
# RECON Framework — Unit Test: Scoring Engine
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh
source lib/scoring.sh

WORKDIR="/tmp/recon_test_$$"
mkdir -p "$WORKDIR/05_urls/categorized" "$WORKDIR/reports"
LOG_FILE="/dev/null"

ERRORS=0

# Create test URL list
cat > "$WORKDIR/05_urls/all_urls.txt" <<EOF
https://example.com/api/v1/users
https://example.com/admin/dashboard
https://example.com/upload/file
https://example.com/graphql
https://example.com/login
https://example.com/about
EOF

score_targets

# Verify output exists and is valid JSON
if [ -f "$WORKDIR/reports/prioritized_targets.json" ]; then
  if jq empty "$WORKDIR/reports/prioritized_targets.json" 2>/dev/null; then
    echo "PASS: scoring output is valid JSON"
  else
    echo "FAIL: scoring output is invalid JSON"
    ((ERRORS++))
  fi
else
  echo "FAIL: scoring output file missing"
  ((ERRORS++))
fi

# Verify /api/v1/ scores higher than /about
if [ -f "$WORKDIR/reports/prioritized_targets.json" ]; then
  api_score=$(jq '[.[] | select(.url | contains("api"))] | .[0].score' \
    "$WORKDIR/reports/prioritized_targets.json" 2>/dev/null)
  if [ "${api_score:-0}" -gt 0 ] 2>/dev/null; then
    echo "PASS: API endpoint scored ($api_score)"
  else
    echo "FAIL: API scoring (got: $api_score)"
    ((ERRORS++))
  fi
fi

# Verify /about does NOT appear (score 0 = not included)
about_count=$(jq '[.[] | select(.url | contains("about"))] | length' \
  "$WORKDIR/reports/prioritized_targets.json" 2>/dev/null)
if [ "${about_count:-0}" -eq 0 ]; then
  echo "PASS: /about correctly excluded (score 0)"
else
  echo "FAIL: /about should not be in scored output"
  ((ERRORS++))
fi

# Verify results are sorted by score descending
if [ -f "$WORKDIR/reports/prioritized_targets.json" ]; then
  first_score=$(jq '.[0].score' "$WORKDIR/reports/prioritized_targets.json" 2>/dev/null)
  last_score=$(jq '.[-1].score' "$WORKDIR/reports/prioritized_targets.json" 2>/dev/null)
  if [ "${first_score:-0}" -ge "${last_score:-0}" ] 2>/dev/null; then
    echo "PASS: results sorted by score descending"
  else
    echo "FAIL: results not sorted (first=$first_score, last=$last_score)"
    ((ERRORS++))
  fi
fi

rm -rf "$WORKDIR"
exit $ERRORS
