#!/bin/bash
# ============================================================
# RECON Framework — Integration Test: Phase 03 (Probe)
# Uses: scanme.nmap.org (explicitly authorized for testing)
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh
source lib/state.sh
source lib/core.sh
source lib/burp.sh
source lib/probe.sh

TARGET="scanme.nmap.org"
LOG_FILE="/tmp/test_phase03_log_$$.txt"
touch "$LOG_FILE"
SCRIPT_DIR="$(pwd)"
OUTPUT_BASE="/tmp/recon_test_phase03_$$"
VERSION="1.0.0"
BURP_ENABLED="false"
HTTPX_THREADS=50
FORCE="false"
BURP_AUTO_SCAN="false"

init_workspace

# Create test input
echo "scanme.nmap.org" > "$WORKDIR/01_subdomains/all_subdomains.txt"

probe_hosts

# Validate output
if [ -f "$WORKDIR/03_live_hosts/live.txt" ] && \
   [ -s "$WORKDIR/03_live_hosts/live.txt" ]; then
  COUNT=$(wc -l < "$WORKDIR/03_live_hosts/live.txt" | tr -d ' ')
  echo "PASS: Probe found $COUNT live hosts"
  exit 0
else
  echo "FAIL: No live hosts found or file missing"
  exit 1
fi

rm -rf "$OUTPUT_BASE" "$LOG_FILE"
