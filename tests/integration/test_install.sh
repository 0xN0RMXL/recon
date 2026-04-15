#!/bin/bash
# ============================================================
# RECON Framework — Integration Test: Verify All Tools Installed
# ============================================================

REQUIRED_TOOLS=(subfinder httpx nuclei naabu dnsx katana assetfinder
                anew waybackurls gau hakrawler ffuf gobuster
                amass nmap jq parallel)

PASS=0; FAIL=0
for tool in "${REQUIRED_TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    echo "PASS: $tool"
    ((PASS++))
  else
    echo "FAIL: $tool NOT FOUND"
    ((FAIL++))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
