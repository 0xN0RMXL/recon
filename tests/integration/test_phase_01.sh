#!/bin/bash
# ============================================================
# RECON Framework — Integration Test: Phase 01 (Subdomains)
# Uses: scanme.nmap.org (explicitly authorized for testing)
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

source lib/utils.sh
source lib/state.sh
source lib/core.sh
source lib/subdomains.sh

TARGET="scanme.nmap.org"
LOG_FILE="/tmp/test_phase01_log_$$.txt"
touch "$LOG_FILE"
SCRIPT_DIR="$(pwd)"
OUTPUT_BASE="/tmp/recon_test_phase01_$$"
VERSION="1.0.0"

# Set defaults
CHAOS_KEY=""
GITHUB_TOKEN=""
SECURITYTRAILS_KEY=""
VIRUSTOTAL_KEY=""
OTX_KEY=""
URLSCAN_KEY=""
FORCE="false"
WORDLIST_DNS_BEST=""
WORDLIST_DNS_BRUTEFORCE=""
RESOLVERS=""

init_workspace

subdomains_run

# Validate output
if [ -f "$WORKDIR/01_subdomains/all_subdomains.txt" ] && \
   [ -s "$WORKDIR/01_subdomains/all_subdomains.txt" ]; then
  COUNT=$(wc -l < "$WORKDIR/01_subdomains/all_subdomains.txt" | tr -d ' ')
  echo "PASS: Subdomain enumeration produced $COUNT results"
  exit 0
else
  echo "FAIL: No subdomains found or file missing"
  exit 1
fi

rm -rf "$OUTPUT_BASE" "$LOG_FILE"
