#!/bin/bash
# ============================================================
# RECON Framework — Integration Test: Verify All Tools Installed
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

OS_NAME=$(uname -s 2>/dev/null || echo "unknown")
case "$OS_NAME" in
  Linux*) ;;
  *)
    echo "SKIP: test_install expects Linux runtime (current: $OS_NAME)"
    exit 0
    ;;
esac

REQUIRED_TOOLS=(subfinder httpx nuclei naabu dnsx katana assetfinder
                anew waybackurls gau hakrawler ffuf gobuster
                amass nmap jq parallel puredns massdns waymore)

PASS=0; FAIL=0; WARN=0
for tool in "${REQUIRED_TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    echo "PASS: $tool"
    ((PASS++))
  else
    echo "FAIL: $tool NOT FOUND"
    ((FAIL++))
  fi
done

runtime_check() {
  local name="$1"
  local cmd="$2"
  local expect="$3"
  shift 3

  if ! command -v "$cmd" &>/dev/null; then
    echo "FAIL: $name runtime skipped (missing command)"
    ((FAIL++))
    return
  fi

  local output
  output=$("$cmd" "$@" 2>&1 | head -20 || true)
  if echo "$output" | grep -qiE "$expect"; then
    echo "PASS: $name runtime"
    ((PASS++))
  else
    echo "FAIL: $name runtime check"
    ((FAIL++))
  fi
}

runtime_check "naabu" "naabu" 'usage|rate|port' '-h'
runtime_check "waymore" "waymore" 'usage|commoncrawl|providers' '-h'
runtime_check "puredns" "puredns" 'usage|bruteforce|resolve' '--help'
runtime_check "massdns" "massdns" 'usage|massdns|resolver' '-h'

if command -v puredns &>/dev/null && command -v massdns &>/dev/null; then
  if [ -s "data/resolvers/resolvers.txt" ]; then
    tmp_out="/tmp/recon_test_puredns_$$.txt"
    interop_out=$(puredns bruteforce /dev/null example.invalid -r "data/resolvers/resolvers.txt" -w "$tmp_out" 2>&1 || true)
    rm -f "$tmp_out"

    if echo "$interop_out" | grep -qiE 'massdns.+not found|unable to execute massdns|exec: "massdns"'; then
      echo "FAIL: puredns+massdns interoperability"
      ((FAIL++))
    else
      echo "PASS: puredns+massdns interoperability"
      ((PASS++))
    fi
  else
    echo "WARN: resolvers.txt missing, skipping puredns+massdns interoperability check"
    ((WARN++))
  fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"
[ $FAIL -eq 0 ] && exit 0 || exit 1
